--!strict
--@EternityDev

local Remote = {}

if game:GetService("RunService"):IsServer() then
	if not script:FindFirstChild("_repl") then
		Instance.new("RemoteEvent", script).Name = "_repl"
	end
	if not script:FindFirstChild("Event") then
		Instance.new("RemoteEvent", script).Name = "Event"
	end
	if not script:FindFirstChild("UnreliableEvent") then
		Instance.new("UnreliableRemoteEvent", script).Name = "UnreliableEvent"
	end
end

local Client = require("@self/Client")
local Server = require("@self/Server")
local Buffer = require("@self/Util/Buffer")

--[[
	@class Remote
	@client
	client library of `Warp`, use it only on client
]]
Remote.Client = setmetatable(Client, {
	__call = function()
		return Client
	end,
})

--[[
	@class Remote
	@server
	server library of `Warp`, use it only on server
]]
Remote.Server = setmetatable(Server, {
	__call = function()
		return Server
	end,
})

--[[
	@class Remote
	@schema
	define a schema for your data and use a strict packing
]]
Remote.Buffer = Buffer

-- making a strict table from `Warp` (Remote) - catching early errors and preventing changes/replacements of keys in the table
return setmetatable(Remote, {
	__index = function(_self: any, key: any): never
		error(`{key} is not valid member of Warp.\nPlease check documentation here: https://imezx.github.io/Warp/`)
	end,

	__newindex = function(_self: any, key: any, _value: any): never
		error(`{key} is not valid member of Warp.\nPlease check documentation here: https://imezx.github.io/Warp/`)
	end,
}) :: typeof(Remote) -- saving the typing
