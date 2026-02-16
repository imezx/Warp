--!optimize 2
--!strict
--@EternityDev
local Client = {}

local RunService = game:GetService("RunService")
local Thread = require("./Util/Thread")
local Buffer = require("./Util/Buffer")
local Replication = require("./Replication")
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

local identifiers: { [string]: number } = {}

local queueEvent: { { any } } = {}
local queueUnreliableEvent: { { any } } = {}
local eventListeners: { Event } = {}
local eventSchemas: { [number]: Buffer.SchemaType } = {}

local pendingInvokes: { [string]: thread } = {}
local invokeId = 0

Client.useSchema = function(remoteName: string, schema: Buffer.SchemaType)
	eventSchemas[Replication.get_id(remoteName)] = schema
end

Client.Connect = function(remoteName: string, fn: (Player, ...any?) -> ...any?): Connection
	local detail = {
		i = Replication.get_id(remoteName),
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

Client.Wait = function(remoteName: string): (number, ...any?)
	local thread, t = coroutine.running(), os.clock()
	Client.Once(remoteName, function(...: any?)
		task.spawn(thread, os.clock() - t, ...)
	end)
	return coroutine.yield()
end

Client.DisconnectAll = function(remoteName: string)
	local id = Replication.get_id(remoteName)
	for idx = #eventListeners, 1, -1 do
		if eventListeners[idx].i == id then
			table.remove(eventListeners, idx)
		end
	end
end

Client.Destroy = Client.DisconnectAll

Client.Fire = function(remoteName: string, reliable: boolean, ...: any?)
	table.insert(reliable and queueEvent or queueUnreliableEvent, {
		Replication.get_id(remoteName),
		{ ... } :: any,
	})
end

Client.Invoke = function(remoteName: string, timeout: number?, ...: any?): ...any?
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
		{ Replication.get_id(remoteName), reqid :: any, { ... } :: any } :: any,
	})
	return coroutine.yield()
end

if RunService:IsClient() then
	local function processIncoming(b: buffer, ref: { Instance }?, handleInvokes: boolean)
		if type(b) ~= "buffer" then
			return
		end
		local contents = Buffer.readEvents(b, ref, eventSchemas)
		for _, content in contents do
			local remote = content[1]
			local content = content[2]
			if handleInvokes then
				if remote == 0 then
					local id = content[1]
					local results = content[2]
					local pending = pendingInvokes[id]
					if pending then
						task.spawn(pending :: any, table.unpack(results))
						pendingInvokes[id] = nil
					end
					continue
				end
				if remote == 1 then
					if #eventListeners == 0 then
						continue
					end
					local remoteName = content[1]
					local id = content[2]
					local args = content[3]
					for _, connection in eventListeners do
						if connection.i == remoteName then
							Thread(function()
								local results = { connection.c(table.unpack(args)) }
								table.insert(queueEvent, {
									1,
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
				Thread(connection.c, table.unpack(content))
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
		if deltaT < cycle then
			return
		end
		deltaT = 0

		-- reliable
		if #queueEvent > 0 then
			Buffer.writeEvents(writer, queueEvent, eventSchemas)
			do
				local buf, ref = Buffer.buildWithRefs(writer)
				Buffer.reset(writer)
				if not ref or #ref == 0 then
					Event:FireServer(buf)
				else
					Event:FireServer(buf, ref)
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
