--!native
--!strict
--!optimize 2
local ServerProcess = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Util = script.Parent.Parent.Util

local Type = require(script.Parent.Parent.Type)
local Event = require(script.Parent.Parent.Event)
local Spawn = require(Util.Spawn)
local Key = require(Util.Key)
local RateLimit = require(Util.RateLimit)
local Buffer = require(Util.Buffer)
local Logger = require(script.Logger)

local serverQueue: Type.QueueMap = {}
local unreliableServerQueue: Type.QueueMap = {}
local serverCallback: Type.CallbackMap = {}
local serverRequestQueue: Type.QueueMap = {}
local registeredIdentifier: { string } = {}

local queueOut: {
	[Player]: {
		[string]: {any},
	}
} = {}
local queueIn: {
	[string]: {
		[Player]: {any},
	}
} = {}
local queueInRequest: {
	[number]: {
		[string]: {
			[Player]: {any}
		}
	}
} = {}
local queueOutRequest: {
	[number]: {
		[string]: {
			[Player]: {any}
		}
	}
} = {}
local logger: {
	[string]: boolean
} = {}
local players: {
	Player
} = {}

queueInRequest[1] = {}
queueInRequest[2] = {}
queueOutRequest[1] = {}
queueOutRequest[2] = {}

local ReliableEvent = Event.Reliable
local UnreliableEvent = Event.Unreliable
local RequestEvent = Event.Request

local function initializeEachPlayer(player: Player)
	if not player then return end
	if not queueOut[player] then
		queueOut[player] = {}
	end

	for _, Identifier: string in registeredIdentifier do
		if not player then break end
		if not queueOut[player][Identifier] then
			queueOut[player][Identifier] = {}
		end
		if not serverRequestQueue[Identifier][player] then
			serverRequestQueue[Identifier][player] = {}
		end
		if not queueIn[Identifier][player] then
			queueIn[Identifier][player] = {}
		end
		if not queueInRequest[1][Identifier][player] then
			queueInRequest[1][Identifier][player] = {}
			queueInRequest[2][Identifier][player] = {}
		end
		if not queueOutRequest[1][Identifier][player] then
			queueOutRequest[1][Identifier][player] = {}
			queueOutRequest[2][Identifier][player] = {}
		end
	end
end

Players.PlayerAdded:Connect(initializeEachPlayer)

function ServerProcess.insertQueue(Identifier: string, reliable: boolean, player: Player, ...: any)
	if not reliable then
		if not unreliableServerQueue[Identifier][player] then
			unreliableServerQueue[Identifier][player] = {}
		end
		table.insert(unreliableServerQueue[Identifier][player], { ... })
		return
	end
	if not serverQueue[Identifier][player] then
		serverQueue[Identifier][player] = {}
	end
	table.insert(serverQueue[Identifier][player], { ... })
end

function ServerProcess.insertRequest(Identifier: string, timeout: number, player: Player, ...: any)
	if not serverQueue[Identifier][player] then
		serverQueue[Identifier][player] = {}
	end
	if not serverRequestQueue[Identifier] then
		serverRequestQueue[Identifier] = {}
	end
	local yieldThread: thread, start = coroutine.running(), os.clock()
	local cancel = task.delay(timeout, function()
		task.spawn(yieldThread, nil)
	end)
	table.insert(serverRequestQueue[Identifier][player], { tostring(Key()), function(...: any)
		if (os.clock() - start) > timeout then return end
		task.cancel(cancel)
		task.spawn(yieldThread, ...)
	end :: any, { ... } :: any })
	return coroutine.yield()
end

function ServerProcess.add(Identifier: string, originId: string, conf: Type.ServerConf)
	if not table.find(registeredIdentifier, Identifier) then
		table.insert(registeredIdentifier, Identifier)
		RateLimit.create(originId, conf.rateLimit and conf.rateLimit.maxEntrance or 200, conf.rateLimit and conf.rateLimit.interval or 2)
		if conf.logging then
			ServerProcess.logger(Identifier, conf.logging.store, conf.logging.opt)
		end
		if not serverQueue[Identifier] then
			serverQueue[Identifier] = {}
		end
		if not serverRequestQueue[Identifier] then
			serverRequestQueue[Identifier] = {}
		end
		if not serverCallback[Identifier] then
			serverCallback[Identifier] = {}
		end
		if not unreliableServerQueue[Identifier] then
			unreliableServerQueue[Identifier] = {}
		end

		if not queueIn[Identifier] then
			queueIn[Identifier] = {}
		end
		if not queueInRequest[1][Identifier] then
			queueInRequest[1][Identifier] = {}
		end
		if not queueInRequest[2][Identifier] then
			queueInRequest[2][Identifier] = {}
		end
		if not queueOutRequest[1][Identifier] then
			queueOutRequest[1][Identifier] = {}
		end
		if not queueOutRequest[2][Identifier] then
			queueOutRequest[2][Identifier] = {}
		end

		for _, player: Player in ipairs(Players:GetPlayers()) do
			task.spawn(initializeEachPlayer, player)
		end
	end
end

function ServerProcess.logger(Identifier: string, store: boolean, log: boolean)
	logger[Identifier] = store
	Logger.write(Identifier, `state: change -> {log == true and "enabled" or "disabled"} logger.`, log)
end

function ServerProcess.getlogs(Identifier: string)
	return Logger.read(Identifier)
end

function ServerProcess.addCallback(Identifier: string, key: string, callback)
	serverCallback[Identifier][key] = callback
	if logger[Identifier] then
		task.defer(Logger.write, Identifier, `state: change -> new callback added.`)
	end
end

function ServerProcess.removeCallback(Identifier: string, key: string)
	serverCallback[Identifier][key] = nil
	if logger[Identifier] then
		task.defer(Logger.write, Identifier, `state: change -> removed a callback.`)
	end
end

function ServerProcess.start()
	debug.setmemorycategory("Warp")
	RunService.PostSimulation:Connect(function()
		for Identifier: string, players in unreliableServerQueue do
			for player: Player, content: any in players do
				if #content == 0 then continue end
				UnreliableEvent:FireClient(player, Buffer.revert(Identifier), content)
				if logger[Identifier] then
					task.defer(Logger.write, Identifier, `state: out -> unreliable -> {#content} data.`)
				end
				unreliableServerQueue[Identifier][player] = nil
			end
		end

		for Identifier: string, contents: { [Player]: { any } } in serverQueue do
			
			for player: Player, requestsData: any in queueOutRequest[1][Identifier] do
				if #requestsData > 0 then
					RequestEvent:FireClient(player, Buffer.revert(Identifier), "\1", requestsData)
					if logger[Identifier] then
						task.defer(Logger.write, Identifier, `state: out -> request -> {#requestsData} data.`)
					end
				end
				queueOutRequest[1][Identifier][player] = nil
			end
			
			for player: Player, toReturnDatas: any in queueOutRequest[2][Identifier] do
				if #toReturnDatas > 0 then
					RequestEvent:FireClient(player, Buffer.revert(Identifier), "\0", toReturnDatas)
					if logger[Identifier] then
						task.defer(Logger.write, Identifier, `state: out -> return request -> {#toReturnDatas} data.`)
					end
				end
				queueOutRequest[2][Identifier][player] = nil
			end
			
			local callback = serverCallback[Identifier] or nil
			for player, content: any in contents do
				if #content > 0 and queueOut[player] then
					ReliableEvent:FireClient(player, Buffer.revert(Identifier), content)
				end
				serverQueue[Identifier][player] = nil
				
				if serverRequestQueue[Identifier][player] then
					for _, requestData in serverRequestQueue[Identifier][player] do
						if not requestData[3] then continue end
						if not queueOutRequest[1][Identifier][player] then
							queueOutRequest[1][Identifier][player] = {}
						end
						table.insert(queueOutRequest[1][Identifier][player], { requestData[1], requestData[3] })
					end
					serverRequestQueue[Identifier][player] = nil
				end
				
				if callback then
					local requestIn1: any = queueInRequest[1][Identifier][player]
					local requestIn2: any = queueInRequest[2][Identifier][player]
					local incoming: any = queueIn[Identifier][player]

					if incoming then
						for _, packedDatas: any in incoming do
							if #packedDatas == 0 then continue end
							for _, fn: any in callback do
								for i=1,#packedDatas do
									Spawn(fn, player, table.unpack(packedDatas[i] or {}))
								end
							end
						end
						incoming = nil
						queueIn[Identifier][player] = nil
					end
					if requestIn1 then
						for _, packetDatas: any in requestIn1 do
							if #packetDatas == 0 then continue end
							for _, fn: any in callback do
								for i=1,#packetDatas do
									local packetData = packetDatas[i]
									if not packetData then continue end
									Spawn(function()
										local requestReturn = { fn(player, table.unpack(packetData[2])) }
										local state = queueOutRequest[2][Identifier][player]
										if not queueOutRequest[2][Identifier][player] then
											queueOutRequest[2][Identifier][player] = {}
										end
										table.insert(queueOutRequest[2][Identifier][player], { packetData[1], requestReturn })
									end)
								end
							end
						end
						requestIn1 = nil
						queueInRequest[1][Identifier][player] = nil
					end
					if requestIn2 then
						for _, packetDatas: any in requestIn2 do
							for _, packetData in packetDatas do
								if #packetData == 1 then continue end
								local data = serverRequestQueue[Identifier][player]
								for i=1,#data do
									local serverRequest = data[i]
									if not serverRequest then continue end
									if serverRequest[1] == packetData[1] then
										Spawn(serverRequest[2], table.unpack(packetData[2]))
										table.remove(data, i)
										break
									end
								end
							end
						end
						requestIn2 = nil
						queueInRequest[2][Identifier][player] = nil
					end
				end
			end
		end
	end)
	local function onServerNetworkReceive(player: Player, Identifier: any, data: any)
		if not Identifier or not data then return end
		Identifier = Buffer.convert(Identifier)
		if not serverQueue[Identifier] then
			serverQueue[Identifier] = {}
		end
		if not serverQueue[Identifier][player] then
			serverQueue[Identifier][player] = {}
		end
		if not queueIn[Identifier][player] then
			queueIn[Identifier][player] = {}
		end
		if logger[Identifier] then
			task.defer(Logger.write, Identifier, `state: in -> net -> {#data} data.`)
		end
		table.insert(queueIn[Identifier][player], data)
	end
	ReliableEvent.OnServerEvent:Connect(onServerNetworkReceive)
	UnreliableEvent.OnServerEvent:Connect(onServerNetworkReceive)
	RequestEvent.OnServerEvent:Connect(function(player: Player, Identifier: any, action: string, data: any)
		if not Identifier or not data then return end
		Identifier = Buffer.convert(Identifier)
		if not queueInRequest[1][Identifier][player] then
			queueInRequest[1][Identifier][player] = {}
			queueInRequest[2][Identifier][player] = {}
		end
		if not serverQueue[Identifier][player] then
			serverQueue[Identifier][player] = {}
		end
		if action == "\1" then
			table.insert(queueInRequest[1][Identifier][player], data)
		else
			table.insert(queueInRequest[2][Identifier][player], data)
		end
		if logger[Identifier] then
			task.defer(Logger.write, Identifier, `state: in -> request -> {#data} data.`)
		end
	end)
end

for _, player: Player in ipairs(Players:GetPlayers()) do
	task.spawn(initializeEachPlayer, player)
end

return ServerProcess