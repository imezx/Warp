--!strict
--!native
--!optimize 2
local RateLimit = {}

local RunService = game:GetService("RunService")
local Assert = require(script.Parent.Assert)
local Event = require(script.Parent.Parent.Event).Reliable

function RateLimit.create(Identifier: string, entrance: number?, interval: number?)
	Assert(typeof(Identifier) == "string", "Identifier must a string type.")
	if RunService:IsServer() then
		Assert(typeof(entrance) == "number", "entrance must a number type.")
		Assert(entrance :: number > 0, "entrance must above 0.")
		Event:SetAttribute(Identifier.."_ent", entrance)
		Event:SetAttribute(Identifier.."_int", interval)
	else
		while (not Event:GetAttribute(Identifier.."_ent")) or (not Event:GetAttribute(Identifier.."_int")) do
			task.wait(0.5)
		end
		entrance = tonumber(Event:GetAttribute(Identifier.."_ent"))
		interval = tonumber(Event:GetAttribute(Identifier.."_int"))
	end
	local entrances: number = 0
	return function(incoming: number?): boolean
		if entrances == 0 then
			task.delay(interval, function()
				entrances = 0
			end)
		end
		entrances += incoming or 1
		return (entrances <= entrance :: number)
	end
end

return RateLimit :: typeof(RateLimit)