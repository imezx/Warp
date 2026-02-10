--!optimize 2
--!strict
--@EternityDev
local Client = {}

local RunService = game:GetService("RunService")
local Thread = require("./Thread")
local Buffer = require("./Buffer")
local Event: RemoteEvent = script.Parent:WaitForChild("Event")
local Function: RemoteFunction = script.Parent:WaitForChild("Function")
local deltaT: number, cycle: number = 0, 1 / 61
local writer: Buffer.Writer = Buffer.createWriter()

type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}
type Event = {
	remote: string,
	fn: (Player, ...any?) -> (...any?),
}

local queueEvent: { { any } } = {}
local eventListeners: { Event } = {}

local pendingInvokes: { [string]: thread } = {}
local invokeHandlers: { [string]: (...any?) -> ...any? } = {}
local invokeId = 0

Client.Connect = function(remoteName: string, fn: (Player, ...any?) -> (...any?)): Connection
	local detail = {
		remote = remoteName,
		fn = fn,
	}
	table.insert(eventListeners, detail)
	return {
		Connected = true,
		Disconnect = function(self: Connection)
			if not self.Connected then return end
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
		task.spawn(thread, os.clock()-t, ...)
	end)
	return coroutine.yield()
end

Client.DisconnectAll = function(remoteName: string)
	for idx = #eventListeners, 1, -1 do
		if eventListeners[idx].remote == remoteName then
			table.remove(eventListeners, idx)
		end
	end
end

Client.Destroy = function(remoteName: string)
	Client.DisconnectAll(remoteName)
end

Client.Fire = function(remoteName: string, ...: any?)
	table.insert(queueEvent, {
		remoteName,
		{ ... } :: any
	})
end

Client.Invoke = function(remoteName: string, timeout: number?, ...: any?): ...any?
	invokeId += 1
	local invokeId, thread = `{invokeId}`, coroutine.running()

	pendingInvokes[invokeId] = thread
	task.delay(timeout or 2, function()
		local pending = pendingInvokes[invokeId]
		if not pending then
			return
		end
		task.spawn(pending, nil)
		pendingInvokes[invokeId] = nil
	end)

	table.insert(queueEvent, {
		"\0",
		{ remoteName, invokeId, { ... } :: any } :: any
	})
	return coroutine.yield()
end

if RunService:IsClient() then
	Event.OnClientEvent:Connect(function(b: buffer, ref: { Instance? })
		if type(b) ~= "buffer" then return end
		local contents = Buffer.read(b, ref)
		for _, content in contents do
			local remote = content[1]
			local content = content[2]
			if remote == "\1" then
				local invokeId = content[1]
				local results = content[2]
				local pending = pendingInvokes[invokeId]
				if pending then
					task.spawn(pending :: any, table.unpack(results))
					pendingInvokes[invokeId] = nil
				end
				continue
			end
			if #eventListeners == 0 then continue end
			if remote == "\0" then
				local remoteName = content[1]
				local invokeId = content[2]
				local args = content[3]
				for _, connection in eventListeners do
					if connection.remote == remoteName then
						Thread(function()
							local results = { connection.fn(table.unpack(args)) }
							table.insert(queueEvent, {
								"\1",
								{ invokeId, results } :: any
							})
						end)
						break
					end
				end
				continue
			end
			for _, connection in eventListeners do
				if connection.remote ~= remote then continue end
				Thread(connection.fn, table.unpack(content))
			end
		end
	end)
	RunService.PostSimulation:Connect(function(d: number)
		deltaT += d
		if deltaT < cycle then return end
		deltaT = 0
		if #queueEvent == 0 then return end
		Buffer.pack(writer, queueEvent)
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
	end)
end

return Client :: typeof(Client)
