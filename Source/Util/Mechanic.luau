local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Util = script.Parent
local Types = require(Util.Types)
local Bindable = require(Util.Bindable)

type MechanicController = Types.MechanicController
type Mechanic = Types.Mechanic
type MechanicData = Types.MechanicData
type Bindable = Types.Bindable

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

local function deepCopy(list: MechanicData)
	local copy = {}
	for index: string, value: any in pairs(list) do
		if type(value) == "table" then
			copy[index] = deepCopy(value)
		else
			copy[index] = value
		end
	end

	return copy
end

function module.new(controller: MechanicController, name: string, data: MechanicData)
	local self = setmetatable(deepCopy(data), Mechanic) -- create new functions that take in the prefix and run the corresponding function
	self.controller = controller
	self.name = name
	self._initialized = false
	self._toggled = false
	self._enabled = nil

	self.Toggled = Bindable.new()

	for functionName, _ in pairs(mechanicFunctions) do
		if data[getMechanicPrefix(self) .. functionName] then
			self["_" .. functionName] = function(...)
				data[getMechanicPrefix(self) .. functionName](self.controller, ...)
			end
		end
	end

	for functionIndex: string, _ in pairs(mechanicFunctions) do
		if not self["_" .. functionIndex] then
			self["_" .. functionIndex] = function() end
		end
	end

	return self
end

function Mechanic.Toggle(self: Mechanic, toggle: boolean)
	if self._enabled and self._toggled ~= toggle then
		self.Toggled:Fire(toggle)

		self._cleanupFunction()
		self._toggleFunction(toggle)
	end

	self._toggled = toggle
end

function Mechanic.Enable(self: Mechanic, toggle: boolean)
	if toggle == nil then
		toggle = true
	end

	if self._enabled ~= toggle then
		self._enabled = toggle
		if toggle then
			self._cleanupFunction()
			self._toggleFunction(self._toggled)
		elseif not toggle and self._toggled then
			self._toggleFunction(false)
			self._cleanupFunction()
		end
	end
end

function Mechanic.Disable(self: Mechanic, toggle: boolean, starterPlayer: Player)
	if toggle == nil then
		toggle = true
	end
	self:Enable(not toggle, starterPlayer, "Disable")
end

function Mechanic.Destroy(self: Mechanic)
	self._cleanupFunction()
	self._destroyFunction()

	if getMechanicPrefix(self) == "" then
		for _, connection: RBXScriptConnection in pairs(self._connections) do
			connection:Disconnect()
		end
	end
end

local function connectInputFunctions(self: Mechanic)
	self.functionConnections = self.functionConnections or {}
	self._connections = {}

	for func: (...any) -> (...any), event: BindableEvent | Bindable in pairs(self.functionConnections) do
		table.insert(
			self._connections,
			event:Connect(function(...)
				func(self.controller, ...)
			end)
		)
	end
end

function Mechanic.Init(self: Mechanic)
	if not self._initialized then
		self._initialized = true

		self._initFunction()

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
