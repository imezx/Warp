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
local registeredIdentifier: { [string]: boolean } = {}

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

queueInRequest[1] = {}
queueInRequest[2] = {}
queueOutRequest[1] = {}
queueOutRequest[2] = {}

local ReliableEvent = Event.Reliable
local UnreliableEvent = Event.Unreliable
local RequestEvent = Event.Request

function ClientProcess.insertQueue(Identifier: string, reliable: boolean, ...: any)
	if not reliable then
		if not unreliableClientQueue[Identifier] then
			unreliableClientQueue[Identifier] = {}
		end
		table.insert(unreliableClientQueue[Identifier], { ... })
		return
	end
	if not clientQueue[Identifier] then
		clientQueue[Identifier] = {}
	end
	table.insert(clientQueue[Identifier], { ... })
end

function ClientProcess.insertRequest(Identifier: string, timeout: number, ...: any)
	if not clientRequestQueue[Identifier] then
		clientRequestQueue[Identifier] = {}
	end
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

function ClientProcess.add(Identifier: any, originId: string, conf: Type.ClientConf)
	if not registeredIdentifier[Identifier] then
		registeredIdentifier[Identifier] = true

		if not clientRatelimit[Identifier] then
			clientRatelimit[Identifier] = RateLimit.create(originId)
		end
		if not clientQueue[Identifier] then
			clientQueue[Identifier] = {}
		end
		if not unreliableClientQueue[Identifier] then
			unreliableClientQueue[Identifier] = {}
		end
		if not clientRequestQueue[Identifier] then
			clientRequestQueue[Identifier] = {}
		end
		if not clientCallback[Identifier] then
			clientCallback[Identifier] = {}
		end

		if not queueOutRequest[1][Identifier] then
			queueOutRequest[1][Identifier] = {}
		end
		if not queueOutRequest[2][Identifier] then
			queueOutRequest[2][Identifier] = {}
		end
		if not queueInRequest[1][Identifier] then
			queueInRequest[1][Identifier] = {}
		end
		if not queueInRequest[2][Identifier] then
			queueInRequest[2][Identifier] = {}
		end
	end
end

function ClientProcess.remove(Identifier: string)
	if not registeredIdentifier[Identifier] then return end
	registeredIdentifier[Identifier] = nil
	clientQueue[Identifier] = nil
	unreliableClientQueue[Identifier] = nil
	clientRequestQueue[Identifier] = nil
	clientCallback[Identifier] = nil
	clientRatelimit[Identifier] = nil
	queueOutRequest[1][Identifier] = nil
	queueOutRequest[2][Identifier] = nil
	queueInRequest[1][Identifier] = nil
	queueInRequest[2][Identifier] = nil
end

function ClientProcess.addCallback(Identifier: string, key: string, callback)
	clientCallback[Identifier][key] = callback
end

function ClientProcess.removeCallback(Identifier: string, key: string)
	clientCallback[Identifier][key] = nil
end

function ClientProcess.start()
	debug.setmemorycategory("Warp")
	RunService.PostSimulation:Connect(function()
		-- Unreliable
		for Identifier: string, data: any in unreliableClientQueue do
			if #data == 0 then continue end
			if clientRatelimit[Identifier](#data) then
				for _, unpacked in data do
					UnreliableEvent:FireServer(Buffer.revert(Identifier), Buffer.write(unpacked))
				end
			end
			unreliableClientQueue[Identifier] = nil
		end
		-- Reliable
		for Identifier: string, data: any in clientQueue do
			if #data > 0 then
				if clientRatelimit[Identifier](#data) then
					for _, unpacked in data do
						ReliableEvent:FireServer(Buffer.revert(Identifier), Buffer.write(unpacked))
					end
				end
				clientQueue[Identifier] = nil
			end
		end
		-- Sent new invokes
		for Identifier: string, requestsData in queueOutRequest[1] do
			if #requestsData == 0 then continue end
			RequestEvent:FireServer(Buffer.revert(Identifier), "\1", requestsData)
			queueOutRequest[1][Identifier] = nil
		end
		-- Sent returning invokes
		for Identifier: string, toReturnDatas in queueOutRequest[2] do
			if #toReturnDatas == 0 then continue end
			RequestEvent:FireServer(Buffer.revert(Identifier), "\0", toReturnDatas)
			queueOutRequest[2][Identifier] = nil
		end

		for Identifier: string in registeredIdentifier do
			if clientRequestQueue[Identifier] then
				for _, requestData in clientRequestQueue[Identifier] do
					if not requestData[3] then continue end
					if not queueOutRequest[1][Identifier] then
						queueOutRequest[1][Identifier] = {}
					end
					table.insert(queueOutRequest[1][Identifier], { requestData[1], requestData[3] })
					requestData[3] = nil
				end
			end

			-- Unreliable & Reliable
			local callback = clientCallback[Identifier] or nil
			if not callback then continue end

			-- Return Invoke
			if queueInRequest[1][Identifier] then
				for _, packetDatas: any in queueInRequest[1][Identifier] do
					if #packetDatas == 0 then continue end
					for _, fn: any in callback do
						for i=1,#packetDatas do
							if not packetDatas[i] then continue end
							local packetData1 = packetDatas[i][1]
							local packetData2 = packetDatas[i][2]
							Spawn(function()
								local requestReturn = { fn(table.unpack(packetData2)) }
								if not queueOutRequest[2][Identifier] then
									queueOutRequest[2][Identifier] = {}
								end
								table.insert(queueOutRequest[2][Identifier], { packetData1,  requestReturn })
								packetData1 = nil
								packetData2 = nil
							end)
						end
					end
				end
				queueInRequest[1][Identifier] = nil
			end

			-- Call to Invoke
			if queueInRequest[2][Identifier] then
				if clientRequestQueue[Identifier] then
					for _, packetDatas: any in queueInRequest[2][Identifier] do
						for _, packetData in packetDatas do
							if #packetData == 1 then continue end
							for y=1,#clientRequestQueue[Identifier] do
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
				end
				queueInRequest[2][Identifier] = nil
			end
		end
	end)
	local function onClientNetworkReceive(Identifier: buffer | string, data: buffer, ref: { any }?)
		if not Identifier or typeof(Identifier) ~= "buffer" or not data or typeof(data) ~= "buffer" then return end
		Identifier = Buffer.convert(Identifier)
		if not registeredIdentifier[Identifier :: string] then return end
		local read = Buffer.read(data, ref)
		if not read then return end
		local callback = clientCallback[Identifier :: string]
		if not callback then return end
		for _, fn: any in callback do
			Spawn(fn, table.unpack(read))
		end
	end
	ReliableEvent.OnClientEvent:Connect(onClientNetworkReceive)
	UnreliableEvent.OnClientEvent:Connect(onClientNetworkReceive)
	RequestEvent.OnClientEvent:Connect(function(Identifier: any, action: string, data)
		if not Identifier or not data then return end
		Identifier = Buffer.convert(Identifier)
		if action == "\1" then
			if not queueInRequest[1][Identifier] then
				queueInRequest[1][Identifier] = {}
			end
			table.insert(queueInRequest[1][Identifier], data)
		else
			if not queueInRequest[2][Identifier] then
				queueInRequest[2][Identifier] = {}
			end
			table.insert(queueInRequest[2][Identifier], data)
		end
	end)
end

return ClientProcess