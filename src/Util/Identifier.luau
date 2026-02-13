--!optimize 2
--!native
--@EternityDev
local BITS: number = 8
local MAX_VALUE: number = bit32.lshift(1, BITS) - 1

local cache: { [string]: number } = {}
local hash: number = game.PlaceVersion + 5381
local count: number = 0

return function(name: string): number
	local cached = cache[name]
	if cached then
		return cached
	end
	if count >= MAX_VALUE then
		warn("ran out of ids :(")
		return 0
	end

	local b: number = hash
	for i = 1, #name do
		b = bit32.bxor(bit32.lshift(b, 5) + b, string.byte(name, i))
	end

	local reduced = bit32.band(b, MAX_VALUE)
	cache[name] = reduced
	count += 1
	return reduced
end
