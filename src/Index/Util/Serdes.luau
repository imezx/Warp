--!strict
--!optimize 2
local SerDes = {}
local RunService = game:GetService("RunService")
local SerInt = 0

local Event = require(script.Parent.Parent.Event).Reliable
local Assert = require(script.Parent.Assert)

function SerDes.increment(Identifier: string, timeout: number?): number
	Assert(typeof(Identifier) == "string", "Identifier must be a string type.")
	if RunService:IsServer() then
		Assert(SerInt < 255, "reached max 255 identifiers.")
		if not Event:GetAttribute(Identifier) then
			SerInt += 1
			Event:SetAttribute(`{SerInt}`, Identifier)
			Event:SetAttribute(Identifier, SerInt)
			--Event:SetAttribute(Identifier, string.pack("I1", SerInt)) -- I1 -> 255 max, I2 -> ~ 6.5e4 max. (SerInt), removed/disabled for buffer migration.
		end
	else
		local yieldThread: thread = coroutine.running()
		local cancel = task.delay(timeout or 10, function() -- yield cancelation (timerout)
			task.spawn(yieldThread, nil)
			error(`Serdes: {Identifier} is taking too long to retrieve, seems like it's not replicated on server.`, 2)
		end)
		task.spawn(function()
			while coroutine.status(cancel) ~= "dead" and task.wait(0.04) do -- let it loop for yields! 1/24
				if Event:GetAttribute(Identifier) then
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

function SerDes.decrement()
	if not RunService:IsServer() or SerInt <= 0 then return end
	local Identifier = Event:GetAttribute(`{SerInt}`)
	if not Identifier then return end
	Event:SetAttribute(`{Identifier}`, nil)
	Event:SetAttribute(`{SerInt}`, nil)
	SerInt -= 1
	Identifier = nil
end

return SerDes :: typeof(SerDes)