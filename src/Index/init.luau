--!strict
--!native
--!optimize 2
local Index = {}

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Util = script.Util
local Server = script.Server
local Client = script.Client

local Type = require(script.Type)
local Assert = require(Util.Assert)
local Signal = require(script.Signal)
local Buffer = require(Util.Buffer)

if IsServer then
	require(Server.ServerProcess).start()
else
	require(Client.ClientProcess).start()
end

function Index.Server(Identifier: string, conf: Type.ServerConf?): Type.Server
	Assert(IsServer, `[Warp]: Calling .Server({Identifier}) on client side (expected server side)`)
	Assert(typeof(Identifier) == "string", `[Warp]: Identifier must be a string type, got {typeof(Identifier)}`)
	return require(Server.Index)(Identifier, conf) :: Type.Server
end
function Index.Client(Identifier: string, conf: Type.ClientConf?): Type.Client
	Assert(not IsServer, `[Warp]: Calling .Client({Identifier}) on server side (expected client side)`)
	Assert(typeof(Identifier) == "string", `[Warp]: Identifier must be a string type, got {typeof(Identifier)}`)
	return require(Client.Index)(Identifier, conf) :: Type.Client
end

function Index.fromServerArray(arrays: { any }): Type.fromServerArray
	Assert(IsServer, `[Warp]: Calling .fromServerArray({arrays}) on client side (expected server side)`)
	Assert(typeof(arrays) == "table", "[Warp]: Array must be a table type, got {typeof(arrays)}")
	local copy = {}
	for param1: any, param2: any in arrays do
		if typeof(param2) == "table" then
			copy[param1] = Index.Server(param1, param2)
		else
			copy[param2] = Index.Server(param2)
		end
	end
	return copy :: typeof(copy)
end

function Index.fromClientArray(arrays: { any }): Type.fromClientArray
	Assert(not IsServer, `[Warp]: Calling .fromClientArray({arrays}) on server side (expected client side)`)
	Assert(typeof(arrays) == "table", `[Warp]: Array must be a table type, got {typeof(arrays)}`)
	local copy = {}
	for param1: any, param2: any in arrays do
		if typeof(param2) == "table" then
			copy[param1] = Index.Client(param1, param2)
		else
			copy[param2] = Index.Client(param2)
		end
	end
	return copy :: typeof(copy)
end

function Index.Signal(Identifier: string)
	return Signal(Identifier)
end

function Index.fromSignalArray(arrays: { any })
	Assert(typeof(arrays) == "table", `[Warp]: Array must be a table type, got {typeof(arrays)}`)
	local copy = {}
	for _, identifier: string in arrays do
		copy[identifier] = Index.Signal(identifier)
	end
	return copy :: typeof(copy)
end

function Index.buffer()
	return Buffer.new()
end

return table.freeze(Index) :: typeof(Index)