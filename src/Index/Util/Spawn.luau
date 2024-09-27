--!native
--!strict
--!optimize 2
local thread: thread?
local threads: {
	thread
} = {}

local function passer<T...>(func: (T...) -> (), ...: T...): ()
	local HoldThread: thread = thread :: thread
	thread = nil
	func(...)
	if not thread then
		thread = HoldThread
		return
	end
	table.insert(threads, HoldThread)
end

local function yield(): never
	while true do
		passer(coroutine.yield())
	end
end

local function createThread(): ()
	local newThread: thread = coroutine.create(yield)
	coroutine.resume(newThread, newThread)
	table.insert(threads, newThread)
end

for _=1,5 do
	createThread()
end

return function<T...>(func: (T...) -> (), ...: T...): ()
	if not thread then
		if #threads == 0 then
			createThread()
		end
		thread = table.remove(threads, 1)
	end
	task.spawn(thread :: thread, func, ...)
end