--!optimize 2
--!strict
--@EternityDev
local BITS: number = 8
local MAX_VALUE: number = bit32.lshift(1, BITS) - 1
local hook_fn: (string, number) -> ()

if not shared.__warp_identifier_registry then
	shared.__warp_identifier_registry = {
		cache = {} :: { [string]: number },
		counter = 0,
	}
end

local registry = shared.__warp_identifier_registry
local function fastAssert(condition: boolean, ...: any)
	if not condition then
		error(...)
	end
end

local Identifier = {}

Identifier.on_added = function(fn: (string, number) -> ())
	fastAssert(hook_fn == nil, ".on_added can only be called once.")
	hook_fn = fn
end

Identifier.has = function(name: string): boolean
	return registry.cache[name] ~= nil
end

Identifier.get = function(name: string): number
	local cached = registry.cache[name]
	if cached then
		return cached
	end

	local id = registry.counter + 1
	fastAssert(id <= MAX_VALUE, `Identifier overflow: exceeded {MAX_VALUE + 1} unique names.`)
	registry.counter = id
	registry.cache[name] = id
	if hook_fn then
		task.defer(hook_fn, name, id)
	end
	return id
end

return Identifier :: typeof(Identifier)
