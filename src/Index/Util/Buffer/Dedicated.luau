--!strict
--!native
--!optimize 2
local DedicatedBuffer = {}
DedicatedBuffer.__index = DedicatedBuffer

local create = buffer.create
local copy = buffer.copy
local writei8 = buffer.writei8
local writei16 = buffer.writei16
local writei32 = buffer.writei32
local writeu8 = buffer.writeu8
local writeu16 = buffer.writeu16
local writeu32 = buffer.writeu32
local writef32 = buffer.writef32
local writef64 = buffer.writef64
local writestring = buffer.writestring

local default: { [string]: number } = {
	point = 0,
	next = 0,
	size = 32,
	bufferSize = 32,
}

function DedicatedBuffer.copy(self: any, offset: number, b: buffer?, src: buffer?, srcOffset: number?, count: number?)
	if not b then
		copy(create(count or default.size), offset, src or self.buffer, srcOffset, count)
	else
		copy(b, offset, src or self.buffer, srcOffset, count)
	end
end

function DedicatedBuffer.alloc(self: any, byte: number)
	local size: number = self.size
	local b: buffer = self.buffer

	while self.next + byte >= size do
		size = math.floor(size * 1.2)
	end
	local newBuffer: buffer = create(size)
	copy(newBuffer, 0, b)

	b = newBuffer

	self.point  = self.next
	self.buffer = b
	self.next += byte
end

function DedicatedBuffer.build(self: any): buffer
	local p: number = self.next > self.point and self.next or self.point
	local build: buffer = create(p)

	copy(build, 0, self.buffer, 0, p)
	return build
end

function DedicatedBuffer.buildAndRemove(self: any): buffer
	local p: number = self.next > self.point and self.next or self.point
	local build: buffer = create(p)

	copy(build, 0, self.buffer, 0, p)
	self:remove()
	return build
end

function DedicatedBuffer.wi8(self: any, val: number)
	if not val then return end
	self:alloc(1)
	writei8(self.buffer, self.point, val)
end

function DedicatedBuffer.wi16(self: any, val: number)
	if not val then return end
	self:alloc(2)
	writei16(self.buffer, self.point, val)
end

function DedicatedBuffer.wi32(self: any, val: number)
	if not val then return end
	self:alloc(4)
	writei32(self.buffer, self.point, val)
end

function DedicatedBuffer.wu8(self: any, val: number)
	if not val then return end
	self:alloc(1)
	writeu8(self.buffer, self.point, val)
end

function  DedicatedBuffer.wu16(self: any, val: number)
	if not val then return end
	self:alloc(2)
	writeu16(self.buffer, self.point, val)
end

function DedicatedBuffer.wu32(self: any, val: number)
	if not val then return end
	self:alloc(4)
	writeu32(self.buffer, self.point, val)
end

function DedicatedBuffer.wf32(self: any, val: number)
	if not val then return end
	self:alloc(4)
	writef32(self.buffer, self.point, val)
end

function DedicatedBuffer.wf64(self: any, val: number)
	if not val then return end
	self:alloc(8)
	writef64(self.buffer, self.point, val)
end

function DedicatedBuffer.wstring(self: any, val: string)
	if not val then return end
	self:alloc(#val)
	writestring(self.buffer, self.point, val)
end

function DedicatedBuffer.wType(self: any, typeByte: number)
	self:alloc(1)
	writeu8(self.buffer, self.point, typeByte)
	self.point += 1
end

function DedicatedBuffer.pack(self: any, data: {any})
	if typeof(data) == "number" then
		if math.floor(data) == data then -- Integer
			if data >= 0 and data <= 255 then
				self:wi8(1) -- u8 marker
				self:wu8(data)
			elseif data >= -32768 and data <= 32767 then
				self:wi8(2) -- i16 marker
				self:wi16(data)
			elseif data >= -2147483647 and data <= 2147483647 then
				self:wi8(3) -- i32 marker
				self:wi32(data)
			else
				self:wi8(4) -- f64 marker
				self:wf64(data)
			end
		else
			self:wi8(4) -- f64 marker
			self:wf64(data)
		end
	elseif typeof(data) == "boolean" then
		self:wi8(5) -- boolean marker
		self:wu8(data and 1 or 0)
	elseif typeof(data) == "string" then
		self:wi8(6) -- string marker
		local length = #data
		if length < 255 then
			--self:wi8(7) -- small string marker
			self:wu8(length) -- use 1 byte for length if small
		else
			--self:wi8(8) -- large string marker
			self:wi32(length) -- 32-bit for larger strings
		end
		self:wstring(data)
	elseif typeof(data) == "Vector3" then
		self:wi8(7) -- Vector3 marker
		self:wf32(data.X)
		self:wf32(data.Y)
		self:wf32(data.Z)
	elseif typeof(data) == "CFrame" then
		self:wi8(8) -- CFrame marker
		for _, v in {data:GetComponents()} do
			self:wf32(v)
		end
	elseif typeof(data) == "table" then
		--local isArray = (next(data) ~= nil and #data > 0) and true or false
		local isArray = true
		local count = 0
		for k in data do
			count += 1
			if typeof(k) ~= "number" or math.floor(k) ~= k then
				isArray = false
			end
		end
		if isArray then
			self:wi8(9) -- array marker
			self:wi32(count) -- use 32-bit length
			for _, v in data do
				self:pack(v)
			end
		else
			self:wi8(10) -- dictionary marker
			self:wi32(count) -- number of key-value pairs
			for k, v in data do
				self:pack(k) -- pack the key
				self:pack(v) -- pack the value
			end
		end
	else
		error("Unsupported data type: " .. typeof(data))
	end
end

function DedicatedBuffer.flush(self: any)
	self.point = default.point
	self.next = default.next
	self.size = default.size
	self.buffer = create(default.bufferSize)
end

function DedicatedBuffer.new()
	return setmetatable({
		point = default.point,
		next = default.next,
		size = default.size,
		buffer = create(default.bufferSize)
	}, DedicatedBuffer)
end

function DedicatedBuffer.remove(self: any)
	self:flush()
	table.clear(self)
	setmetatable(self, nil)
end

export type DedicatedType = typeof(DedicatedBuffer.new())

return DedicatedBuffer.new :: typeof(DedicatedBuffer.new)