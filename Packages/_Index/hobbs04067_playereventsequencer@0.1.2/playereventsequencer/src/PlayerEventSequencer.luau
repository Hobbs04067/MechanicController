local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type ConnectionType = number | thread
type Connection = {
    callback: (...any) -> (),
    connectionType: ConnectionType,
}
type ConnectionTable = {
	[(...any) -> ()]: ConnectionType,
	size: number,
}

local function initConnectionTable(): ConnectionTable
	return {}
end

local function connect(connectionTable: ConnectionTable, callback: (...any) -> (), t: ConnectionType)
	table.insert(connectionTable, { callback = callback, type = t })

    return #connectionTable
end

local function disconnect(connectionTable: ConnectionTable, index: number)
    table.remove(connectionTable, index)
end

local function call(connection: Connection, ...)
    connection.callback(...)
end

local function initConnection(connectionTable: ConnectionTable, index: number): RBXScriptConnection
	return {
		Disconnect = function(self)
			if self.Connected then
				disconnect(connectionTable, index)

                self.Connected = false
			else
				error("Attempted to disconnect a non-existent connection.")
			end
		end,

		Connected = true,
	}
end

local connections = {
	["PlayerAdded"] = initConnectionTable(),
	["PlayerRemoving"] = initConnectionTable(),
}

if RunService:IsClient() then
	connections["PlayerChatted"] = initConnectionTable()
	connections["PlayerConnecting"] = initConnectionTable()
	connections["PlayerDisconnecting"] = initConnectionTable()
	connections["PlayerMembershipChanged"] = initConnectionTable()
	connections["PlayerRejoining"] = initConnectionTable()
end

local module = {}

for eventName: string, connTable: ConnectionTable in pairs(connections) do
	Players[eventName]:Connect(function(...)
		for i: number, connection: Connection in pairs(connTable) do
			call(connection, ...)

            local callbackType = connection.connectionType
			if callbackType == 1 then
				disconnect(connTable, i)
			elseif type(callbackType) == "thread" then
				coroutine.resume(callbackType)
			end
		end
	end)

	module[eventName] = {
		Connect = function(_, callback: (...any) -> ())
			return initConnection(connTable, connect(connTable, callback, 0))
		end :: RBXScriptSignal,

		Once = function(_, callback: (...any) -> ())
			return initConnection(connTable, connect(connTable, callback, 1))
		end :: RBXScriptSignal,

		Wait = function(_, callback: (...any) -> ())
			connect(connTable, callback, coroutine.running)
			coroutine.yield()
		end :: RBXScriptSignal,

		ConnectParallel = Players[eventName].ConnectParallel :: RBXScriptSignal,
	}
end

return module
