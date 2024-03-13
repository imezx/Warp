--!strict
--!native
--!optimize 2
local Dedicated = {}
Dedicated.__index = Dedicated

function Dedicated.new(signal: any, handler: (...any) -> ())
	return setmetatable({
		fn = handler,
		root = signal,
	}, Dedicated)
end

function Dedicated:Disconnect()
	setmetatable(self, nil)
end

return Dedicated.new :: typeof(Dedicated.new)