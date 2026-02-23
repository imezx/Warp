--!optimize 2
--!strict
local Replication = {}

local RunService = game:GetService("RunService")
local _repl: RemoteEvent = script.Parent:WaitForChild("_repl")

local Buffer = require("./Util/Buffer")
local Identifier = require("./Util/Identifier")

local identifiers_schema = Buffer.Schema.string
local warp_identifier_registry = shared.__warp_identifier_registry

if RunService:IsClient() or RunService:IsRunMode() then
	local pending_id_yields, pending_name_yields, ready_yields = {}, {}, {}
	local is_ready = false
	
	if RunService:IsClient() then
		_repl.OnClientEvent:Connect(function(b: buffer)
			if type(b) ~= "buffer" then
				return
			end
			local contents = Buffer.readRepl(b, identifiers_schema)
			if #contents == 0 then return end
			for _, content in contents do
				local id, remote = content[1], content[2]
				warp_identifier_registry.cache[remote] = id
				warp_identifier_registry.name[id] = remote
				
				if pending_id_yields[remote] then
					for _, thread in pending_id_yields[remote] do
						task.spawn(thread, id)
					end
					pending_id_yields[remote] = nil
				end
				if pending_name_yields[id] then
					for _, thread in pending_name_yields[id] do
						task.spawn(thread, remote)
					end
					pending_name_yields[id] = nil
				end
			end
			if not is_ready then
				is_ready = true
				for _, thread in ready_yields do
					task.spawn(thread :: thread)
				end
				table.clear(ready_yields)
			end
		end)
		_repl:FireServer()
	end

	--@yield
	-- wait for the identifiers to be replicated from the server
	Replication.wait_for_ready = function()
		if is_ready then return end

		local thread = coroutine.running()
		table.insert(ready_yields, thread)
		coroutine.yield()
	end

	--@name string
	--@timeout number (default: 0)
	Replication.get_id = function(name: string, timeout: number?): number
		local cached = warp_identifier_registry.cache[name]
		if cached or type(timeout) ~= "number" then return cached end

		local thread = coroutine.running()

		if not pending_id_yields[name] then pending_id_yields[name] = {} end
		table.insert(pending_id_yields[name], thread)

		task.delay(timeout, function()
			if pending_id_yields[name] then
				local idx = table.find(pending_id_yields[name], thread)
				if idx then
					table.remove(pending_id_yields[name], idx)
					task.spawn(thread, nil)
				end
			end
		end)

		local obj: number = coroutine.yield()
		if not obj then
			warn(`[Replication] timeout: could not find identifier '{name}' after {timeout}s.`)
		end
		return obj
	end
	
	--@name string
	--@timeout number (default: 0)
	Replication.get_name = function(id: number, timeout: number?): string
		local cached = warp_identifier_registry.name[id]
		if cached or type(timeout) ~= "number" then return cached end

		local thread = coroutine.running()
		if not pending_name_yields[id] then pending_name_yields[id] = {} end
		table.insert(pending_name_yields[id], thread)

		task.delay(timeout, function()
			if pending_name_yields[id] then
				local idx = table.find(pending_name_yields[id], thread)
				if idx then
					table.remove(pending_name_yields[id], idx)
					task.spawn(thread, nil)
				end
			end
		end)

		local obj: string = coroutine.yield()
		if not id then
			warn(`[Replication] timeout: could not find identifier '{id}' after {timeout}s.`)
		end
		return obj
	end
else
	local replication_ready: { Player }, pending_replications = {}, {}
	local writer: Buffer.Writer = Buffer.createWriter()
	local replication_id: number = Identifier.get_id("id_replication") or 1
	local is_scheduled = false

	if not Identifier.has_name("id_replication") or not replication_id then
		replication_id = Identifier.get_id("id_replication") or 1
	end

	local function replicateToAll(content: any, id: number?)
		if #replication_ready == 0 then return end

		if type(content) == "string" and id then
			pending_replications[content] = id
		else
			for k, v in content :: any do
				pending_replications[k] = v
			end
		end

		if not is_scheduled then
			is_scheduled = true
			task.defer(function()
				is_scheduled = false

				local count = 0
				for _ in pending_replications do count += 1 end
				if count == 0 then return end

				Buffer.writeRepl(writer, pending_replications, count, identifiers_schema)
				local buf = Buffer.build(writer)
				Buffer.reset(writer)

				for _, player: Player in replication_ready do
					_repl:FireClient(player, buf)
				end

				table.clear(pending_replications)
			end)
		end
	end

	local function replicateTo(player: Player)
		Buffer.writeRepl(writer, warp_identifier_registry.cache, warp_identifier_registry.counter, identifiers_schema)
		do
			local buf = Buffer.build(writer)
			Buffer.reset(writer)
			_repl:FireClient(player, buf)
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
end

return Replication :: typeof(Replication)
