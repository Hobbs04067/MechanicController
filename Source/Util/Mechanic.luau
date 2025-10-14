local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicationEvent = script.Parent.Parent.ReplicateController

local Util = script.Parent
local Types = require(Util.Types)
local Bindable = require(Util.Bindable)
local Enums = require(Util.Enums)
local Networking = require(Util.Networking)

type MechanicController = Types.MechanicController
type Mechanic = Types.Mechanic
type MechanicData = Types.MechanicData
type Bindable = Types.Bindable

local function shouldReplicate(self: Mechanic)
	return self._data["REPLICATED_initFunction"] or self._data["REPLICATED_destroyFunction"] or self._data["REPLICATED_toggleFunction"] or self._data["REPLICATED_cleanupFunction"]
end

local mechanicFunctions = {
	initFunction = 0,
	destroyFunction = 0,
	toggleFunction = 0,
	cleanupFunction = 0,
}

local Mechanic = {}
Mechanic.__index = Mechanic

local module = { _metadata = Mechanic }

local function getMechanicPrefix(self: Mechanic)
	if RunService:IsClient() then
		if self.controller.player ~= Players.LocalPlayer then
			return "REPLICATED_"
		end
	else
		return "SERVER_"
	end

	return ""
end

function module.new(controller: MechanicController, name: string, data: MechanicData)
	local self = setmetatable({}, Mechanic) -- create new functions that take in the prefix and run the corresponding function
	self.controller = controller
	self.name = name
	self._initialized = false
	self._toggled = false
	self._enabled = nil
	self._data = data

	self.Toggled = Bindable.new()
	self.Enabled = Bindable.new()
	self.Disabled = Bindable.new()

	for functionName, _ in pairs(mechanicFunctions) do
		if data[getMechanicPrefix(self) .. functionName] then
			self["_" .. functionName] = function(...)
				data[getMechanicPrefix(self) .. functionName](self.controller, ...)
			end
		end
	end

	for key, value in pairs(data) do
		if not mechanicFunctions[key] then
			self[key] = value
		end
	end

	for functionIndex: string, _ in pairs(mechanicFunctions) do
		if not self["_" .. functionIndex] then
			self["_" .. functionIndex] = function() end
		end
	end

	return self
end

local function Toggle(self: Mechanic, toggle: boolean, ...)
	if self._enabled and self._toggled ~= toggle then
		self._cleanupFunction(...)
		self._toggleFunction(toggle, ...)
	end

	self._toggled = toggle
end

if RunService:IsServer() then
	Mechanic.SoftToggle = function(self: Mechanic, toggle: boolean, ...)
		self.Toggled:Fire(toggle)

		Toggle(self, toggle, ...)
	end

	Mechanic.Toggle = function(self: Mechanic, toggle: boolean, ...)
		ReplicationEvent:FireClient(
			self.controller.player,
			Networking.bitPack({
				replicationAction = Enums.ControllerReplicationAction.UpdateToggle,
				controllerId = self.controller.id,
				mechanicBoolean = toggle,
				mechanicId = self._id,
			})
		)

		self:SoftToggle(toggle, ...)
	end
else
	Mechanic.SoftToggle = function(self: Mechanic, toggle: boolean, ...)
		self.Toggled:Fire(toggle)

		Toggle(self, toggle, ...)
	end

	Mechanic.Toggle = function(self: Mechanic, toggle: boolean, ...)
		if shouldReplicate(self) and self.controller.player == Players.LocalPlayer then
			ReplicationEvent:FireServer(
				Networking.bitPack({
					replicationAction = Enums.ControllerReplicationAction.UpdateToggle,
					controllerId = self.controller.id,
					mechanicBoolean = toggle,
					mechanicId = self._id,
				})
			)
		end

		self:SoftToggle(toggle, ...)
	end
end

local function Enable(self: Mechanic, toggle: boolean, ...)
	if toggle == nil then
		toggle = true
	end

	if self._enabled ~= toggle then
		if toggle then
			self.Enabled:Fire()
		else
			self.Disabled:Fire()
		end

		self._enabled = toggle
		if toggle then
			self._cleanupFunction(...)
			self._toggleFunction(self._toggled, ...)
		elseif not toggle and self._toggled then
			self._toggleFunction(false, ...)
			self._cleanupFunction(...)
		end
	end
end

if RunService:IsServer() then
	Mechanic.SoftEnable = function(self: Mechanic, toggle: boolean, ...)
		self.Enabled:Fire(toggle)

		Enable(self, toggle, ...)
	end

	Mechanic.Enable = function(self: Mechanic, toggle: boolean, ...)
		if toggle == nil then
			toggle = true
		end

		ReplicationEvent:FireClient(
			self.controller.player,
			Networking.bitPack({
				replicationAction = Enums.ControllerReplicationAction.UpdateEnable,
				controllerId = self.controller.id,
				mechanicBoolean = toggle,
				mechanicId = self._id,
			})
		)

		self:SoftToggle(toggle, ...)
	end
else
	Mechanic.SoftEnable = function(self: Mechanic, toggle: boolean, ...)
		self.Enabled:Fire(toggle)

		Enable(self, toggle, ...)
	end

	Mechanic.Enable = Mechanic.SoftEnable
end

function Mechanic.Disable(self: Mechanic, toggle: boolean, ...)
	if toggle == nil then
		toggle = true
	end
	self:Enable(not toggle, ...)
end

function Mechanic.DisableWithoutFiring(self: Mechanic, toggle: boolean, ...)
	if toggle == nil then
		toggle = true
	end
	self:EnableWithoutFiring(not toggle, ...)
end

function Mechanic.Destroy(self: Mechanic, ...)
	self._cleanupFunction(...)
	self._destroyFunction(...)

	if getMechanicPrefix(self) == "" then
		for _, connection: RBXScriptConnection in pairs(self._connections) do
			connection:Disconnect()
		end
	end

	table.clear(self)
	setmetatable(self, nil)
end

local function connectInputFunctions(self: Mechanic)
	self._connections = {}

	if self._data.functionConnections then
		for func: (...any) -> ...any, event: BindableEvent | Bindable in pairs(self._data.functionConnections) do
			table.insert(
				self._connections,
				event:Connect(function(...)
					func(self.controller, ...)
				end)
			)
		end
	end
end

function Mechanic.Init(self: Mechanic, ...)
	if not self._initialized then
		self._initialized = true

		self._initFunction(...)

		if getMechanicPrefix(self) == "" then
			connectInputFunctions(self)
		end
	end
end

function Mechanic.IsEnabled(self: Mechanic)
	return self._enabled
end

function Mechanic.IsDisabled(self: Mechanic)
	return not self._enabled
end

function Mechanic.IsToggled(self: Mechanic)
	return self._toggled
end

function Mechanic.IsUsing(self: Mechanic)
	return self._toggled and self._enabled
end

return module