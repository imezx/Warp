--!strict
local Index = {}

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Util = script.Util
local Server = script.Server
local Client = script.Client

local Type = require(script.Type)
local Assert = require(Util.Assert)

if IsServer then
	require(Server.ServerProcess).start()
else
	require(Client.ClientProcess).start()
end

function Index.Server(Identifier: string): Type.Server
	Assert(IsServer, `[Warp]: Calling .Server({Identifier}) on client side (expected server side)`)
	Assert(typeof(Identifier) == "string", "[Warp]: Identifier must be a string type")
	return require(Server.Index)(Identifier) :: Type.Server
end
function Index.Client(Identifier: string): Type.Client
	Assert(not IsServer, `[Warp]: Calling .Client({Identifier}) on server side (expected client side)`)
	Assert(typeof(Identifier) == "string", "[Warp]: Identifier must be a string type")
	return require(Client.Index)(Identifier) :: Type.Client
end

return table.freeze(Index) :: typeof(Index)