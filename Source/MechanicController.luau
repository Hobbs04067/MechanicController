local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local ReplicationEvent = script.Parent.ReplicateController

local Util = script.Parent.Util
local Types = require(Util.Types)
local Bindable = require(Util.Bindable)
local Mechanic = require(Util.Mechanic)
local Enums = require(Util.Enums)
local Networking = require(Util.Networking)

type MechanicController = Types.MechanicController
type Mechanic = Types.Mechanic
type MechanicInfo = Types.MechanicInfo
type BitPackData = Types.BitPackData

local coreRigComponents = {
	HumanoidRootPart = 1,
	Humanoid = 1,
}

local Controller = {}
Controller.__index = Controller

local module = {
	_metadata = Controller,

	Controllers = {},

	_idControllerReference = {},

	ConstructingPreMechanics = Bindable.new(),
	ConstructingPostMechanics = Bindable.new(),
	Destructing = Bindable.new(),
	PlayerReplicated = Bindable.new(),
}

module.MechanicDataModules = {}

function module.addMechanicModule(mechanicModule: ModuleScript)
	if RunService:IsServer() then
		ReplicationEvent:FireAllClients(
			Networking.bitPack({
				replicationAction = Enums.ControllerReplicationAction.AddMechanic,
				controllerId = 0,
			}),
			mechanicModule
		)
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

	for id: number, key: string in ipairs(keys) do
		local mechanic = self.mechanics[key]
		mechanic._id = id
		mechanic:Init()
		mechanic._toggled = mechanicDatas[key].toggledOnStart or false
		mechanic:SoftEnable(mechanicDatas[key].enabledOnStart or false)
	end

	self._indexedMechanics = keys
end

local new = function(player: Player, id: number): MechanicController
	local characterRig = player.Character

	for charRequisite: string, _ in pairs(coreRigComponents) do
		characterRig:WaitForChild(charRequisite)
	end

	local self = setmetatable({
		id = id,
		rig = characterRig,
		player = player,
		mechanics = {},
		_connections = {},
	}, Controller)

	module.ConstructingPreMechanics:Fire(self)

	loadMovementMechanics(self)

	module.ConstructingPostMechanics:Fire(self)

	if module.Controllers[self.rig] then
		module.Controllers[self.rig]:Destroy()
	end

	module.Controllers[self.rig] = self
	module._idControllerReference[self.id] = self

	return self
end

if RunService:IsServer() then
	module._availableControllerIds = {}

	for i = 0, 255, 1 do
		table.insert(module._availableControllerIds, i)
	end

	module.new = function(player: Player)
		local character = player.Character
		if character then
			if module.Controllers[character] then
				module.Controllers[character]:Destroy()
			end

			local self = new(player, module._availableControllerIds[1])
			table.remove(module._availableControllerIds, 1)
			ReplicationEvent:FireAllClients(
				Networking.bitPack({
					replicationAction = Enums.ControllerReplicationAction.Construct,
					controllerId = self.id,
				}),
				player
			)
			setupConnections(self)

			return self
		else
			error("MechanicController Error: Character of player not found or loaded.")
		end
	end
elseif RunService:IsClient() then
	module.new = function(player: Player, controllerId: number)
		local self = new(player, controllerId)

		self._resetBindableEvent = Instance.new("BindableEvent")
		self.PlayerReset = self._resetBindableEvent.Event

		local success = false

		repeat
			success = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", self._resetBindableEvent)
			end)

			task.wait(0.1)
		until success

		self._connections["ResetButtonPressed"] = self.PlayerReset:Connect(function()
			ReplicationEvent:FireServer(Networking.bitPack({
				replicationAction = Enums.ControllerReplicationAction.Detruct,
				controllerId = self.id,
			}))
		end)

		return self
	end
end

function Controller.Destroy(self: MechanicController)
	module.Controllers[self.rig] = nil
	module._idControllerReference[self.id] = nil

	local missingCoreComponent = false
	for rigComponentName: string, _ in pairs(coreRigComponents) do
		if not self.rig:FindFirstChild(rigComponentName, true) then
			missingCoreComponent = true
			break
		end
	end

	if not missingCoreComponent then
		for _, mechanic: Mechanic in pairs(self.mechanics) do
			mechanic:Disable()
		end
	end

	for _, mechanic: Mechanic in pairs(self.mechanics) do
		mechanic:Destroy()
	end

	if RunService:IsServer() then
		ReplicationEvent:FireAllClients(Networking.bitPack({
			replicationAction = Enums.ControllerReplicationAction.Detruct,
			controllerId = self.id,
		}))

		table.insert(module._availableControllerIds, self.id)
	else
		self._resetBindableEvent:Destroy()
	end

	module.Destructing:Fire(self)

	for _, connection: RBXScriptConnection in pairs(self._connections) do
		connection:Disconnect()
	end

	table.clear(self)
	setmetatable(self, nil)
end

local function replicateToPlayer(player: Player)
	for _, mechanicModule: ModuleScript in pairs(module.MechanicDataModules) do
		ReplicationEvent:FireClient(
			player,
			Networking.bitPack({
				replicationAction = Enums.ControllerReplicationAction.AddMechanic,
				controllerId = 0,
			}),
			mechanicModule
		)
	end

	for _, controller: MechanicController in pairs(module.Controllers) do
		if controller.player ~= player then
			ReplicationEvent:FireClient(
				player,
				Networking.bitPack({
					replicationAction = Enums.ControllerReplicationAction.Construct,
					controllerId = controller.id,
				}),
				controller.player
			)
		end
	end

	module.PlayerReplicated:Fire(player)
end

if RunService:IsServer() then
	Players.PlayerAdded:Connect(function(player: Player)
		replicateToPlayer(player)
	end)

	for _, player: Player in pairs(Players:GetPlayers()) do
		replicateToPlayer(player)
	end

	ReplicationEvent.OnServerEvent:Connect(function(player: Player, packData: number)
		local event, controllerId, mechanicBoolean, mechanicId = Networking.bitUnpack(packData)

		if event == Enums.ControllerReplicationAction.UpdateToggle then
			local controller: MechanicController = module._idControllerReference[controllerId]
			if controller then
				controller.mechanics[controller._indexedMechanics[mechanicId]]:SoftToggle(mechanicBoolean)

				if
					controller.mechanics[controller._indexedMechanics[mechanicId]]._data["REPLICATED_toggleFunction"]
				then
					for _, iPlayer: Player in pairs(Players:GetPlayers()) do
						if iPlayer ~= player then
							ReplicationEvent:FireClient(iPlayer, packData)
						end
					end
				end
			end
		elseif event == Enums.ControllerReplicationAction.UpdateEnable then
			local controller: MechanicController = module._idControllerReference[controllerId]
			if controller then
				controller.mechanics[controller._indexedMechanics[mechanicId]]:SoftEnable(mechanicBoolean)

				if
					controller.mechanics[controller._indexedMechanics[mechanicId]]._data["REPLICATED_toggleFunction"]
				then
					for _, iPlayer: Player in pairs(Players:GetPlayers()) do
						if iPlayer ~= player then
							ReplicationEvent:FireClient(iPlayer, packData)
						end
					end
				end
			end
		elseif event == Enums.ControllerReplicationAction.Detruct then
			local controller: MechanicController = module._idControllerReference[controllerId]
			if controller then
				controller.rig.Humanoid.Health = 0
			end
		end
	end)
else
	ReplicationEvent.OnClientEvent:Connect(function(packData: number, ...)
		local args = { ... }

		local event, controllerId, mechanicBoolean, mechanicId = Networking.bitUnpack(packData)

		if event == Enums.ControllerReplicationAction.Construct then
			local _controller = module.new(args[1], controllerId)
		elseif event == Enums.ControllerReplicationAction.Detruct then
			local controller = module._idControllerReference[controllerId]
			if controller then
				controller:Destroy()
			end
		elseif event == Enums.ControllerReplicationAction.UpdateToggle then
			local controller: MechanicController = module._idControllerReference[controllerId]
			if controller then
				controller.mechanics[controller._indexedMechanics[mechanicId]]:SoftToggle(mechanicBoolean)
			end
		elseif event == Enums.ControllerReplicationAction.UpdateEnable then
			local controller: MechanicController = module._idControllerReference[controllerId]
			if controller then
				controller.mechanics[controller._indexedMechanics[mechanicId]]:SoftEnable(mechanicBoolean)
			end
		elseif event == Enums.ControllerReplicationAction.AddMechanic then
			module.addMechanicModule(args[1])
		end
	end)
end

return module