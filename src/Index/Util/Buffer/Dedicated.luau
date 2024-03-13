--!strict
--!native
--!optimize 2
local DedicatedBuffer = {}
DedicatedBuffer.__index = DedicatedBuffer

local create = buffer.create
local copy = buffer.copy
local writeu8 = buffer.writeu8
local tostring = buffer.tostring

local default = {
	point = 0,
	size = 256,
}

function DedicatedBuffer.alloc(self: any, byte: number)
	local size: number = self.size
	local b: buffer = self.buffer
	
	while self.point + byte >= size do
		size = math.floor(size * 1.5)
	end

	local newBuffer: buffer = create(size)
	copy(newBuffer, 0, b)

	b = newBuffer
end

function DedicatedBuffer.build(self: any): buffer
	local p: number = self.point
	local build: buffer = create(p)

	copy(build, 0, self.buffer, 0, p)
	return build
end

function DedicatedBuffer.writeu8(self: any, val: number)
	DedicatedBuffer.alloc(self, 1)
	writeu8(self.buffer, self.point, val)
	self.point += 1
end

function DedicatedBuffer.flush(self: any)
	self.point = default.point
	self.size = default.size
	self.buffer = create(256)
end

function DedicatedBuffer.new()
	return setmetatable({
		point = default.point,
		size = default.size,
		buffer = create(256)
	}, DedicatedBuffer)
end

function DedicatedBuffer.remove(self: any)
	self:flush()
	setmetatable(self, nil)
end

return DedicatedBuffer.new :: typeof(DedicatedBuffer.new)