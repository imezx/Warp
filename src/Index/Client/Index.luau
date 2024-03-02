--!strict
--!native
local Client = {}
Client.__index = Client

local Players = game:GetService("Players")
local Util = script.Parent.Parent.Util

local ClientProcess = require(script.Parent.ClientProcess)
local Assert = require(Util.Assert)
local Key = require(Util.Key)
local Serdes = require(Util.Serdes)

function Client.new(Identifier: string)
	local self = setmetatable({}, Client)
	self.id = Serdes(Identifier)
	self.fn = {}
	ClientProcess.add(self.id, Identifier)
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
	ClientProcess.addCallback(self.id, key, callback)
	return key
end

function Client:Once(callback: (args: any) -> ()): string
	local key = tostring(Key())
	table.insert(self.fn, key)
	ClientProcess.addCallback(self.id, key, function(...)
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
	for idx, key: string in self.fn do
		ClientProcess.removeCallback(self.id, key)
		table.remove(self.fn, idx)
	end
end

function Client:Disconnect(key: string)
	Assert(typeof(key) == "string", "Key must be a string type.")
	ClientProcess.removeCallback(self.id, key)
end

function Client:Destroy()
	self:DisconnectAll()
	setmetatable(self, nil)
end

return Client.new