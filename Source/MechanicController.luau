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
type BitPackData = Types.BitPackData

local coreRigComponents = {
	HumanoidRootPart = 1,
	Humanoid = 1,
}

local ControllerReplicationDict = {
	construct = 0,
	update = 1,
	destroy = 2,
	add_mechanics = 3,
}

local bitPackBAndReferenceDict = {
	replication_action = 3,
	controller_id = 255,
	mechanic_toggle = 1,
	mechanic_id = 2^21-1,
}

local function bitPack(packData: BitPackData)
	local packedReplicationAction = bit32.lshift(packData.replicationAction, 30)
	local packedControllerId = bit32.lshift(packData.controllerId, 22)
	local packedMechanicToggle = 0
	local packedMechanicId = 0

	if packData.mechanicToggle then
		local num = 0
		if packData.mechanicToggle == true then
			num = 1
		end
		packedMechanicToggle = bit32.lshift(num, 21)
		packedMechanicId = packData.mechanicId
	end

	return bit32.bor(packedReplicationAction, packedControllerId, packedMechanicToggle, packedMechanicId)
end

local function bitUnpack(pack)
	local unpackedReplicationAction = bit32.rshift(bit32.band(pack, bitPackBAndReferenceDict.replication_action), 30)
	local unpackedControllerId = bit32.rshift(bit32.band(pack, bitPackBAndReferenceDict.replication_action), 22)
	local unpackedMechanicToggle = bit32.rshift(bit32.band(pack, bitPackBAndReferenceDict.mechanic_toggle), 21)
	local unpackedMechanicId = bit32.band(pack, bitPackBAndReferenceDict.mechanic_id)

	return unpackedReplicationAction, unpackedControllerId, unpackedMechanicToggle == 1, unpackedMechanicId
end

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

for i = 0, 255, 1 do
	table.insert(module._availableControllerIds, i)
end

module.MechanicDataModules = {}

function module.addMechanicModule(mechanicModule: ModuleScript)
	if RunService:IsServer() then
		ReplicationEvent:FireAllClients(bitPack({
			replicationAction = ControllerReplicationDict.add_mechanics, 
			controllerId = 0
		}), mechanicModule)
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
								ReplicationEvent:FireServer(bitPack({
									replicationAction = ControllerReplicationDict.update,
									controllerId = self.id,
									mechanicToggle = toggle,
									mechanicId = self.mechanics[name]._id
								}))
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

	self._indexedMechanics = {}
	local i = 1
	for name: string, mechanic: Mechanic in pairs(self.mechanics) do
		self._indexedMechanics[i] = name
		mechanic._id = i
	end
end

function module.new(player: Player, id: number): MechanicController
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

	module.Controllers[self.rig] = self
	module._idControllerReference[self.id] = self

	return self
end

if RunService:IsServer() then
	module._availableControllerIds = {}
	
	for i=0, 255, 1 do
		table.insert(module._availableControllerIds, i)
	end

	local new = module.new
	module.new = function(player: Player)
		local self = new(player, module._availableControllerIds[1])
		table.remove(module._availableControllerIds, 1)
		ReplicationEvent:FireAllClients(bitPack({
			replicationAction = ControllerReplicationDict.construct,
			controllerId = self.id
		}), player)
		setupConnections(self)

		return self
	end
end

function Controller.Destroy(self: MechanicController)
	module.Controllers[self.rig] = nil
	module._idControllerReference[self.id] = nil

	if RunService:IsServer() then
		ReplicationEvent:FireAllClients(bitPack({
			replicationAction = ControllerReplicationDict.destroy,
			controllerId = self.id
		}))

		table.insert(module._availableControllerIds, self.id)
	end

	module.Destructing:Fire(self)

	for _, mechanic: Mechanic in pairs(self.mechanics) do
		mechanic:Destroy()
	end

	for _, connection: RBXScriptConnection in pairs(self._connections) do
		connection:Disconnect()
	end

	table.clear(self)
	setmetatable(self, nil)
end

if RunService:IsServer() then
	Players.PlayerAdded:Connect(function(player: Player)

		for _, controller: MechanicController in pairs(module.Controllers) do
			if controller.player ~= player then
				ReplicationEvent:FireClient(bitPack({
					replicationAction = ControllerReplicationDict.construct,
					controllerId = controller.id
				}), controller.player)
			end
		end

		for _, mechanicModule: ModuleScript in pairs(module.MechanicDataModules) do
			ReplicationEvent:FireClient(player, bitPack({
				replicationAction = ControllerReplicationDict.add_mechanics, 
				controllerId = 0
			}), mechanicModule)
		end

		module.PlayerReplicated:Fire(player)
	end)

	ReplicationEvent.OnServerEvent:Connect(
		function(player: Player, packData: number)
			local event, controllerId, mechanicToggle, mechanicId = bitUnpack(packData)

			if event == ControllerReplicationDict.update then
				local controller: MechanicController = module._idControllerReference[controllerId]
				if controller then
					controller.mechanics[controller._indexedMechanics[mechanicId]]:Toggle(mechanicToggle)

					if controller.mechanics[controller._indexedMechanics[mechanicId]]["REPLICATED_toggleFunction"] then
						for _, iPlayer: Player in pairs(Players:GetPlayers()) do
							if iPlayer ~= player then
								ReplicationEvent:FireClient(iPlayer, packData)
							end
						end
					end
				end
			end
		end
	)
else
	ReplicationEvent.OnClientEvent:Connect(function(packData: number, ...)
		local args = { ... }

		local event, controllerId, mechanicToggle, mechanicId = bitUnpack(packData)

		if event == ControllerReplicationDict.construct then
			--[[local controller = ]]
			module.new(args[1], controllerId)
		elseif event == ControllerReplicationDict.destroy then
			if module._idControllerReference[controllerId] then
				module._idControllerReference[controllerId]:Destroy()
			end
		elseif event == ControllerReplicationDict.update then
			local controller: MechanicController = module._idControllerReference[controllerId]
			if controller then
				controller.mechanics[controller._indexedMechanics[mechanicId]]:Toggle(mechanicToggle)
			end
		elseif event == ControllerReplicationDict.add_mechanics then
			module.addMechanicModule(args[1])
		end
	end)
end

return module
