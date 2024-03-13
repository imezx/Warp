--!strict
--!native
--!optimize 2
local Buffer = {}
Buffer.__index = Buffer

local Dedicated = require(script.Dedicated)

local tostring = buffer.tostring
local fromstring = buffer.fromstring

function Buffer.new()
	return Dedicated()
end

function Buffer.convert(b: buffer): string
	return tostring(b)
end

function Buffer.revert(s: string): buffer
	return fromstring(s)
end

return Buffer :: typeof(Buffer)