--!optimize 2
--!native
--@EternityDev
if not shared.__identifier_cache then
	shared.__identifier_cache = {
		cache = {} :: { [string]: number },
		used = {} :: { [number]: string },
		count = 0 :: number,
	}
end

local registry = shared.__identifier_cache
local cache = registry.cache
local used = registry.used
local count = registry.count

local BITS: number = 16
local MAX_VALUE: number = bit32.lshift(1, BITS) - 1
local hash: number = game.PlaceVersion + 5381

return function(name: string): number
	local cached = cache[name]
	if cached then
		return cached
	end

	local b: number = hash
	for i = 1, #name do
		b = bit32.bxor(bit32.lshift(b, 5) + b, string.byte(name, i))
	end

	local reduced: number = (b % (MAX_VALUE - 2)) + 2
	local existing = used[reduced]
	if existing and existing ~= name then
		error(`[Warp] Hash collision: "{name}" & "{existing}" both map to ID {reduced}. Rename one.`)
	end

	used[reduced] = name
	cache[name] = reduced
	count += 1
	return reduced
end
