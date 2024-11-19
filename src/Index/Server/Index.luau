--!strict
--!native
--!optimize 2
local Server = {}
Server.__index = Server

local Players = game:GetService("Players")
local Util = script.Parent.Parent.Util

local Type = require(script.Parent.Parent.Type)
local ServerProcess = require(script.Parent.ServerProcess)
local Assert = require(Util.Assert)
local Key = require(Util.Key)
local Serdes = require(Util.Serdes)
local Buffer = require(Util.Buffer)

function Server.new(Identifier: string, conf: Type.ServerConf?)
	local self = setmetatable({}, Server)

	self._buffer = Buffer.new()
	self._buffer:wu8(Serdes.increment(Identifier))
	self.id = Buffer.convert(self._buffer:build())
	self.fn = {}
	self._conf = table.freeze(conf or {})
	self.IsConnected = false

	ServerProcess.add(self.id, Identifier, conf or { rateLimit = { maxEntrance = 200, interval = 2 } })
	self._buffer:remove()

	return self
end

function Server:Fire(reliable: boolean, player: Player, ...: any)
	ServerProcess.insertQueue(self.id, reliable, player, ...)
end

function Server:Fires(reliable: boolean, ...: any)
	for _, player: Player in ipairs(Players:GetPlayers()) do
		ServerProcess.insertQueue(self.id, reliable, player, ...)
	end
end

function Server:FireExcept(reliable: boolean, except: { Player }, ...: any)
	for _, player: Player in ipairs(Players:GetPlayers()) do
		if table.find(except, player) then continue end
		ServerProcess.insertQueue(self.id, reliable, player, ...)
	end
end

function Server:FireIn(reliable: boolean, range: number, from: Vector3, data: { any }, except: { Player }?)
	for _, player: Player in ipairs(Players:GetPlayers()) do
		if (except and table.find(except, player)) or not player.Character or not player.Character.PrimaryPart or (player.Character.PrimaryPart.Position - from).Magnitude < range then continue end
		ServerProcess.insertQueue(self.id, reliable, player, table.unpack(data))
	end
end

function Server:Invoke(timeout: number, player: Player, ...: any): any
	return ServerProcess.insertRequest(self.id, timeout, player, ...)
end

function Server:Connect(callback: (plyer: Player, args: any) -> ()): string
	local key = tostring(Key())
	table.insert(self.fn, key)
	ServerProcess.addCallback(self.id, key, callback)
	self.IsConnected = #self.fn > 0
	return key
end

function Server:Once(callback: (plyer: Player, args: any) -> ()): string
	local key = tostring(Key())
	table.insert(self.fn, key)
	self.IsConnected = #self.fn > 0
	ServerProcess.addCallback(self.id, key, function(player: Player, ...: any?)
		self:Disconnect(key)
		task.spawn(callback, player, ...)
	end)
	return key
end

function Server:Wait()
	local thread: thread, t = coroutine.running(), os.clock()
	self:Once(function()
		task.spawn(thread, os.clock()-t)
	end)
	return coroutine.yield()
end

function Server:DisconnectAll()
	for _, key: string in self.fn do
		self:Disconnect(key)
	end
end

function Server:Disconnect(key: string): boolean
	Assert(typeof(key) == "string", "Key must be a string type.")
	ServerProcess.removeCallback(self.id, key)
	table.remove(self.fn, table.find(self.fn, key))
	self.IsConnected = #self.fn > 0
	return table.find(self.fn, key) == nil
end

function Server:Destroy()
	self:DisconnectAll()
	self._buffer:remove()
	ServerProcess.remove(self.id)
	Serdes.decrement()
	table.clear(self)
	setmetatable(self, nil)
end

return Server.new