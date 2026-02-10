--!strict
--@EternityDev
local Remote = {}

if game.RunService:IsServer() then
	if not script:FindFirstChild("Event") then
		Instance.new("RemoteEvent", script).Name = "Event"
	end
	if not script:FindFirstChild("Function") then
		Instance.new("RemoteFunction", script).Name = "Function"
	end
end

local Client = require("@self/Client")
local Server = require("@self/Server")

Remote.Client = function()
	return Client
end

Remote.Server = function()
	return Server
end

return Remote :: typeof(Remote)
