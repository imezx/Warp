--!native
--!strict
--!optimize 2
local thread: thread?

local function passer<T...>(func: (T...) -> (), ...: T...): ()
	local HoldThread: thread = thread :: thread
	thread = nil
	func(...)
	thread = HoldThread
end

local function newThread(): ()
	thread = coroutine.running()
	while true do passer(coroutine.yield()) end
end

return function<T...>(func: (T...) -> (), ...: T...): ()
	if not thread then task.spawn(newThread) end
	task.spawn(thread :: thread, func, ...)
end