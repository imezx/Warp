--!strict
--!optimize 2
local RateLimit = {}

local RunService = game:GetService("RunService")
local Assert = require(script.Parent.Assert)
local Events = require(script.Parent.Parent.Event)
local Reliable, Unreliable, Request = Events.Reliable, Events.Unreliable, Events.Request
local Signal = require(script.Parent.Parent.Signal)("Warp_OnSpamSignal")

local map, activity, meta = {}, {}, {}
setmetatable(meta , {
	__index = map,
	__newindex  = function(self, key, value)
		if not activity[key] then
			activity[key] = os.clock()
		end
		if (os.clock()-activity[key]) >= 1 then
			activity[key] = os.clock()
			map[key] = 1
			return
		end
		if value >= 1e2 then -- 100
			Signal:Fire(key)
			return
		end
		map[key] = value
	end,
})

local function onReceived(player: Player)
	if not meta[player] then
		meta[player] = 1
		return
	end
	meta[player] += 1
end

function RateLimit.create(Identifier: string, entrance: number?, interval: number?)
	Assert(typeof(Identifier) == "string", "Identifier must a string type.")
	if RunService:IsServer() then
		Assert(typeof(entrance) == "number", "entrance must a number type.")
		Assert(entrance :: number > 0, "entrance must above 0.")
		Reliable:SetAttribute(Identifier.."_ent", entrance)
		Reliable:SetAttribute(Identifier.."_int", interval)
	else
		while (not Reliable:GetAttribute(Identifier.."_ent")) or (not Reliable:GetAttribute(Identifier.."_int")) do
			task.wait(0.1)
		end
		entrance = tonumber(Reliable:GetAttribute(Identifier.."_ent"))
		interval = tonumber(Reliable:GetAttribute(Identifier.."_int"))
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

function RateLimit.Protect()
	if not RunService:IsServer() or Reliable:GetAttribute("Protected") or Unreliable:GetAttribute("Protected") or Request:GetAttribute("Protected") then return end
	Reliable:SetAttribute("Protected", true)
	Unreliable:SetAttribute("Protected", true)
	Request:SetAttribute("Protected", true)
	Reliable.OnServerEvent:Connect(onReceived)
	Unreliable.OnServerEvent:Connect(onReceived)
	Request.OnServerEvent:Connect(onReceived)
end

return RateLimit :: typeof(RateLimit)