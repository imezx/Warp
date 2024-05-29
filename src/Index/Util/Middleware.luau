--!strict
--!native
--!optimize 2
local Middleware = {}
Middleware.__index = Middleware

local function wrap(middleware: (...any) -> (...any)): (...any) -> boolean
	return function(...): boolean
		local obj: any = { ... }
		local s, r = pcall(function()
			return middleware(table.unpack(obj))
		end)
		if not s and r then
			warn(r)
			r = nil
			table.clear(obj)
			obj = nil
		end
		return s
	end
end

function Middleware.new(key: string)
	return setmetatable({
		root = key,
		bridge = function(...: any?): any?
			return true
		end,
	}, Middleware)
end

function Middleware:middleware(middleware: (...any) -> (...any))
	self.bridge = wrap(middleware)
	return self
end

function Middleware:key(): string
	return self.root
end

function Middleware:destroy()
	table.clear(self)
	setmetatable(self, nil)
end

return Middleware.new :: typeof(Middleware.new)