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

local default = {
	point = 0,
	next = 0,
	size = 128,
	bufferSize = 128,
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


	while self.point + byte >= size do
		size = math.floor(size * 1.5)
	end

	local newBuffer: buffer = create(size)
	copy(newBuffer, 0, b)

	b = newBuffer

	self.point  = self.next
	self.next += byte
end

function DedicatedBuffer.build(self: any): buffer
	local p: number = self.next > self.point and self.next or self.point
	local build: buffer = create(p)

	copy(build, 0, self.buffer, 0, p)
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
	setmetatable(self, nil)
end

return DedicatedBuffer.new :: typeof(DedicatedBuffer.new)