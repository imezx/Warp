--!native
--!strict
--!optimize 2
local ClientProcess = {}

local RunService = game:GetService("RunService")
local Util = script.Parent.Parent.Util

local Type = require(script.Parent.Parent.Type)
local Event = require(script.Parent.Parent.Event)
local Spawn = require(Util.Spawn)
local Key = require(Util.Key)
local RateLimit = require(Util.RateLimit)
local Buffer = require(Util.Buffer)

local clientRatelimit: Type.StoredRatelimit = {}
local clientQueue: Type.QueueMap = {}
local unreliableClientQueue: Type.QueueMap = {}
local clientCallback: Type.CallbackMap = {}
local clientRequestQueue: Type.QueueMap = {}

local queueIn: {
	[string]: {any}
} = {}
local queueInRequest: {
	[number]: {
		[string]: {
			any
		}
	}
} = {}
local queueOutRequest: {
	[number]: {
		[string]: {
			any
		}
	}
} = {}
local incoming_cache: {
	[string]: {
		any
	}
} = {}

queueInRequest[1] = {}
queueInRequest[2] = {}
queueOutRequest[1] = {}
queueOutRequest[2] = {}

local ReliableEvent = Event.Reliable
local UnreliableEvent = Event.Unreliable
local RequestEvent = Event.Request

function ClientProcess.insertQueue(Identifier: string, reliable: boolean, ...: any)
	if not reliable then
		table.insert(unreliableClientQueue[Identifier], { ... })
		return
	end
	table.insert(clientQueue[Identifier], { ... })
end

function ClientProcess.insertRequest(Identifier: string, timeout: number, ...: any)
	local yieldThread: thread, start = coroutine.running(), os.clock()
	local cancel = task.delay(timeout, function()
		task.spawn(yieldThread, nil)
	end)
	table.insert(clientRequestQueue[Identifier], { tostring(Key()), function(...: any)
		if (os.clock() - start) > timeout then  return end
		task.cancel(cancel)
		task.spawn(yieldThread, ...)
	end :: any, { ... } :: any })
	return coroutine.yield()
end

function ClientProcess.add(Identifier: string, originId: string)
	if not clientQueue[Identifier] then
		clientRatelimit[Identifier] = RateLimit.create(originId)
		clientQueue[Identifier] = {}
		unreliableClientQueue[Identifier] = {}
		clientRequestQueue[Identifier] = {}
		clientCallback[Identifier] = {}
		
		queueOutRequest[1][Identifier] = {}
		queueOutRequest[2][Identifier] = {}
		queueInRequest[1][Identifier] = {}
		queueInRequest[2][Identifier] = {}
		queueIn[Identifier] = {}
	end
end

function ClientProcess.addCallback(Identifier: string, key: string, callback)
	clientCallback[Identifier][key] = callback
end

function ClientProcess.removeCallback(Identifier: string, key: string)
	clientCallback[Identifier][key] = nil
end

function ClientProcess.start()
	RunService.PostSimulation:Connect(function()
		for Identifier: string, data: any in unreliableClientQueue do
			if #data == 0 then continue end
			if clientRatelimit[Identifier](#data) then
				UnreliableEvent:FireServer(Buffer.revert(Identifier), data)
			end
			table.clear(data)
		end
		for Identifier: string, data: any in clientQueue do
			if #data > 0 then
				if clientRatelimit[Identifier](#data) then
					ReliableEvent:FireServer(Buffer.revert(Identifier), data)
				end
				table.clear(data)
			end
			if #clientRequestQueue[Identifier] > 0 then
				for _, requestData in clientRequestQueue[Identifier] do
					if not requestData[3] then continue end
					table.insert(queueOutRequest[1][Identifier], { requestData[1], requestData[3] })
					table.remove(requestData, #requestData)
				end
			end
			if incoming_cache[Identifier] then
				for _, packet in incoming_cache[Identifier] do
					if not queueIn[Identifier] then continue end
					table.insert(queueIn[Identifier], table.clone(packet))
					table.clear(incoming_cache[Identifier])
				end
			end
			if clientCallback[Identifier] then
				if #queueIn[Identifier] > 0 then
					for _, packedDatas: any in queueIn[Identifier] do
						if #packedDatas == 0 then continue end
						for _, fn: any in clientCallback[Identifier] do
							for i=1,math.min(1e3, #packedDatas) do
								Spawn(fn, table.unpack(packedDatas[i] or {}))
							end
						end
					end
					table.clear(queueIn[Identifier])
				end
				if #queueInRequest[1][Identifier] > 0 then
					for idx, packetDatas: any in queueInRequest[1][Identifier] do
						if #packetDatas == 0 then continue end
						for _, fn: any in clientCallback[Identifier] do
							for i=1,math.min(1e3, #packetDatas) do
								local packetData = packetDatas[i]
								if not packetData then continue end
								Spawn(function()
									local requestReturn = { fn(table.unpack(packetData[2])) }
									table.insert(queueOutRequest[2][Identifier], { packetData[1],  requestReturn })
								end)
							end
						end
					end
					table.clear(queueInRequest[1][Identifier])
				end
				if #queueInRequest[2][Identifier] > 0 then
					for _, packetDatas: any in queueInRequest[2][Identifier] do
						for _, packetData in packetDatas do
							if #packetData == 1 then continue end
							for y=1, math.min(1e3, #clientRequestQueue[Identifier]) do
								local clientRequest = clientRequestQueue[Identifier][y]
								if not clientRequest then continue end
								if clientRequest[1] == packetData[1] then
									Spawn(clientRequest[2], table.unpack(packetData[2]))
									table.remove(clientRequestQueue[Identifier], y)
									break
								end
							end
						end
					end
					table.clear(queueInRequest[2][Identifier])
				end
			end
		end
		for Identifier: string, requestsData in queueOutRequest[1] do
			if #requestsData == 0 then continue end
			RequestEvent:FireServer(Buffer.revert(Identifier), "\1", requestsData)
			table.clear(queueOutRequest[1][Identifier])
		end
		for Identifier: string, requestsData in queueOutRequest[2] do
			if #requestsData == 0 then continue end
			RequestEvent:FireServer(Buffer.revert(Identifier), "\0", requestsData)
			table.clear(queueOutRequest[2][Identifier])
		end
	end)
	local function onClientNetworkReceive(Identifier: any, data: any)
		if not Identifier or not data then return end
		Identifier = Buffer.convert(Identifier)
		if not queueIn[Identifier] then
			queueIn[Identifier] = {}
		end
		if not clientCallback[Identifier] then
			if not incoming_cache[Identifier] then
				incoming_cache[Identifier] = {}
			end
			table.insert(incoming_cache[Identifier], data)
			return
		end
		table.insert(queueIn[Identifier], data)
	end
	ReliableEvent.OnClientEvent:Connect(onClientNetworkReceive)
	UnreliableEvent.OnClientEvent:Connect(onClientNetworkReceive)
	RequestEvent.OnClientEvent:Connect(function(Identifier: any, action: string, returnDatas)
		if not Identifier or not returnDatas then return end
		Identifier = Buffer.convert(Identifier)
		if action == "\1" then
			table.insert(queueInRequest[1][Identifier], returnDatas)
		else
			table.insert(queueInRequest[2][Identifier], returnDatas)
		end
	end)
end

return ClientProcess