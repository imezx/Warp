--!optimize 2
--!strict
--@EternityDev
local Client = {}

local Thread = require("./Util/Thread")
local Buffer = require("./Util/Buffer")
local Replication = require("./Replication")
local Xor = require("./Util/Xor")

local RunService = game:GetService("RunService")
local Event: RemoteEvent = script.Parent:WaitForChild("Event")
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

local queueEvent: { { any } } = {}
local queueUnreliableEvent: { { any } } = {}
local eventListeners: { [number]: { Event } } = {}
local eventSchemas: { [number]: Buffer.SchemaType } = {}

local lastDelta: { [number]: { any } } = {}
local pendingInvokes: { [string]: thread } = {}
local invokeId = 0

--@optional
-- Yields the current thread until the client has successfully initialized and synchronized with the server's replication data (identifier). Its optionally, but highly recommended to call this before firing or connecting to any events to ensure the network is fully ready.
Client.awaitReady = Replication.wait_for_ready

--@remoteName string
--@schema Buffer.SchemaType
-- Define a schema for strict data packing on a specific event.
Client.useSchema = function(remoteName: string, schema: Buffer.SchemaType)
	local id = Replication.get_id[remoteName]
	if not id then
		warn(`[Warp]: ".useSchema"::"{remoteName}" does not exist, likely its not registered on the server yet.`)
		return
	end
	eventSchemas[id] = schema
end

--@remoteName string
--@fn function
-- Connect to an event to receive incoming data from the server.
Client.Connect = function(remoteName: string, fn: (Player, ...any?) -> ...any?): Connection
	local id = Replication.get_id[remoteName]
	if not id then
		warn(`[Warp]: ".Connect"::"{remoteName}" does not exist, likely its not registered on the server yet.`)
		return {
			Connected = false,
			Disconnect = function()
				return
			end,
		} :: Connection
	end
	local detail = {
		i = id,
		c = fn,
	}
	if not eventListeners[id] then
		eventListeners[id] = {}
	end
	table.insert(eventListeners[id], detail)
	return {
		Connected = true,
		Disconnect = function(self: Connection)
			if not self.Connected then
				return
			end
			self.Connected = false
			local bucket = eventListeners[detail.i]
			if bucket then
				local idx = table.find(bucket, detail)
				if idx then
					table.remove(bucket, idx)
				end
			end
		end,
	} :: Connection
end

--@remoteName string
--@fn function
-- Similar to :Connect but automatically disconnects after the first firing.
Client.Once = function(remoteName: string, fn: (...any?) -> ()): Connection
	local connection
	connection = Client.Connect(remoteName, function(...: any?)
		if connection then
			connection:Disconnect()
		end
		fn(...)
	end)
	return connection
end

--@remoteName string
-- Wait for an event to be triggered. Yields the current thread.
Client.Wait = function(remoteName: string): (number, ...any?)
	local thread, t = coroutine.running(), os.clock()
	Client.Once(remoteName, function(...: any?)
		task.spawn(thread, os.clock() - t, ...)
	end)
	return coroutine.yield()
end

--@remoteName string
-- Disconnect all connections for a specific event.
Client.DisconnectAll = function(remoteName: string)
	local id = Replication.get_id[remoteName]
	if not id then
		return
	end
	eventListeners[id] = nil
end

--@remoteName string
-- Disconnect all connections and remove the event.
Client.Destroy = Client.DisconnectAll

--@remoteName string
--@reliable boolean
-- Fire an event to the server.
Client.Fire = function(remoteName: string, reliable: boolean, ...: any?)
	local id = Replication.get_id[remoteName]
	if id then
		table.insert(reliable and queueEvent or queueUnreliableEvent, {
			Replication.get_id[remoteName],
			{ ... } :: any,
		})
	end
end

--@remoteName string
--@timeout number?
-- Invoke the server with timeout support. Yields the current thread. Returns nil if timeout occurs.
Client.Invoke = function(remoteName: string, timeout: number?, ...: any?): ...any?
	local id = Replication.get_id[remoteName]
	if not id then
		return nil
	end
	invokeId += 1
	local reqid, thread = `{invokeId}`, coroutine.running()

	pendingInvokes[reqid] = thread
	task.delay(timeout or 2, function()
		local pending = pendingInvokes[reqid]
		if not pending then
			return
		end
		task.spawn(pending, nil)
		pendingInvokes[reqid] = nil
	end)
	table.insert(queueEvent, {
		0,
		{ id, reqid :: any, { ... } :: any } :: any,
	})
	return coroutine.yield()
end

if RunService:IsClient() then
	local function processIncoming(b: buffer, ref: { Instance }?, handleInvokes: boolean)
		if type(b) ~= "buffer" then return end
		local decoded: buffer = handleInvokes and Xor.decodeClient(b) or b
		local contents = Buffer.readEvents(decoded, ref, eventSchemas)
		for _, content in contents do
			local remote = content[1]
			local args = content[2]
			if handleInvokes then
				if remote == 0 then
					local id = args[1]
					local results = args[2]
					local pending = pendingInvokes[id]
					if pending then
						task.spawn(pending :: any, table.unpack(results))
						pendingInvokes[id] = nil
					end
					continue
				end
				if remote == 1 then
					local remoteName, id, rargs = args[1], args[2], args[3]
					local connections = eventListeners[remoteName]
					if connections and #connections > 0 then
						Thread(function()
							local results = { connections[1].c(table.unpack(rargs)) }
							table.insert(queueEvent, { 1, { id, results } :: any })
						end)
					end
					continue
				end
			end
			local connections = eventListeners[remote]
			if connections then
				for _, connection in connections do
					Thread(connection.c, table.unpack(args))
				end
			end
		end
	end

	Event.OnClientEvent:Connect(function(b: buffer, ref: { Instance }?)
		processIncoming(b, ref, true)
	end)

	UnreliableEvent.OnClientEvent:Connect(function(b: buffer, ref: { Instance }?)
		processIncoming(b, ref, false)
	end)

	RunService.PostSimulation:Connect(function(d: number)
		deltaT += d
		if deltaT < cycle then return end
		deltaT = 0
		
		--reliable
		if #queueEvent > 0 then
			Buffer.writeEvents(writer, queueEvent, eventSchemas)
			do
				local buf, ref = Buffer.buildWithRefs(writer)
				local encoded = Xor.encodeClient(buf)
				Buffer.reset(writer)
				if not ref or #ref == 0 then
					Event:FireServer(encoded)
				else
					Event:FireServer(encoded, ref)
				end
			end
			table.clear(queueEvent)
		end
		-- unreliable
		if #queueUnreliableEvent > 0 then
			Buffer.writeEvents(writer, queueUnreliableEvent, eventSchemas)
			do
				local buf, ref = Buffer.buildWithRefs(writer)
				Buffer.reset(writer)
				if not ref or #ref == 0 then
					UnreliableEvent:FireServer(buf)
				else
					UnreliableEvent:FireServer(buf, ref)
				end
			end
			table.clear(queueUnreliableEvent)
		end
	end)
end

--[[
    @class Client
    @schema
    define a schema for your data and use a strict packing
]]
Client.Schema = Buffer.Schema

return Client :: typeof(Client)
