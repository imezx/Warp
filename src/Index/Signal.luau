--!strict
--!native
local Signal = {}
Signal.__index = Signal

local Util = script.Parent.Util
local Key = require(Util.Key)
local Spawn = require(Util.Spawn)
local Assert = require(Util.Assert)

local Signals = {}

function Signal.new(Identifier: string)
	Assert(typeof(Identifier) == "string", `[Signal]: Identifier must be a string type, got {typeof(Identifier)}`)
	if not Signals[Identifier] then
		local signal = setmetatable({}, Signal)
		signal.id = Identifier
		signal.fn = {}
		Signals[Identifier] = signal
		return signal
	end
	return Signals[Identifier]
end

function Signal:Fire(...: any): ()
	for _, fn in self.fn do
		Spawn(fn, ...)
	end
end

function Signal:FireTo(Identifier: string, ...: any): ()
	if not Identifier or not Signals[Identifier] then return end
	Signal.Fire(Signals[Identifier], ...)
end

function Signal:Invoke(key: string, ...: any): (...any?)
	if not key or not self.fn[key] then return nil end
	return self.fn[key](...)
end

function Signal:InvokeTo(Identifier: string, key: string, ...: any): (...any?)
	if not Identifier or not Signals[Identifier] or not key then return nil end
	return Signal.Invoke(Signals[Identifier], key, ...)
end

function Signal:Connect(fn: (...any) -> ()): string
	local key = tostring(Key())
	self.fn[key] = fn
	return key
end

function Signal:Once(fn: (...any) -> ()): string
	local key: string
	key = self:Connect(function(...)
		self:Disconnect(key)
		Spawn(fn, ...)
	end)
	return key
end

function Signal:Wait(): number
	local thread, t = coroutine.running(), os.clock()
	self:Once(function()
		task.spawn(thread, os.clock()-t)
	end)
	return coroutine.yield()
end

function Signal:Disconnect(key: string): ()
	if not key then return end
	self.fn[key] = nil
end

function Signal:DisconnectAll(): ()
	table.clear(self.fn)
end

function Signal:Destroy(): ()
	self:DisconnectAll()
	setmetatable(self, nil)
end

return Signal.new :: typeof(Signal.new)