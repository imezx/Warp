--!optimize 2
local Replication = {}

local RunService = game:GetService("RunService")
local _repl: RemoteEvent = script.Parent:WaitForChild("_repl")

local Buffer = require("./Util/Buffer")
local Identifier = require("./Util/Identifier")

local identifiers_schema = Buffer.Schema.string
local writer: Buffer.Writer = Buffer.createWriter()
local warp_identifier_registry = shared.__warp_identifier_registry

if RunService:IsServer() then
	local replication_ready: { Player } = {}
	local replication_id: number = Identifier.get("id_replication") or 1
	
	if not Identifier.has("id_replication") or not replication_id then
		replication_id = Identifier.get("id_replication") or 1
	end

	local function replicateToAll(content: any, id: number?)
		if #replication_ready == 0 then return end
		local to_repl: any = type(content) == "string" and { content = id } or content
		Buffer.writeRepl(writer, to_repl, warp_identifier_registry.counter, identifiers_schema)
		do
			local buf = Buffer.build(writer)
			Buffer.reset(writer)
			for _, player: Player in replication_ready do
				_repl:FireClient(player, buf, replication_id)
			end
		end
	end

	local function replicateTo(player: Player)
		Buffer.writeRepl(writer, warp_identifier_registry.cache, warp_identifier_registry.counter, identifiers_schema)
		do
			local buf = Buffer.build(writer)
			Buffer.reset(writer)
			_repl:FireClient(player, buf, replication_id)
		end
	end

	Identifier.on_added(replicateToAll)
	
	_repl.OnServerEvent:Connect(function(player: Player)
		if table.find(replication_ready, player) then return end
		table.insert(replication_ready, player)
		replicateTo(player)
	end)
	
	Replication.remove = function(player: Player)
		table.remove(replication_ready, table.find(replication_ready, player))
	end
	
elseif RunService:IsClient() then
	_repl.OnClientEvent:Connect(function(b: buffer, id: number)
		if type(b) ~= "buffer" then
			return
		end
		local contents = Buffer.readRepl(b, identifiers_schema)
		if #contents == 0 then return end
		for _, content in contents do
			warp_identifier_registry.cache[content[2]] = content[1]
		end
	end)
	_repl:FireServer()
	
	Replication.get_id = function(name: string): number
		return warp_identifier_registry.cache[name]
	end
end

return Replication :: typeof(Replication)
