--!optimize 2
--!native
--@EternityDev
if not shared.__identifier_cache then
	shared.__identifier_cache = {
		cache = {} :: { [string]: number },
		used = {} :: { [number]: string },
	}
end

local registry = shared.__identifier_cache
local cache = registry.cache
local used = registry.used

return function(name: string): number
	local cached = cache[name]
	if cached then
		return cached
	end

	local h: number = 2166136261
	for i = 1, #name do
		h = bit32.bxor(h, string.byte(name, i))
		h = bit32.band(h * 16777619, 0xFFFFFFFF)
	end

	local id = h % 254 + 2

	local existing = used[id]
	if existing and existing ~= name then
		warn(`[Warp] Hash collision: "{name}" & "{existing}" both map to ID {id}`)
	end

	cache[name] = id
	used[id] = name
	return id
end
