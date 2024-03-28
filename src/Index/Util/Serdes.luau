--!strict
local RunService = game:GetService("RunService")
local SerInt = 0

local Event = require(script.Parent.Parent.Event).Reliable
local Assert = require(script.Parent.Assert)

return function(Identifier: string): number
	Assert(typeof(Identifier) == "string", "Identifier must be a string type.")
	Assert(SerInt < 255, "reached max 255 identifiers.")
	if RunService:IsServer() then
		if not Event:GetAttribute(Identifier) then
			SerInt += 1
			Event:SetAttribute(Identifier, SerInt)
			--Event:SetAttribute(Identifier, string.pack("I1", SerInt)) -- I1 -> 255 max, I2 -> ~ 6.5e4 max. (SerInt)
		end
	else
		local loaded = false
		task.delay(10, function()
			if loaded then
				return
			end
			warn(`{Identifier} is taking too long to load on the server.`)
		end)

		while not Event:GetAttribute(Identifier) do
			task.wait(0.5)
		end
		loaded = true
	end
	return Event:GetAttribute(Identifier)
end
