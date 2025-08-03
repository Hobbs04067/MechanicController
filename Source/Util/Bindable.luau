local Util = script.Parent
local Types = require(Util.Types)

type Bindable = Types.Bindable

local Bindable = {}
Bindable.__index = Bindable

local module = {}

function module.new()
	return setmetatable({_connections={}}, Bindable)
end

function Bindable.Connect(self: Bindable, func)
	table.insert(self._connections, func)
end

function Bindable.Fire(self: Bindable, ...)
	local args = table.pack(...)
	for _, func in pairs(self._connections) do
		task.spawn(func, table.unpack(args))
	end
end

function Bindable.Destroy(self: Bindable)
	table.clear(self._connections)
end

return module
