--!strict
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
		end
	else
		local retreived = false
		task.delay(timeout or 10,  function()
			if retreived then return end
			retreived = true
			error(`Serdes: {Identifier} is taking too long to retrieve, seems like not replicated on server.`, 2)
		end)
		task.spawn(function()
			repeat 
				task.wait(0.5)
			until retreived and Event:GetAttribute(Identifier)

			retreived = true
		end)
	end
	return Event:GetAttribute(Identifier)
end
