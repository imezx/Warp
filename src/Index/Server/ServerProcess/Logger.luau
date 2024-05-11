--!strict
--!native
--!optimize 2
local Logger = {}
local Logs: {
	[string]: {
		[string]: string
	}
} = {}
local logging: {
	[string]: boolean
} = {}

local now = tick()

function Logger.write(Identifier: string, text: string, log: boolean?)
	if not Logs[Identifier] then
		Logs[Identifier] = {}
	end
	if log ~= nil then
		logging[Identifier] = log
	end
	now = tick()
	Logs[Identifier][tostring(now)] = text
	if logging[Identifier] then
		print(`[{now}] ->`, text)
	end
end

function Logger.read(Identifier: string)
	return Logs[Identifier]
end

return Logger