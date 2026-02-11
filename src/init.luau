--!strict
--@EternityDev
local Remote = {}

if game.RunService:IsServer() then
	if not script:FindFirstChild("Event") then
		Instance.new("RemoteEvent", script).Name = "Event"
	end
	if not script:FindFirstChild("UnreliableEvent") then
		Instance.new("UnreliableRemoteEvent", script).Name = "UnreliableEvent"
	end
	if not script:FindFirstChild("Function") then
		Instance.new("RemoteFunction", script).Name = "Function"
	end
end

local Client = require("@self/Client")
local Server = require("@self/Server")
local Buffer = require("@self/Buffer")

--[[
	@class Remote
	@client
]]
Remote.Client = function()
	return Client
end

--[[
	@class Remote
	@server
]]
Remote.Server = function()
	return Server
end

--[[
	@class Remote
	@schema
	define a schema for your data and use a strict packing
]]
Remote.Buffer = Buffer

return Remote :: typeof(Remote)
