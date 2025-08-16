local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicationEvent = script.Parent.ReplicateController

local Util = script.Parent.Util
local Types = require(Util.Types)
local Bindable = require(Util.Bindable)
local Mechanic = require(Util.Mechanic)

type MechanicController = Types.MechanicController
type Mechanic = Types.Mechanic
type MechanicInfo = Types.MechanicInfo

local coreRigComponents = {
	HumanoidRootPart = 1,
	Humanoid = 1,
}

local ControllerReplicationDict = {
	construct = "a",
	update = "b",
	destroy = "c",
	add_mechanics = "d",
}

local Controller = {}
Controller.__index = Controller

local module = {
	_metadata = Controller,
	ConstructingPreMechanics = Bindable.new(),
	ConstructingPostMechanics = Bindable.new(),
	Destructing = Bindable.new(),
	PlayerReplicated = Bindable.new(),
}

module.MechanicDataModules = {}

function module.addMechanicModule(mechanicModule: ModuleScript)
	if RunService:IsServer() then
		ReplicationEvent:FireAllClients(ControllerReplicationDict.add_mechanics, mechanicModule)
	end

	if not table.find(module.MechanicDataModules, mechanicModule) then
		table.insert(module.MechanicDataModules, mechanicModule)
	end
end

local function setupConnections(self: MechanicController)
	for rigComponentName: string, _ in pairs(coreRigComponents) do
		local component = self.rig:FindFirstChild(rigComponentName, true)
		self._connections[rigComponentName .. "DestroyCheck"] = component
			:GetPropertyChangedSignal("Parent")
			:Connect(function()
				if component.Parent == nil then
					if self.rig:FindFirstChild("Humanoid") then
						self.rig.Humanoid.Health = -100
					end

					self:Destroy()
				end
			end)
	end

	self._connections["DeathCheck"] = self.rig.Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if self.rig:FindFirstChild("Humanoid") then
			if self.rig.Humanoid.Health <= 0 then
				self:Destroy()
			end
		end
	end)

	self._connections["RemovalCheck"] = self.rig.Changed:Connect(function(property: string)
		if property == "Parent" and self.rig.Parent == nil then
			self:Destroy()
		end
	end)
end

local function loadMovementMechanics(self: MechanicController)
	local mechanicDatas = {}
	for _, mechanicModule: ModuleScript in pairs(module.MechanicDataModules) do
		local datas = require(mechanicModule)(self)
		if datas["data"] then
			datas = { datas }
		end

		for _, data: MechanicInfo in pairs(datas) do
			local name = data["name"]
			mechanicDatas[name] = data

			self.mechanics[name] = Mechanic.new(self, name, data.data)

			if self.mechanics[name]["SERVER_toggleFunction"] or self.mechanics[name]["REPLICATED_toggleFunction"] then
				if RunService:IsClient() then
					if Players.LocalPlayer == self.player then
						self._connections["MechanicReplication_" .. name] = self.mechanics[name].Toggling:Connect(
							function(toggle: boolean)
								ReplicationEvent:FireServer(ControllerReplicationDict.update, self.rig, name, toggle)
							end
						)
					end
				end
			end
		end
	end

	local keys = {}
	for mechanicName: string, _ in pairs(mechanicDatas) do
		table.insert(keys, mechanicName)
	end

	table.sort(keys, function(a, b)
		local aOrder, bOrder = mechanicDatas[a].loadingOrder or math.huge, mechanicDatas[b].loadingOrder or math.huge
		return aOrder < bOrder
	end)

	for _, key: string in pairs(keys) do
		local mechanic = self.mechanics[key]
		mechanic:Init()
		mechanic._toggled = mechanicDatas[key].toggledOnStart or false
		mechanic:Enable(mechanicDatas[key].enabledOnStart or false)
	end
end

function module.new(characterRig: Model, player: Player): MechanicController
	for charRequisite: string, _ in pairs(coreRigComponents) do
		characterRig:WaitForChild(charRequisite)
	end

	local self = setmetatable({
		rig = characterRig,
		player = player,
		mechanics = {},
		_connections = {},
	}, Controller)

	module.ConstructingPreMechanics:Fire(self)

	loadMovementMechanics(self)

	module.ConstructingPostMechanics:Fire(self)

	module.Controllers[self.rig] = self

	return self
end

if RunService:IsServer() then
	local new = module.new
	module.new = function(characterRig: Model, player: Player)
		local self = new(characterRig, player)
		ReplicationEvent:FireAllClients(ControllerReplicationDict.construct, self.rig, self.player)
		setupConnections(self)

		return self
	end
end

function Controller.Destroy(self: MechanicController)
	if RunService:IsServer() then
		ReplicationEvent:FireAllClients(ControllerReplicationDict.destroy, self.rig)
	end

	module.Destructing:Fire(self)

	for _, mechanic: Mechanic in pairs(self.mechanics) do
		mechanic:Destroy()
	end

	table.clear(self)
end

module.Controllers = {}

if RunService:IsServer() then
	Players.PlayerAdded:Connect(function(player: Player)
		for _, controller: Controller in pairs(module.Controllers) do
			if controller.player ~= player then
				ReplicationEvent:FireClient(
					player,
					ControllerReplicationDict.construct,
					controller.rig,
					controller.player
				)
			end
		end

		for _, mechanicModule: ModuleScript in pairs(module.MechanicDataModules) do
			ReplicationEvent:FireClient(player, ControllerReplicationDict.add_mechanics, mechanicModule)
		end

		module.PlayerReplicated:Fire(player)
	end)

	ReplicationEvent.OnServerEvent:Connect(
		function(player: Player, event: string, rig: Model, mechanicName: string, toggled: boolean)
			if event == ControllerReplicationDict.update then
				if module.Controllers[rig] then
					module.Controllers[rig].mechanics[mechanicName]:Toggle(toggled)

					if module.Controllers[rig].mechanics[mechanicName]["REPLICATED_toggleFunction"] then
						for _, iPlayer: Player in pairs(Players:GetPlayers()) do
							if iPlayer ~= player then
								ReplicationEvent:FireClient(
									iPlayer,
									ControllerReplicationDict.update,
									rig,
									mechanicName,
									toggled
								)
							end
						end
					end
				end
			end
		end
	)
else
	ReplicationEvent.OnClientEvent:Connect(function(event: string, ...)
		local args = { ... }

		if event == ControllerReplicationDict.construct then
			--[[local controller = ]]
			module.new(args[1], args[2])
		elseif event == ControllerReplicationDict.destroy then
			if module.Controllers[args[1]] then
				module.Controllers[args[1]]:Destroy()
			end
		elseif event == ControllerReplicationDict.update then
			if module.Controllers[args[1]] then
				module.Controllers[args[1]].mechanics[args[2]]:Toggle(args[3])
			end
		elseif event == ControllerReplicationDict.add_mechanics then
			module.addMechanicModule(args[1])
		end
	end)
end

return module
