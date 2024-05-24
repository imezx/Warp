--!strict
--!native
--!optimize 2
local Signal = {}
Signal.__index = Signal

local DedicatedSignal = require(script.Dedicated)

local Util = script.Parent.Util
local Key = require(Util.Key)
local Assert = require(Util.Assert)

local Signals = {}

function Signal.new(Identifier: string)
	Assert(typeof(Identifier) == "string", `[Signal]: Identifier must be a string type, got {typeof(Identifier)}`)
	if not Signals[Identifier] then
		local signal = setmetatable({}, Signal)
		Signals[Identifier] = signal
		return signal
	end
	return Signals[Identifier]
end

function Signal:Connect(fn: (...any) -> ()): string
	local key = tostring(Key())
	self[key] = DedicatedSignal(self, fn)
	return key
end

function Signal:Once(fn: (...any) -> ()): string
	local key: string
	key = self:Connect(function(...)
		self:Disconnect(key)
		task.spawn(fn, ...)
	end)
	return key
end

function Signal:Disconnect(key: string)
	self[key]:Disconnect()
	self[key] = nil
end

function Signal:DisconnectAll(): ()
	for _, handle in self do
		handle:Disconnect()
	end
	table.clear(self)
end

function Signal:Wait(): number
	local thread, t = coroutine.running(), os.clock()
	self:Once(function()
		task.spawn(thread, os.clock()-t)
	end)
	return coroutine.yield()
end

function Signal:DeferFire(...: any): ()
	for _, handle in self do
		task.defer(handle.fn, ...)
	end
end

function Signal:Fire(...: any): ()
	for _, handle in self do
		task.spawn(handle.fn, ...)
	end
end

function Signal:FireTo(signal: string, ...: any): ()
	local to = Signals[signal]
	if not to then return end
	Signal.Fire(to, ...)
end

function Signal:Invoke(key: string, ...: any): ()
	local to = self[key]
	if not to then return end
	return to.fn(...)
end

function Signal:InvokeTo(signal: string, key: string, ...: any): ()
	if not Signals[signal] then return end
	return Signal.Invoke(Signals[signal], key, ...)
end

function Signal:Destroy(): ()
	self:DisconnectAll()
	for idx: string, signal in Signals do
		if self :: any == signal then
			Signals[idx] = nil
			break
		end
	end
	setmetatable(self, nil)
end

return Signal.new :: typeof(Signal.new)