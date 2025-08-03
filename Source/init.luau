local RunService = game:GetService("RunService")

if RunService:IsServer() then
     local ReplicationEvent = Instance.new("RemoteEvent")
    ReplicationEvent.Parent = script
    ReplicationEvent.Name = "ReplicateController"
end

return require(script.MechanicController)