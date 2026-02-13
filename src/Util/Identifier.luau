--!optimize 2
--!native
--@EternityDev
local BITS: number = 8
local MAX_VALUE: number = bit32.lshift(1, BITS) - 1

local cache: { [string]: number } = {}
local hash: number = game.PlaceVersion + 5381

return function(name: string): number
	local cached = cache[name]
	if cached then
		return cached
	end

	local b: number = hash
	for i = 1, #name do
		b = bit32.bxor(bit32.lshift(hash, 5) + b, string.byte(name, i))
	end

	local reduced = bit32.band(b, MAX_VALUE)
	cache[name] = reduced
	return reduced
end
