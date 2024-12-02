--!strict
--!native
--!optimize 2
local Buffer = {}
Buffer.__index = Buffer

local Dedicated = require(script.Dedicated)

local tostring = buffer.tostring
local fromstring = buffer.fromstring
local readu8 = buffer.readu8
local readi8 = buffer.readi8
local readu16 = buffer.readu16
local readi16 = buffer.readi16
local readi32 = buffer.readi32
local readf32 = buffer.readf32
local readf64 = buffer.readf64
local readstring = buffer.readstring
local len = buffer.len

local function readValue(b: buffer, position: number, ref: { any }?): (any, number)
	local typeByte = readi8(b, position)
	position += 1
	if typeByte == 0 then -- nil
		return nil, position
	elseif typeByte == -1 then -- Instance
		if not ref or #ref == 0 then
			return nil, position + 1
		end
		local value = ref[readu8(b, position)]
		if typeof(value) == "Instance" then
			return value, position + 1
		end
		return nil, position + 1
	elseif typeByte == -2 then -- array
		local length = readu16(b, position)
		position += 2
		local array = {}
		for _ = 1, length do
			local value
			value, position = readValue(b, position, ref)
			table.insert(array, value)
		end
		return array, position
	elseif typeByte == -3 then -- dictionary
		local length = readu16(b, position)
		position += 2
		local dict = {}
		for _ = 1, length do
			local key, value
			key, position = readValue(b, position, ref)
			value, position = readValue(b, position, ref)
			dict[key] = value
		end
		return dict, position
	elseif typeByte == -4 then -- EnumItem
		local length = readi8(b, position)
		local value = readstring(b, position + 1, length)
		local value2 = readu8(b, position + 1 + length)
		return Enum[value]:FromValue(value2), position + 2 + length
	elseif typeByte == -5 then -- BrickColor
		local value = readi16(b, position)
		return BrickColor.new(value), position + 2
	elseif typeByte == -6 then -- Enum
		local length = readi8(b, position)
		local value = readstring(b, position + 1, length)
		return Enum[value], position + 1 + length
	elseif typeByte == 1 then -- int u8
		local value = readu8(b, position)
		return value, position + 1
	elseif typeByte == 2 then -- int i16
		local value = readi16(b, position)
		return value, position + 2
	elseif typeByte == 3 then -- int i32
		local value = readi32(b, position)
		return value, position + 4
	elseif typeByte == 4 then -- f64
		local value = readf64(b, position)
		return value, position + 8
	elseif typeByte == 5 then -- boolean
		local value = readu8(b, position) == 1
		return value, position + 1
	elseif typeByte == 6 then -- string u8
		local length = readu8(b, position)
		local value = readstring(b, position + 1, length)
		return value, position + length + 1
	elseif typeByte == 7 then -- string u16
		local length = readu16(b, position)
		local value = readstring(b, position + 2, length)
		return value, position + length + 2
	elseif typeByte == 8 then -- string i32
		local length = readi32(b, position)
		local value = readstring(b, position + 4, length)
		return value, position + length + 4
	elseif typeByte == 9 then -- Vector3
		local x = readf32(b, position)
		local y = readf32(b, position + 4)
		local z = readf32(b, position + 8)
		return Vector3.new(x, y, z), position + 12
	elseif typeByte == 10 then -- Vector2
		local x = readf32(b, position)
		local y = readf32(b, position + 8)
		return Vector2.new(x, y), position + 8
	elseif typeByte == 11 then -- CFrame
		local components = {}
		for i = 1, 12 do
			table.insert(components, readf32(b, position + (i - 1) * 4))
		end
		return CFrame.new(unpack(components)), position + 48
	elseif typeByte == 12 then -- Color3
		local r = readu8(b, position)
		local g = readu8(b, position + 1)
		local b = readu8(b, position + 2)
		return Color3.fromRGB(r, g, b), position + 3
	end
	error(`Unsupported type marker: {typeByte}`)
end

function Buffer.new(): Dedicated.DedicatedType
	return Dedicated()
end

function Buffer.convert(b: buffer): string
	return tostring(b)
end

function Buffer.revert(s: string): buffer
	return fromstring(s)
end

function Buffer.write(data: { any }): (buffer, (any)?)
	local newBuffer = Dedicated()
	newBuffer:pack(data)
	return newBuffer:buildAndRemove()
end

function Buffer.read(b: buffer, ref: { any }?): any?
	local position = 0
	local result = {}
	while position < len(b) do
		local value
		value, position = readValue(b, position, ref)
		table.insert(result, value)
	end
	ref = nil
	return table.unpack(result)
end

return Buffer :: typeof(Buffer)