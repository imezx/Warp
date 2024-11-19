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

local function readValue(b: buffer, position: number): (any, number)
	local typeByte = readu8(b, position)
	position += 1
	if typeByte == 1 then -- u8
		local value = readu8(b, position)
		return value, position + 1
	elseif typeByte == 2 then -- i16
		local value = readi16(b, position)
		return value, position + 2
	elseif typeByte == 3 then -- i32
		local value = readi32(b, position)
		return value, position + 4
	elseif typeByte == 4 then -- f64
		local value = readf64(b, position)
		return value, position + 8
	elseif typeByte == 5 then -- boolean
		local value = readu8(b, position) == 1
		return value, position + 1
	elseif typeByte == 6 then -- string
		local lengthByte = readu8(b, position)
		position += 1
		local value
		if lengthByte < 255 then
			value = readstring(b, position, lengthByte)
			return value, position + lengthByte
		else
			local length = readi32(b, position)
			position += 4
			value = readstring(b, position, length)
			return value, position + length
		end
	elseif typeByte == 7 then -- Vector3
		local x = readf32(b, position)
		local y = readf32(b, position + 4)
		local z = readf32(b, position + 8)
		return Vector3.new(x, y, z), position + 12
	elseif typeByte == 8 then -- CFrame
		local components = {}
		for i = 1, 12 do
			table.insert(components, readf32(b, position + (i - 1) * 4))
		end
		return CFrame.new(unpack(components)), position + 48
	elseif typeByte == 9 then -- array
		local length = readi32(b, position)
		position += 4
		local array = {}
		for _ = 1, length do
			local value
			value, position = readValue(b, position)
			table.insert(array, value)
		end
		return array, position
	elseif typeByte == 10 then -- dictionary
		local length = readi32(b, position)
		position += 4
		local dict = {}
		for _ = 1, length do
			local key, value
			key, position = readValue(b, position)
			value, position = readValue(b, position)
			dict[key] = value
		end
		return dict, position
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

function Buffer.write(data: { any }): buffer
	local newBuffer = Dedicated()
	newBuffer:pack(data)
	return newBuffer:buildAndRemove()
end

function Buffer.read(b: buffer): any?
	local position = 0
	local result = {}
	while position < len(b) do
		local value
		value, position = readValue(b, position)
		table.insert(result, value)
	end
	return table.unpack(result)
end

return Buffer :: typeof(Buffer)