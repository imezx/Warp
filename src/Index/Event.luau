--!strict
local RunService = game:GetService("RunService")
local Type = require(script.Parent.Type)

if RunService:IsServer() then
	if not script:FindFirstChild("Event") then
		Instance.new("RemoteEvent", script).Name = "Event"
	end
	if not script:FindFirstChild("Event2") then
		Instance.new("RemoteEvent", script).Name = "Event2"
	end
	if not script:FindFirstChild("Request") then
		Instance.new("RemoteEvent", script).Name = "Request"
	end
elseif not script:FindFirstChild("Event") or not script:FindFirstChild("Event2") or not script:FindFirstChild("Request") then
	repeat task.wait() until script:FindFirstChild("Event") and script:FindFirstChild("Event2") and script:FindFirstChild("Request")
end

return {
	Reliable = script.Event,
	Unreliable = script.Event2,
	Request = script.Request
} :: Type.Event