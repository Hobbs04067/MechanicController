local RunService = game:GetService("RunService")

local Util = script.Util
local Types = require(Util.Types)

export type MechanicController = Types.MechanicController
export type MechanicInfo = Types.MechanicInfo
export type Mechanic = Types.Mechanic

if RunService:IsServer() then
	local ReplicationEvent = Instance.new("RemoteEvent")
	ReplicationEvent.Parent = script
	ReplicationEvent.Name = "ReplicateController"
end

return require(script.MechanicController)
