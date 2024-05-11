--!strict
--!native
--!optimize 2
local RunService = game:GetService("RunService")
local SerInt = 0

local Event = require(script.Parent.Parent.Event).Reliable
local Assert = require(script.Parent.Assert)

return function(Identifier: string, timeout: number?): number
	Assert(typeof(Identifier) == "string", "Identifier must be a string type.")
	Assert(SerInt < 255, "reached max 255 identifiers.")
	if RunService:IsServer() then
		if not Event:GetAttribute(Identifier) then
			SerInt += 1
			Event:SetAttribute(Identifier, SerInt)
			--Event:SetAttribute(Identifier, string.pack("I1", SerInt)) -- I1 -> 255 max, I2 -> ~ 6.5e4 max. (SerInt), removed/disabled for buffer migration.
		end
	else
		local yieldThread: thread = coroutine.running()
		local cancel = task.delay(timeout or 10, function() -- yield cancelation (timerout)
			task.spawn(yieldThread, nil)
			error(`Serdes: {Identifier} is taking too long to retrieve, seems like not replicated on server.`, 2)
		end)
		task.spawn(function()
			while coroutine.status(cancel) ~= "dead" and task.wait(0.5) do -- let it loop for yields!
				if (Event:GetAttribute(Identifier)) then
					task.cancel(cancel)
					task.spawn(yieldThread, Event:GetAttribute(Identifier))
					break
				end
			end
		end)
		return coroutine.yield() -- yield
	end
	return Event:GetAttribute(Identifier)
end
