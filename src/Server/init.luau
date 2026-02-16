--!optimize 2
--!strict
--@EternityDev
local Server = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Thread = require("./Util/Thread")
local Buffer = require("./Util/Buffer")
local Identifier = require("./Util/Identifier")
local Replication = require("./Replication")
local Event: RemoteEvent = script.Parent:WaitForChild("Event")
local _repl: RemoteEvent = script.Parent:WaitForChild("_repl")
local UnreliableEvent: UnreliableRemoteEvent = script.Parent:WaitForChild("UnreliableEvent")
local deltaT: number, cycle: number = 0, 1 / 61
local writer: Buffer.Writer = Buffer.createWriter()

type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}
type Event = {
	i: number,
	c: (Player, ...any?) -> ...any?,
}

local queueEvent: {
	[Player]: { { any } },
} = {}
local queueUnreliableEvent: {
	[Player]: { { any } },
} = {}
local eventListeners: { Event } = {}
local eventSchemas: { [number]: Buffer.SchemaType } = {}
local players_ready: { Player }, player_bytes: { [Player]: number } = {}, {}

local pendingInvokes: { [string]: thread } = {}
local invokeId = 0

Server.reg_namespaces = function(namespaces: { string })
	for _, name: string in namespaces do
		Identifier.get_id(name)
	end
end

Server.useSchema = function(remoteName: string, schema: Buffer.SchemaType)
	eventSchemas[Identifier.get_id(remoteName)] = schema
end

Server.Connect = function(remoteName: string, fn: (Player, ...any?) -> ...any?): Connection
	local detail = {
		i = Identifier.get_id(remoteName),
		c = fn,
	}
	table.insert(eventListeners, detail)
	return {
		Connected = true,
		Disconnect = function(self: Connection)
			if not self.Connected then
				return
			end
			self.Connected = false
			local idx = table.find(eventListeners, detail)
			if idx then
				table.remove(eventListeners, idx)
			end
		end,
	} :: Connection
end

Server.Once = function(remoteName: string, fn: (...any?) -> ()): Connection
	local connection
	connection = Server.Connect(remoteName, function(...: any?)
		if connection then
			connection:Disconnect()
		end
		fn(...)
	end)
	return connection
end

Server.Wait = function(remoteName: string): (number, ...any?)
	local thread, t = coroutine.running(), os.clock()
	Server.Once(remoteName, function(...: any?)
		task.spawn(thread, os.clock() - t, ...)
	end)
	return coroutine.yield()
end

Server.DisconnectAll = function(remoteName: string)
	local id = Identifier.get_id(remoteName)
	if not id then
		return
	end
	for idx = #eventListeners, 1, -1 do
		if eventListeners[idx].i == id then
			table.remove(eventListeners, idx)
		end
	end
end

Server.Destroy = Server.DisconnectAll

Server.Fire = function(remoteName: string, reliable: boolean, player: Player, ...: any?)
	local targetQueue = reliable and queueEvent or queueUnreliableEvent
	if not targetQueue[player] then
		targetQueue[player] = {} :: any
	end
	table.insert(targetQueue[player], {
		Identifier.get_id(remoteName),
		{ ... } :: any,
	})
end

Server.Fires = function(remoteName: string, reliable: boolean, ...: any?)
	for _, player: Player in players_ready do
		Server.Fire(remoteName, reliable, player, ...)
	end
end

Server.FireExcept = function(remoteName: string, reliable: boolean, except: { Player }, ...: any?)
	for _, player: Player in players_ready do
		if table.find(except, player) then continue end
		Server.Fire(remoteName, reliable, player, ...)
	end
end

Server.Invoke = function(remoteName: string, player: Player, timeout: number?, ...: any?): ...any?
	invokeId += 1
	local reqId, thread = `{invokeId}`, coroutine.running()

	pendingInvokes[reqId] = thread
	task.delay(timeout or 2, function()
		local pending = pendingInvokes[reqId]
		if not pending then
			return
		end
		task.spawn(pending, nil)
		pendingInvokes[reqId] = nil
	end)
	if not queueEvent[player] then
		queueEvent[player] = {} :: any
	end
	table.insert(queueEvent[player], {
		0,
		{ Identifier.get_id(remoteName), reqId :: any, { ... } :: any } :: any,
	})
	return coroutine.yield()
end

if RunService:IsServer() then
	local function processIncoming(player: Player, b: buffer, ref: { Instance }?, handleInvokes: boolean)
		if type(b) ~= "buffer" then
			return
		end
		local bytes: number = (player_bytes[player] or 0) + math.max(buffer.len(b), 800)
		if bytes > 8e3 then return end
		player_bytes[player] = bytes
		
		local contents = Buffer.readEvents(b, ref, eventSchemas)
		for _, content in contents do
			local remote = content[1]
			local content = content[2]
			if handleInvokes then
				if remote == 1 then
					local id = content[1]
					local results = content[2]
					local pending = pendingInvokes[id]
					if pending then
						task.spawn(pending :: any, table.unpack(results))
						pendingInvokes[id] = nil
					end
					continue
				end
				if remote == 0 then
					if #eventListeners == 0 then
						continue
					end
					local remoteName = content[1]
					local id = content[2]
					local args = content[3]
					for _, connection in eventListeners do
						if connection.i == remoteName then
							Thread(function()
								local results = { connection.c(player, table.unpack(args)) }
								if not queueEvent[player] then
									queueEvent[player] = {} :: any
								end
								table.insert(queueEvent[player], {
									0,
									{ id, results } :: any,
								})
							end)
							break
						end
					end
					continue
				end
			end
			if #eventListeners == 0 then
				continue
			end
			for _, connection in eventListeners do
				if connection.i ~= remote then
					continue
				end
				Thread(connection.c, player, table.unpack(content))
			end
		end
	end

	Event.OnServerEvent:Connect(function(player: Player, b: buffer, ref: { Instance }?)
		processIncoming(player, b, ref, true)
	end)

	UnreliableEvent.OnServerEvent:Connect(function(player: Player, b: buffer, ref: { Instance }?)
		processIncoming(player, b, ref, false)
	end)

	RunService.PostSimulation:Connect(function(d: number)
		deltaT += d
		if deltaT < cycle then
			return
		end
		deltaT = 0

		-- reliable
		for player: Player, content in queueEvent do
			if #content == 0 or player.Parent ~= Players then
				continue
			end
			Buffer.writeEvents(writer, content, eventSchemas)
			do
				local buf, ref = Buffer.buildWithRefs(writer)
				Buffer.reset(writer)
				if not ref or #ref == 0 then
					Event:FireClient(player, buf)
				else
					Event:FireClient(player, buf, ref)
				end
			end
			player_bytes[player] = 0
			table.clear(queueEvent[player])
		end
		-- unreliable
		for player: Player, content in queueUnreliableEvent do
			if #content == 0 or player.Parent ~= Players then
				continue
			end
			Buffer.writeEvents(writer, content, eventSchemas)
			do
				local buf, ref = Buffer.buildWithRefs(writer)
				Buffer.reset(writer)
				if not ref or #ref == 0 then
					UnreliableEvent:FireClient(player, buf)
				else
					UnreliableEvent:FireClient(player, buf, ref)
				end
			end
			table.clear(player_bytes)
			table.clear(queueUnreliableEvent[player])
		end
	end)

	local function onAdded(player: Player)
		if not table.find(players_ready, player) then
			table.insert(players_ready, player)
		end
		if not queueEvent[player] then
			queueEvent[player] = {} :: any
		end
		if not queueUnreliableEvent[player] then
			queueUnreliableEvent[player] = {} :: any
		end
	end
	Players.PlayerAdded:Connect(onAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		Replication.remove(player)
		table.remove(players_ready, table.find(players_ready, player))
		if queueEvent[player] then
			table.clear(queueEvent[player])
			queueEvent[player] = nil
		end
		if player_bytes[player] then
			player_bytes[player] = nil
		end
		if queueUnreliableEvent[player] then
			table.clear(queueUnreliableEvent[player])
			queueUnreliableEvent[player] = nil
		end
	end)
	for _, player: Player in ipairs(Players:GetPlayers()) do
		onAdded(player)
	end
end

--[[
	@class Server
	@schema
	define a schema for your data and use a strict packing
]]
Server.Schema = Buffer.Schema

return Server :: typeof(Server)
