--!strict
--!native
--!optimize 2
local Client = {}
Client.__index = Client

local Players = game:GetService("Players")
local Util = script.Parent.Parent.Util

local Type = require(script.Parent.Parent.Type)
local ClientProcess = require(script.Parent.ClientProcess)
local Assert = require(Util.Assert)
local Key = require(Util.Key)
local Serdes = require(Util.Serdes)
local Buffer = require(Util.Buffer)

function Client.new(Identifier: string, conf: Type.ClientConf?)
	local self = setmetatable({}, Client)

	self._buffer = Buffer.new()
	self._buffer:wu8(Serdes.increment(Identifier, conf and conf.yieldWait))
	self.id = Buffer.convert(self._buffer:build())
	self.fn = {}
	self._conf = table.freeze(conf or {})
	self.IsConnected = false

	ClientProcess.add(self.id, Identifier, conf or { yieldWait = 10 })
	self._buffer:remove()

	return self
end

function Client:Fire(reliable: boolean,...: any)
	ClientProcess.insertQueue(self.id, reliable, ...)
end

function Client:Invoke(timeout: number, ...: any): any
	return ClientProcess.insertRequest(self.id, timeout, ...)
end

function Client:Connect(callback: (args: any) -> ()): string
	local key = tostring(Key())
	table.insert(self.fn, key)
	self.IsConnected = #self.fn > 0
	ClientProcess.addCallback(self.id, key, callback)
	return key
end

function Client:Once(callback: (args: any) -> ()): string
	local key = tostring(Key())
	table.insert(self.fn, key)
	self.IsConnected = #self.fn > 0
	ClientProcess.addCallback(self.id, key, function(...: any?)
		self:Disconnect(key)
		task.spawn(callback, ...)
	end)
	return key
end

function Client:Wait()
	local thread: thread, t = coroutine.running(), os.clock()
	self:Once(function()
		task.spawn(thread, os.clock()-t)
	end)
	return coroutine.yield()
end

function Client:DisconnectAll()
	for _, key: string in self.fn do
		self:Disconnect(key)
	end
end

function Client:Disconnect(key: string)
	Assert(typeof(key) == "string", "Key must be a string type.")
	ClientProcess.removeCallback(self.id, key)
	table.remove(self.fn, table.find(self.fn, key))
	self.IsConnected = #self.fn > 0
end

function Client:Destroy()
	self:DisconnectAll()
	self._buffer:remove()
	ClientProcess.remove(self.id)
	Serdes.decrement()
	table.clear(self)
	setmetatable(self, nil)
end

return Client.new