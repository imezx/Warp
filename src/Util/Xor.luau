--!strict
--!native
--!optimize 2
local Xor = {}

const KEYFRAME, DELTA, HEADER = 0, 1, 2
const KEYFRAME_INTERVAL = 1 -- bounds how long a desynced stream stays broken

export type Stream = { prev: buffer?, seq: number, lastKey: number }

local function xorApply(out: buffer, outOff: number, cur: buffer, curOff: number, len: number, prev: buffer)
	local common = math.min(len, buffer.len(prev))
	local i = 0
	while i + 4 <= common do
		buffer.writeu32(out, outOff + i, bit32.bxor(buffer.readu32(cur, curOff + i), buffer.readu32(prev, i)))
		i += 4
	end
	while i < common do
		buffer.writeu8(out, outOff + i, bit32.bxor(buffer.readu8(cur, curOff + i), buffer.readu8(prev, i)))
		i += 1
	end
	if len > common then
		buffer.copy(out, outOff + common, cur, curOff + common, len - common)
	end
end

function Xor.new(): Stream
	return { prev = nil, seq = 0, lastKey = 0 }
end

function Xor.encode(s: Stream, buf: buffer): buffer
	local len = buffer.len(buf)
	local prev = s.prev
	local now = os.clock()
	local out = buffer.create(len + HEADER)
	s.seq = (s.seq + 1) % 256
	buffer.writeu8(out, 1, s.seq)
	if prev == nil or now - s.lastKey >= KEYFRAME_INTERVAL then
		buffer.writeu8(out, 0, KEYFRAME)
		buffer.copy(out, HEADER, buf, 0, len)
		s.lastKey = now
	else
		buffer.writeu8(out, 0, DELTA)
		xorApply(out, HEADER, buf, 0, len, prev)
	end
	local copy = buffer.create(len)
	buffer.copy(copy, 0, buf, 0, len)
	s.prev = copy
	return out
end

function Xor.decode(s: Stream, pkt: buffer): buffer?
	local len = buffer.len(pkt) - HEADER
	if len < 0 then
		s.prev = nil
		return nil
	end
	local kind, seq = buffer.readu8(pkt, 0), buffer.readu8(pkt, 1)
	local prev = s.prev
	local out = buffer.create(len)
	if kind == KEYFRAME then
		buffer.copy(out, 0, pkt, HEADER, len)
	elseif kind == DELTA and prev and seq == (s.seq + 1) % 256 then
		xorApply(out, 0, pkt, HEADER, len, prev)
	else
		s.prev = nil
		return nil
	end
	s.seq = seq
	s.prev = out
	return out
end

return Xor
