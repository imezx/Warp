--!optimize 2
--@EternityDev
local BITS: number = 8
local MAX_VALUE: number = bit32.lshift(1, BITS) - 1

if not shared.__identifier_registry then
    shared.__identifier_registry = {
        cache = {} :: { [string]: number },
        counter = 0,
    }
end

local registry = shared.__identifier_registry
return function(name: string): number
    local cached = registry.cache[name]
    if cached then
        return cached
    end

    local id = registry.counter + 1
    assert(id <= MAX_VALUE, `Identifier overflow: exceeded {MAX_VALUE + 1} unique names.`)
    registry.counter = id + 1
    registry.cache[name] = id
    return id
end
