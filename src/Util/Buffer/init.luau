--!native
--!optimize 2
--@EternityDev
export type Writer = {
	buf: buffer,
	cursor: number,
	capacity: number,
	refs: { any },
}

local DEFAULT_CAPACITY: number = 64
local NaN_VALUE: number = 0 / 0

-- 0x00-0x7F: + fixint (0-127) — single byte
-- 0x80-0x9F: - fixint (-32 to -1) — single byte
local T_NIL = 0xA0
local T_FALSE = 0xA1
local T_TRUE = 0xA2
local T_U8 = 0xA3
local T_U16 = 0xA4
local T_U32 = 0xA5
local T_I8 = 0xA6
local T_I16 = 0xA7
local T_I32 = 0xA8
local T_F16 = 0xAB
local T_F32 = 0xA9
local T_F64 = 0xAA

-- str: 0xB0-0xBF = inline len 0-15
local T_STR_BASE = 0xB0
local T_STR8 = 0xC0
local T_STR16 = 0xC1
local T_STRVAR = 0xC2

-- arrays: 0xC4-0xCB = inline len 0-7
local T_ARR_BASE = 0xC4
local T_ARR8 = 0xCC
local T_ARR16 = 0xCD
local T_ARRVAR = 0xCE

-- maps: 0xD0-0xD7 = inline len 0-7
local T_MAP_BASE = 0xD0
local T_MAP8 = 0xD8
local T_MAP16 = 0xD9
local T_MAPVAR = 0xDA

-- typed arrays (homogeneous, no per-element tags)
local T_TYPED_ARR = 0xDB
local T_BUFFER = 0xDC
local T_BOOL_ARR = 0xDD

local T_VEC3 = 0xE0
local T_VEC2 = 0xE2
local T_CFRAME = 0xE4
local T_COLOR3 = 0xE6
local T_COLOR3_F = 0xE7
local T_BRICKCOLOR = 0xE8
local T_INSTANCE = 0xE9
local T_ENUMITEM = 0xEA
local T_ENUM = 0xEB
local T_UDIM2 = 0xEC
local T_UDIM = 0xED
local T_RECT = 0xEE
local T_NUMBERRANGE = 0xEF
local T_RAY = 0xF0
local T_COLSEQ = 0xF2
local T_NUMSEQ = 0xF3
local T_VEC3I16 = 0xF1
local T_VEC2I16 = 0xF4
local T_TWEENINFO = 0xF5
local T_PHYSPROP = 0xF6
local T_FONT = 0xF7
local T_DATETIME = 0xF8

local F16_LOOKUP: { number } = table.create(65536, 0)
do
	for raw = 0, 65535 do
		local sign: number = bit32.btest(raw, 0x8000) and -1 or 1
		local exponent: number = bit32.extract(raw, 10, 5)
		local mantissa: number = bit32.band(raw, 0x03FF)
		local value: number
		if exponent == 0 then
			if mantissa == 0 then
				value = 0 * sign
			else
				value = sign * (mantissa / 1024) * 6.103515625e-05
			end
		elseif exponent == 31 then
			if mantissa == 0 then
				value = sign * math.huge
			else
				value = NaN_VALUE
			end
		else
			value = sign * (1 + mantissa / 1024) * math.ldexp(1, exponent - 15)
		end
		F16_LOOKUP[raw + 1] = value
		-- if raw % 8192 == 0 then
		-- 	task.wait()
		-- end
	end
end

local function encodeF16(value: number): number
	if value ~= value then
		return 0x7E00
	end
	if value == 0 then
		return if 1 / value < 0 then 0x8000 else 0
	end
	local sign = 0
	if value < 0 then
		sign = 0x8000
		value = -value
	end
	if value >= 65504 then
		return sign + 0x7C00
	end
	if value < 6.103515625e-05 then
		local f = math.floor(value * 16777216 + 0.5)
		return sign + (if f >= 1024 then 0x0400 else f)
	end
	local m, e = math.frexp(value)
	local biasedExp = e + 14
	local f = math.floor(m * 2048 - 1024 + 0.5)
	if f >= 1024 then
		f = 0
		biasedExp += 1
	end
	if biasedExp >= 31 then
		return sign + 0x7C00
	end
	return sign + biasedExp * 1024 + f
end

local function readF16(b: buffer, pos: number): number
	return F16_LOOKUP[buffer.readu16(b, pos) + 1]
end

local function varUIntSize(value: number): number
	if value < 0x80 then
		return 1
	end
	if value < 0x4000 then
		return 2
	end
	if value < 0x200000 then
		return 3
	end
	if value < 0x10000000 then
		return 4
	end
	return 5
end

local function writeVarUInt(buf: buffer, offset: number, value: number): number
	while value >= 0x80 do
		buffer.writeu8(buf, offset, bit32.bor(bit32.band(value, 0x7F), 0x80))
		offset += 1
		value = bit32.rshift(value, 7)
	end
	buffer.writeu8(buf, offset, value)
	return offset + 1
end

local function readVarUInt(buf: buffer, offset: number): (number, number)
	local value = 0
	local shift = 0
	repeat
		local byte = buffer.readu8(buf, offset)
		offset += 1
		value = bit32.bor(value, bit32.lshift(bit32.band(byte, 0x7F), shift))
		shift += 7
	until byte < 0x80
	return value, offset
end

local function createWriter(capacity: number?): Writer
	local cap = capacity or DEFAULT_CAPACITY
	return {
		buf = buffer.create(cap),
		cursor = 0,
		capacity = cap,
		refs = {},
	}
end

local function ensureSpace(w: Writer, bytes: number)
	local needed = w.cursor + bytes
	if needed <= w.capacity then
		return
	end
	local newCap = w.capacity
	while newCap < needed do
		newCap *= 2
	end
	local newBuf = buffer.create(newCap)
	buffer.copy(newBuf, 0, w.buf, 0, w.cursor)
	w.buf = newBuf
	w.capacity = newCap
end

local function rawU8(w: Writer, v: number)
	buffer.writeu8(w.buf, w.cursor, v)
	w.cursor += 1
end

local function rawU16(w: Writer, v: number)
	buffer.writeu16(w.buf, w.cursor, v)
	w.cursor += 2
end

local function rawI16(w: Writer, v: number)
	buffer.writei16(w.buf, w.cursor, v)
	w.cursor += 2
end

local function rawU32(w: Writer, v: number)
	buffer.writeu32(w.buf, w.cursor, v)
	w.cursor += 4
end

local function rawI32(w: Writer, v: number)
	buffer.writei32(w.buf, w.cursor, v)
	w.cursor += 4
end

local function rawF32(w: Writer, v: number)
	buffer.writef32(w.buf, w.cursor, v)
	w.cursor += 4
end

local function rawF64(w: Writer, v: number)
	buffer.writef64(w.buf, w.cursor, v)
	w.cursor += 8
end

local function rawF16(w: Writer, value: number)
	buffer.writeu16(w.buf, w.cursor, encodeF16(value))
	w.cursor += 2
end

local function rawVarUInt(w: Writer, v: number)
	w.cursor = writeVarUInt(w.buf, w.cursor, v)
end

local function rawString(w: Writer, s: string, n: number)
	buffer.writestring(w.buf, w.cursor, s)
	w.cursor += n
end

local function wByte(w: Writer, v: number)
	ensureSpace(w, 1)
	buffer.writeu8(w.buf, w.cursor, v)
	w.cursor += 1
end

local function wU16(w: Writer, v: number)
	ensureSpace(w, 2)
	buffer.writeu16(w.buf, w.cursor, v)
	w.cursor += 2
end

local function wI16(w: Writer, v: number)
	ensureSpace(w, 2)
	buffer.writei16(w.buf, w.cursor, v)
	w.cursor += 2
end

local function wU32(w: Writer, v: number)
	ensureSpace(w, 4)
	buffer.writeu32(w.buf, w.cursor, v)
	w.cursor += 4
end

local function wI32(w: Writer, v: number)
	ensureSpace(w, 4)
	buffer.writei32(w.buf, w.cursor, v)
	w.cursor += 4
end

local function wF16(w: Writer, value: number)
	ensureSpace(w, 2)
	buffer.writeu16(w.buf, w.cursor, encodeF16(value))
	w.cursor += 2
end

local function wF32(w: Writer, v: number)
	ensureSpace(w, 4)
	buffer.writef32(w.buf, w.cursor, v)
	w.cursor += 4
end

local function wF64(w: Writer, v: number)
	ensureSpace(w, 8)
	buffer.writef64(w.buf, w.cursor, v)
	w.cursor += 8
end

local function wVarUInt(w: Writer, v: number)
	ensureSpace(w, 5) -- max varuint = 5 bytes; avoids double-analysis via varUIntSize
	w.cursor = writeVarUInt(w.buf, w.cursor, v)
end

local function wString(w: Writer, s: string)
	local n = #s
	ensureSpace(w, n)
	buffer.writestring(w.buf, w.cursor, s)
	w.cursor += n
end

local packValue: (w: Writer, v: any) -> ()
local unpackValue: (buf: buffer, pos: number, refs: { any }?) -> (any, number)

local F32_TEST_BUF = buffer.create(4)

local TYPED_CODES = { u8 = 1, i8 = 2, u16 = 3, i16 = 4, u32 = 5, i32 = 6, f32 = 7, f64 = 8, f16 = 9 }
local TYPED_SIZES = { u8 = 1, i8 = 1, u16 = 2, i16 = 2, u32 = 4, i32 = 4, f32 = 4, f64 = 8, f16 = 2 }

local TYPED_WRITERS = {
	u8 = buffer.writeu8,
	i8 = buffer.writei8,
	u16 = buffer.writeu16,
	i16 = buffer.writei16,
	u32 = buffer.writeu32,
	i32 = buffer.writei32,
	f32 = buffer.writef32,
	f64 = buffer.writef64,
	f16 = function(b: buffer, offset: number, value: number)
		buffer.writeu16(b, offset, encodeF16(value))
	end,
}

local TYPED_READERS = {
	[1] = function(b: buffer, o: number)
		return buffer.readu8(b, o), o + 1
	end,
	[2] = function(b: buffer, o: number)
		return buffer.readi8(b, o), o + 1
	end,
	[3] = function(b: buffer, o: number)
		return buffer.readu16(b, o), o + 2
	end,
	[4] = function(b: buffer, o: number)
		return buffer.readi16(b, o), o + 2
	end,
	[5] = function(b: buffer, o: number)
		return buffer.readu32(b, o), o + 4
	end,
	[6] = function(b: buffer, o: number)
		return buffer.readi32(b, o), o + 4
	end,
	[7] = function(b: buffer, o: number)
		return buffer.readf32(b, o), o + 4
	end,
	[8] = function(b: buffer, o: number)
		return buffer.readf64(b, o), o + 8
	end,
	[9] = function(b: buffer, o: number)
		return readF16(b, o), o + 2
	end,
}

-- CFrame quaternion compression (Shepperd's method + smallest-three encoding).
-- Extracts a unit quaternion directly from the rotation matrix - no trig needed.
-- The three stored components are guaranteed in [-1/√2, 1/√2], so we rescale
-- by √2 to fill the full i16 range, giving ~41% better precision for free.
local CF_I16_SCALE: number = 32767 * math.sqrt(2)
local CF_I16_INV_SCALE: number = 1 / CF_I16_SCALE

local function compressCFrameRotation(cf: CFrame): (number, number, number, number)
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local trace: number = r00 + r11 + r22
	local qx: number, qy: number, qz: number, qw: number
	if trace > 0 then
		local sq: number = math.sqrt(trace + 1)
		local s: number = 0.5 / sq
		qw = sq * 0.5
		qx = (r21 - r12) * s
		qy = (r02 - r20) * s
		qz = (r10 - r01) * s
	elseif r00 > r11 and r00 > r22 then
		local sq: number = math.sqrt(1 + r00 - r11 - r22)
		local s: number = 0.5 / sq
		qx = sq * 0.5
		qw = (r21 - r12) * s
		qy = (r01 + r10) * s
		qz = (r02 + r20) * s
	elseif r11 > r22 then
		local sq: number = math.sqrt(1 + r11 - r00 - r22)
		local s: number = 0.5 / sq
		qy = sq * 0.5
		qw = (r02 - r20) * s
		qx = (r01 + r10) * s
		qz = (r12 + r21) * s
	else
		local sq: number = math.sqrt(1 + r22 - r00 - r11)
		local s: number = 0.5 / sq
		qz = sq * 0.5
		qw = (r10 - r01) * s
		qx = (r02 + r20) * s
		qy = (r12 + r21) * s
	end

	local index, value, sign = 1, math.abs(qx), qx >= 0 and 1 or -1
	local abs
	abs = math.abs(qy)
	if abs > value then
		index = 2
		value = abs
		sign = qy >= 0 and 1 or -1
	end
	abs = math.abs(qz)
	if abs > value then
		index = 3
		value = abs
		sign = qz >= 0 and 1 or -1
	end
	abs = math.abs(qw)
	if abs > value then
		index = 4
		sign = qw >= 0 and 1 or -1
	end

	local scale = CF_I16_SCALE * sign
	local v0: number, v1: number, v2: number
	if index == 1 then
		v0 = math.round(qy * scale)
		v1 = math.round(qz * scale)
		v2 = math.round(qw * scale)
	elseif index == 2 then
		v0 = math.round(qx * scale)
		v1 = math.round(qz * scale)
		v2 = math.round(qw * scale)
	elseif index == 3 then
		v0 = math.round(qx * scale)
		v1 = math.round(qy * scale)
		v2 = math.round(qw * scale)
	else
		v0 = math.round(qx * scale)
		v1 = math.round(qy * scale)
		v2 = math.round(qz * scale)
	end
	return index, v0, v1, v2
end

local function decompressCFrameRotation(
	index: number,
	v0: number,
	v1: number,
	v2: number
): (number, number, number, number)
	v0 *= CF_I16_INV_SCALE
	v1 *= CF_I16_INV_SCALE
	v2 *= CF_I16_INV_SCALE
	local sq = 1 - (v0 * v0 + v1 * v1 + v2 * v2)
	local d = sq > 0 and math.sqrt(sq) or 0
	if index == 1 then
		return d, v0, v1, v2
	elseif index == 2 then
		return v0, d, v1, v2
	elseif index == 3 then
		return v0, v1, d, v2
	end
	return v0, v1, v2, d
end

local function packNumber(w: Writer, n: number)
	if n ~= n then
		ensureSpace(w, 9)
		rawU8(w, T_F64)
		rawF64(w, n)
		return
	end

	local isInt = n == math.floor(n)

	if isInt then
		if n >= 0 then
			if n <= 127 then
				ensureSpace(w, 1)
				rawU8(w, n)
				return
			end
			if n <= 255 then
				ensureSpace(w, 2)
				rawU8(w, T_U8)
				rawU8(w, n)
			elseif n <= 65535 then
				ensureSpace(w, 3)
				rawU8(w, T_U16)
				rawU16(w, n)
			elseif n <= 4294967295 then
				ensureSpace(w, 5)
				rawU8(w, T_U32)
				rawU32(w, n)
			else
				ensureSpace(w, 9)
				rawU8(w, T_F64)
				rawF64(w, n)
			end
		else
			if n >= -32 then
				ensureSpace(w, 1)
				rawU8(w, bit32.bor(0x80, n + 32))
				return
			end
			if n >= -128 then
				ensureSpace(w, 2)
				rawU8(w, T_I8)
				buffer.writei8(w.buf, w.cursor, n)
				w.cursor += 1
			elseif n >= -32768 then
				ensureSpace(w, 3)
				rawU8(w, T_I16)
				rawI16(w, n)
			elseif n >= -2147483648 then
				ensureSpace(w, 5)
				rawU8(w, T_I32)
				rawI32(w, n)
			else
				ensureSpace(w, 9)
				rawU8(w, T_F64)
				rawF64(w, n)
			end
		end
	else
		buffer.writef32(F32_TEST_BUF, 0, n)
		local f32Val = buffer.readf32(F32_TEST_BUF, 0)

		if f32Val == n then
			ensureSpace(w, 5)
			rawU8(w, T_F32)
			rawF32(w, n)
		else
			ensureSpace(w, 9)
			rawU8(w, T_F64)
			rawF64(w, n)
		end
	end
end

local function packString(w: Writer, s: string)
	local n = #s
	if n <= 15 then
		ensureSpace(w, 1 + n)
		rawU8(w, T_STR_BASE + n)
	elseif n <= 255 then
		ensureSpace(w, 2 + n)
		rawU8(w, T_STR8)
		rawU8(w, n)
	elseif n <= 65535 then
		ensureSpace(w, 3 + n)
		rawU8(w, T_STR16)
		rawU16(w, n)
	else
		ensureSpace(w, 6 + n) -- tag(1) + varuint(max5) + data
		rawU8(w, T_STRVAR)
		rawVarUInt(w, n)
	end
	rawString(w, s, n)
end

local function analyzeArray(t: { any }, count: number): (string?, string?, number)
	if count < 2 then
		return nil, nil, count
	end

	local first = t[1]
	local firstType = type(first)

	if firstType == "boolean" then
		for i = 2, count do
			if type(t[i]) ~= "boolean" then
				return nil, nil, count
			end
		end
		return "boolean", nil, count
	end

	if firstType ~= "number" then
		return nil, nil, count
	end

	local minVal, maxVal = first, first
	local allInt = first == math.floor(first)

	for i = 2, count do
		local v = t[i]
		if type(v) ~= "number" then
			return nil, nil, count
		end
		if v ~= math.floor(v) then
			allInt = false
		end
		if v < minVal then
			minVal = v
		end
		if v > maxVal then
			maxVal = v
		end
	end

	if not allInt then
		return "number", "f32", count
	elseif minVal >= 0 and maxVal <= 255 then
		return "number", "u8", count
	elseif minVal >= -128 and maxVal <= 127 then
		return "number", "i8", count
	elseif minVal >= 0 and maxVal <= 65535 then
		return "number", "u16", count
	elseif minVal >= -32768 and maxVal <= 32767 then
		return "number", "i16", count
	elseif minVal >= 0 and maxVal <= 4294967295 then
		return "number", "u32", count
	elseif minVal >= -2147483648 and maxVal <= 2147483647 then
		return "number", "i32", count
	end
	return "number", "f64", count
end

local function packTable(w: Writer, t: { [any]: any })
	local count = 0
	local maxIdx = 0
	local isArray = true

	for k in t do
		count += 1
		if type(k) == "number" and k > 0 and k == math.floor(k) then
			if k > maxIdx then
				maxIdx = k
			end
		else
			isArray = false
		end
	end

	isArray = isArray and maxIdx == count

	if isArray then
		local category, dtype, arrCount = analyzeArray(t, count)

		if category == "boolean" then
			local numBytes = math.ceil(arrCount / 8)
			ensureSpace(w, 1 + 5 + numBytes)
			rawU8(w, T_BOOL_ARR)
			rawVarUInt(w, arrCount)
			for i = 0, numBytes - 1 do
				local byte = 0
				for bit = 0, 7 do
					local idx = i * 8 + bit + 1
					if idx > arrCount then
						break
					end
					if t[idx] then
						byte = bit32.bor(byte, bit32.lshift(1, bit))
					end
				end
				buffer.writeu8(w.buf, w.cursor, byte)
				w.cursor += 1
			end
			return
		end

		-- typed num arrays
		if category == "number" and dtype and arrCount >= 4 then
			local code = TYPED_CODES[dtype]
			local size = TYPED_SIZES[dtype]
			local writer = TYPED_WRITERS[dtype]

			ensureSpace(w, 2 + 5 + arrCount * size)
			rawU8(w, T_TYPED_ARR)
			rawU8(w, code)
			rawVarUInt(w, arrCount)
			for i = 1, arrCount do
				writer(w.buf, w.cursor, t[i])
				w.cursor += size
			end
			return
		end

		-- regular array
		if count <= 7 then
			wByte(w, T_ARR_BASE + count)
		elseif count <= 255 then
			ensureSpace(w, 2)
			rawU8(w, T_ARR8)
			rawU8(w, count)
		elseif count <= 65535 then
			ensureSpace(w, 3)
			rawU8(w, T_ARR16)
			rawU16(w, count)
		else
			ensureSpace(w, 6)
			rawU8(w, T_ARRVAR)
			rawVarUInt(w, count)
		end

		for i = 1, count do
			packValue(w, t[i])
		end
	else
		-- map
		if count <= 7 then
			wByte(w, T_MAP_BASE + count)
		elseif count <= 255 then
			ensureSpace(w, 2)
			rawU8(w, T_MAP8)
			rawU8(w, count)
		elseif count <= 65535 then
			ensureSpace(w, 3)
			rawU8(w, T_MAP16)
			rawU16(w, count)
		else
			ensureSpace(w, 6)
			rawU8(w, T_MAPVAR)
			rawVarUInt(w, count)
		end

		for k, v in t do
			packValue(w, k)
			packValue(w, v)
		end
	end
end

local function packVector3(w: Writer, v: Vector3)
	ensureSpace(w, 7)
	rawU8(w, T_VEC3)
	rawF16(w, v.X)
	rawF16(w, v.Y)
	rawF16(w, v.Z)
end

local function packVector2(w: Writer, v: Vector2)
	ensureSpace(w, 5)
	rawU8(w, T_VEC2)
	rawF16(w, v.X)
	rawF16(w, v.Y)
end

local function packCFrame(w: Writer, cf: CFrame)
	local pos = cf.Position
	local qi, q0, q1, q2 = compressCFrameRotation(cf)
	ensureSpace(w, 20) -- tag(1) + 3xf32(12) + u8(1) + 3xi16(6)
	rawU8(w, T_CFRAME)
	rawF32(w, pos.X)
	rawF32(w, pos.Y)
	rawF32(w, pos.Z)
	rawU8(w, qi)
	rawI16(w, q0)
	rawI16(w, q1)
	rawI16(w, q2)
end

local function packColor3(w: Writer, c: Color3)
	local r, g, b = c.R, c.G, c.B
	if r > 1 or g > 1 or b > 1 then
		ensureSpace(w, 7)
		rawU8(w, T_COLOR3_F)
		rawF16(w, r)
		rawF16(w, g)
		rawF16(w, b)
	else
		ensureSpace(w, 4)
		rawU8(w, T_COLOR3)
		rawU8(w, math.clamp(math.round(r * 255), 0, 255))
		rawU8(w, math.clamp(math.round(g * 255), 0, 255))
		rawU8(w, math.clamp(math.round(b * 255), 0, 255))
	end
end

local PACK_DISPATCH: { [string]: (Writer, any) -> () } = {}

PACK_DISPATCH["nil"] = function(w: Writer, _: any)
	wByte(w, T_NIL)
end

PACK_DISPATCH["boolean"] = function(w: Writer, v: any)
	wByte(w, v and T_TRUE or T_FALSE)
end

PACK_DISPATCH["number"] = function(w: Writer, v: any)
	packNumber(w, v)
end

PACK_DISPATCH["string"] = function(w: Writer, v: any)
	packString(w, v)
end

PACK_DISPATCH["table"] = function(w: Writer, v: any)
	packTable(w, v)
end

PACK_DISPATCH["Vector3"] = function(w: Writer, v: any)
	packVector3(w, v)
end

PACK_DISPATCH["Vector2"] = function(w: Writer, v: any)
	packVector2(w, v)
end

PACK_DISPATCH["CFrame"] = function(w: Writer, v: any)
	packCFrame(w, v)
end

PACK_DISPATCH["Color3"] = function(w: Writer, v: any)
	packColor3(w, v)
end

PACK_DISPATCH["Instance"] = function(w: Writer, v: any)
	table.insert(w.refs, v)
	local refIdx = #w.refs
	ensureSpace(w, 6)
	rawU8(w, T_INSTANCE)
	rawVarUInt(w, refIdx)
end

PACK_DISPATCH["EnumItem"] = function(w: Writer, v: any)
	local enumName = `{v.EnumType}`
	local nameLen = #enumName
	ensureSpace(w, 1 + 5 + nameLen + 2)
	rawU8(w, T_ENUMITEM)
	rawVarUInt(w, nameLen)
	rawString(w, enumName, nameLen)
	rawU16(w, v.Value)
end

PACK_DISPATCH["BrickColor"] = function(w: Writer, v: any)
	ensureSpace(w, 3)
	rawU8(w, T_BRICKCOLOR)
	rawU16(w, v.Number)
end

PACK_DISPATCH["Enum"] = function(w: Writer, v: any)
	local name = v.Name
	local nameLen = #name
	ensureSpace(w, 1 + 5 + nameLen)
	rawU8(w, T_ENUM)
	rawVarUInt(w, nameLen)
	rawString(w, name, nameLen)
end

PACK_DISPATCH["UDim2"] = function(w: Writer, v: any)
	local X, Y = v.X, v.Y
	ensureSpace(w, 17)
	rawU8(w, T_UDIM2)
	rawF32(w, X.Scale)
	rawI32(w, X.Offset)
	rawF32(w, Y.Scale)
	rawI32(w, Y.Offset)
end

PACK_DISPATCH["UDim"] = function(w: Writer, v: any)
	ensureSpace(w, 9)
	rawU8(w, T_UDIM)
	rawF32(w, v.Scale)
	rawI32(w, v.Offset)
end

PACK_DISPATCH["Rect"] = function(w: Writer, v: any)
	local Min, Max = v.Min, v.Max
	ensureSpace(w, 17)
	rawU8(w, T_RECT)
	rawF32(w, Min.X)
	rawF32(w, Min.Y)
	rawF32(w, Max.X)
	rawF32(w, Max.Y)
end

PACK_DISPATCH["NumberRange"] = function(w: Writer, v: any)
	ensureSpace(w, 9)
	rawU8(w, T_NUMBERRANGE)
	rawF32(w, v.Min)
	rawF32(w, v.Max)
end

PACK_DISPATCH["Ray"] = function(w: Writer, v: any)
	local Origin, Direction = v.Origin, v.Direction
	ensureSpace(w, 25)
	rawU8(w, T_RAY)
	rawF32(w, Origin.X)
	rawF32(w, Origin.Y)
	rawF32(w, Origin.Z)
	rawF32(w, Direction.X)
	rawF32(w, Direction.Y)
	rawF32(w, Direction.Z)
end

PACK_DISPATCH["ColorSequence"] = function(w: Writer, v: any)
	local keypoints = v.Keypoints
	local kpCount = #keypoints
	ensureSpace(w, 2 + kpCount * 7)
	rawU8(w, T_COLSEQ)
	rawU8(w, kpCount)
	for _, kp in keypoints do
		rawF32(w, kp.Time)
		local c = kp.Value
		rawU8(w, math.clamp(math.round(c.R * 255), 0, 255))
		rawU8(w, math.clamp(math.round(c.G * 255), 0, 255))
		rawU8(w, math.clamp(math.round(c.B * 255), 0, 255))
	end
end

PACK_DISPATCH["NumberSequence"] = function(w: Writer, v: any)
	local keypoints = v.Keypoints
	local kpCount = #keypoints
	ensureSpace(w, 2 + kpCount * 12)
	rawU8(w, T_NUMSEQ)
	rawU8(w, kpCount)
	for _, kp in keypoints do
		rawF32(w, kp.Time)
		rawF32(w, kp.Value)
		rawF32(w, kp.Envelope)
	end
end

PACK_DISPATCH["buffer"] = function(w: Writer, v: any)
	local len = buffer.len(v)
	ensureSpace(w, 1 + 5 + len)
	rawU8(w, T_BUFFER)
	rawVarUInt(w, len)
	buffer.copy(w.buf, w.cursor, v, 0, len)
	w.cursor += len
end

PACK_DISPATCH["Vector3int16"] = function(w: Writer, v: any)
	ensureSpace(w, 7)
	rawU8(w, T_VEC3I16)
	rawI16(w, v.X)
	rawI16(w, v.Y)
	rawI16(w, v.Z)
end

PACK_DISPATCH["Vector2int16"] = function(w: Writer, v: any)
	ensureSpace(w, 5)
	rawU8(w, T_VEC2I16)
	rawI16(w, v.X)
	rawI16(w, v.Y)
end

PACK_DISPATCH["TweenInfo"] = function(w: Writer, v: any)
	ensureSpace(w, 16) -- tag(1) + f32(4) + u8(1) + u8(1) + i32(4) + u8(1) + f32(4)
	rawU8(w, T_TWEENINFO)
	rawF32(w, v.Time)
	rawU8(w, v.EasingStyle.Value)
	rawU8(w, v.EasingDirection.Value)
	rawI32(w, v.RepeatCount)
	rawU8(w, v.Reverses and 1 or 0)
	rawF32(w, v.DelayTime)
end

PACK_DISPATCH["PhysicalProperties"] = function(w: Writer, v: any)
	ensureSpace(w, 21) -- tag(1) + 5xf32(20)
	rawU8(w, T_PHYSPROP)
	rawF32(w, v.Density)
	rawF32(w, v.Friction)
	rawF32(w, v.Elasticity)
	rawF32(w, v.FrictionWeight)
	rawF32(w, v.ElasticityWeight)
end

PACK_DISPATCH["Font"] = function(w: Writer, v: any)
	local family = v.Family
	local familyLen = #family
	ensureSpace(w, 1 + 5 + familyLen + 3) -- tag + varuint + str + u16 + u8
	rawU8(w, T_FONT)
	rawVarUInt(w, familyLen)
	rawString(w, family, familyLen)
	rawU16(w, v.Weight.Value)
	rawU8(w, v.Style.Value)
end

PACK_DISPATCH["DateTime"] = function(w: Writer, v: any)
	ensureSpace(w, 9) -- tag(1) + f64(8)
	rawU8(w, T_DATETIME)
	rawF64(w, v.UnixTimestampMillis)
end

packValue = function(w: Writer, v: any)
	local handler = PACK_DISPATCH[typeof(v)]
	if handler then
		handler(w, v)
	else
		error(`Unsupported type: {typeof(v)}`)
	end
end

local UNPACK: { (buffer, number, { any }?, number) -> (any, number) } = table.create(256)

do
	local function unpackError(_: buffer, _: number, _: { any }?, tag: number): (any, number)
		error(`(serdes) unknown type: {tag}`)
		return nil :: any, 0
	end
	for i = 1, 256 do
		UNPACK[i] = unpackError
	end
end

do
	local function handler(_: buffer, pos: number, _: { any }?, tag: number): (any, number)
		return tag, pos
	end
	for i = 0x00, 0x7F do
		UNPACK[i + 1] = handler
	end
end

do
	local function handler(_: buffer, pos: number, _: { any }?, tag: number): (any, number)
		return tag - 0x80 - 32, pos
	end
	for i = 0x80, 0x9F do
		UNPACK[i + 1] = handler
	end
end

-- scalar types
UNPACK[T_NIL + 1] = function(_: buffer, pos: number, _: { any }?, _: number): (any, number)
	return nil, pos
end

UNPACK[T_FALSE + 1] = function(_: buffer, pos: number, _: { any }?, _: number): (any, number)
	return false, pos
end

UNPACK[T_TRUE + 1] = function(_: buffer, pos: number, _: { any }?, _: number): (any, number)
	return true, pos
end

-- numeric types
UNPACK[T_U8 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return buffer.readu8(buf, pos), pos + 1
end

UNPACK[T_U16 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return buffer.readu16(buf, pos), pos + 2
end

UNPACK[T_U32 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return buffer.readu32(buf, pos), pos + 4
end

UNPACK[T_I8 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return buffer.readi8(buf, pos), pos + 1
end

UNPACK[T_I16 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return buffer.readi16(buf, pos), pos + 2
end

UNPACK[T_I32 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return buffer.readi32(buf, pos), pos + 4
end

UNPACK[T_F16 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return readF16(buf, pos), pos + 2
end

UNPACK[T_F32 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return buffer.readf32(buf, pos), pos + 4
end

UNPACK[T_F64 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return buffer.readf64(buf, pos), pos + 8
end

UNPACK[T_VEC3I16 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return Vector3int16.new(buffer.readi16(buf, pos), buffer.readi16(buf, pos + 2), buffer.readi16(buf, pos + 4)),
		pos + 6
end

UNPACK[T_VEC2I16 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return Vector2int16.new(buffer.readi16(buf, pos), buffer.readi16(buf, pos + 2)), pos + 4
end

UNPACK[T_TWEENINFO + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return TweenInfo.new(
		buffer.readf32(buf, pos),
		Enum.EasingStyle:FromValue(buffer.readu8(buf, pos + 4)),
		Enum.EasingDirection:FromValue(buffer.readu8(buf, pos + 5)),
		buffer.readi32(buf, pos + 6),
		buffer.readu8(buf, pos + 10) ~= 0,
		buffer.readf32(buf, pos + 11)
	),
		pos + 15
end

UNPACK[T_PHYSPROP + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return PhysicalProperties.new(
		buffer.readf32(buf, pos),
		buffer.readf32(buf, pos + 4),
		buffer.readf32(buf, pos + 8),
		buffer.readf32(buf, pos + 12),
		buffer.readf32(buf, pos + 16)
	),
		pos + 20
end

UNPACK[T_FONT + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local familyLen
	familyLen, pos = readVarUInt(buf, pos)
	local family = buffer.readstring(buf, pos, familyLen)
	pos += familyLen
	local weight = buffer.readu16(buf, pos)
	local style = buffer.readu8(buf, pos + 2)
	return Font.new(family, Enum.FontWeight:FromValue(weight), Enum.FontStyle:FromValue(style)), pos + 3
end

UNPACK[T_DATETIME + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return DateTime.fromUnixTimestampMillis(buffer.readf64(buf, pos)), pos + 8
end

do
	local function handler(buf: buffer, pos: number, _: { any }?, tag: number): (any, number)
		local n = tag - T_STR_BASE
		return buffer.readstring(buf, pos, n), pos + n
	end
	for i = T_STR_BASE, T_STR_BASE + 15 do
		UNPACK[i + 1] = handler
	end
end

UNPACK[T_STR8 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local n = buffer.readu8(buf, pos)
	return buffer.readstring(buf, pos + 1, n), pos + 1 + n
end

UNPACK[T_STR16 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local n = buffer.readu16(buf, pos)
	return buffer.readstring(buf, pos + 2, n), pos + 2 + n
end

UNPACK[T_STRVAR + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local n
	n, pos = readVarUInt(buf, pos)
	return buffer.readstring(buf, pos, n), pos + n
end

do
	local function handler(buf: buffer, pos: number, refs: { any }?, tag: number): (any, number)
		local count = tag - T_ARR_BASE
		local arr = table.create(count)
		for i = 1, count do
			arr[i], pos = unpackValue(buf, pos, refs)
		end
		return arr, pos
	end
	for i = T_ARR_BASE, T_ARR_BASE + 7 do
		UNPACK[i + 1] = handler
	end
end

UNPACK[T_ARR8 + 1] = function(buf: buffer, pos: number, refs: { any }?, _: number): (any, number)
	local count = buffer.readu8(buf, pos)
	pos += 1
	local arr = table.create(count)
	for i = 1, count do
		arr[i], pos = unpackValue(buf, pos, refs)
	end
	return arr, pos
end

UNPACK[T_ARR16 + 1] = function(buf: buffer, pos: number, refs: { any }?, _: number): (any, number)
	local count = buffer.readu16(buf, pos)
	pos += 2
	local arr = table.create(count)
	for i = 1, count do
		arr[i], pos = unpackValue(buf, pos, refs)
	end
	return arr, pos
end

UNPACK[T_ARRVAR + 1] = function(buf: buffer, pos: number, refs: { any }?, _: number): (any, number)
	local count
	count, pos = readVarUInt(buf, pos)
	local arr = table.create(count)
	for i = 1, count do
		arr[i], pos = unpackValue(buf, pos, refs)
	end
	return arr, pos
end

do
	local function handler(buf: buffer, pos: number, refs: { any }?, tag: number): (any, number)
		local count = tag - T_MAP_BASE
		local map = {}
		for _ = 1, count do
			local k, v
			k, pos = unpackValue(buf, pos, refs)
			v, pos = unpackValue(buf, pos, refs)
			map[k] = v
		end
		return map, pos
	end
	for i = T_MAP_BASE, T_MAP_BASE + 7 do
		UNPACK[i + 1] = handler
	end
end

UNPACK[T_MAP8 + 1] = function(buf: buffer, pos: number, refs: { any }?, _: number): (any, number)
	local count = buffer.readu8(buf, pos)
	pos += 1
	local map = {}
	for _ = 1, count do
		local k, v
		k, pos = unpackValue(buf, pos, refs)
		v, pos = unpackValue(buf, pos, refs)
		map[k] = v
	end
	return map, pos
end

UNPACK[T_MAP16 + 1] = function(buf: buffer, pos: number, refs: { any }?, _: number): (any, number)
	local count = buffer.readu16(buf, pos)
	pos += 2
	local map = {}
	for _ = 1, count do
		local k, v
		k, pos = unpackValue(buf, pos, refs)
		v, pos = unpackValue(buf, pos, refs)
		map[k] = v
	end
	return map, pos
end

UNPACK[T_MAPVAR + 1] = function(buf: buffer, pos: number, refs: { any }?, _: number): (any, number)
	local count
	count, pos = readVarUInt(buf, pos)
	local map = {}
	for _ = 1, count do
		local k, v
		k, pos = unpackValue(buf, pos, refs)
		v, pos = unpackValue(buf, pos, refs)
		map[k] = v
	end
	return map, pos
end

-- typed number array
UNPACK[T_TYPED_ARR + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local subtype = buffer.readu8(buf, pos)
	pos += 1
	local count
	count, pos = readVarUInt(buf, pos)
	local reader = TYPED_READERS[subtype]
	local arr = table.create(count)
	for i = 1, count do
		arr[i], pos = reader(buf, pos)
	end
	return arr, pos
end

-- boolean bitpacked array
UNPACK[T_BOOL_ARR + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local count
	count, pos = readVarUInt(buf, pos)
	local arr = table.create(count)
	local numBytes = math.ceil(count / 8)
	for i = 0, numBytes - 1 do
		local byte = buffer.readu8(buf, pos + i)
		for bit = 0, 7 do
			local idx = i * 8 + bit + 1
			if idx > count then
				break
			end
			arr[idx] = bit32.band(byte, bit32.lshift(1, bit)) ~= 0
		end
	end
	return arr, pos + numBytes
end

-- buffer
UNPACK[T_BUFFER + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local len
	len, pos = readVarUInt(buf, pos)
	local b = buffer.create(len)
	buffer.copy(b, 0, buf, pos, len)
	return b, pos + len
end

-- Vector3
UNPACK[T_VEC3 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local x = readF16(buf, pos)
	local y = readF16(buf, pos + 2)
	local z = readF16(buf, pos + 4)
	return Vector3.new(x, y, z), pos + 6
end

-- Vector2
UNPACK[T_VEC2 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local x = readF16(buf, pos)
	local y = readF16(buf, pos + 2)
	return Vector2.new(x, y), pos + 4
end

-- CFrame
UNPACK[T_CFRAME + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local px = buffer.readf32(buf, pos)
	local py = buffer.readf32(buf, pos + 4)
	local pz = buffer.readf32(buf, pos + 8)
	local qi = buffer.readu8(buf, pos + 12)
	local q0 = buffer.readi16(buf, pos + 13)
	local q1 = buffer.readi16(buf, pos + 15)
	local q2 = buffer.readi16(buf, pos + 17)
	local qx, qy, qz, qw = decompressCFrameRotation(qi, q0, q1, q2)
	return CFrame.new(px, py, pz, qx, qy, qz, qw), pos + 19
end

-- Color3 (RGB bytes)
UNPACK[T_COLOR3 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local r = buffer.readu8(buf, pos)
	local g = buffer.readu8(buf, pos + 1)
	local b = buffer.readu8(buf, pos + 2)
	return Color3.fromRGB(r, g, b), pos + 3
end

-- Color3 (f16 floats)
UNPACK[T_COLOR3_F + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local r = readF16(buf, pos)
	local g = readF16(buf, pos + 2)
	local b = readF16(buf, pos + 4)
	return Color3.new(r, g, b), pos + 6
end

-- BrickColor
UNPACK[T_BRICKCOLOR + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return BrickColor.new(buffer.readu16(buf, pos)), pos + 2
end

-- Instance
UNPACK[T_INSTANCE + 1] = function(buf: buffer, pos: number, refs: { any }?, _: number): (any, number)
	local idx
	idx, pos = readVarUInt(buf, pos)
	return refs and refs[idx] or nil, pos
end

-- EnumItem
UNPACK[T_ENUMITEM + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local nameLen
	nameLen, pos = readVarUInt(buf, pos)
	local enumName = buffer.readstring(buf, pos, nameLen)
	pos += nameLen
	local val = buffer.readu16(buf, pos)
	return (Enum :: any)[enumName]:FromValue(val), pos + 2
end

-- Enum
UNPACK[T_ENUM + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local nameLen
	nameLen, pos = readVarUInt(buf, pos)
	local enumName = buffer.readstring(buf, pos, nameLen)
	return (Enum :: any)[enumName], pos + nameLen
end

-- UDim2
UNPACK[T_UDIM2 + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local xs = buffer.readf32(buf, pos)
	local xo = buffer.readi32(buf, pos + 4)
	local ys = buffer.readf32(buf, pos + 8)
	local yo = buffer.readi32(buf, pos + 12)
	return UDim2.new(xs, xo, ys, yo), pos + 16
end

-- UDim
UNPACK[T_UDIM + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local s = buffer.readf32(buf, pos)
	local o = buffer.readi32(buf, pos + 4)
	return UDim.new(s, o), pos + 8
end

-- Rect
UNPACK[T_RECT + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return Rect.new(
		buffer.readf32(buf, pos),
		buffer.readf32(buf, pos + 4),
		buffer.readf32(buf, pos + 8),
		buffer.readf32(buf, pos + 12)
	),
		pos + 16
end

-- NumberRange
UNPACK[T_NUMBERRANGE + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return NumberRange.new(buffer.readf32(buf, pos), buffer.readf32(buf, pos + 4)), pos + 8
end

-- Ray
UNPACK[T_RAY + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	return Ray.new(
		Vector3.new(buffer.readf32(buf, pos), buffer.readf32(buf, pos + 4), buffer.readf32(buf, pos + 8)),
		Vector3.new(buffer.readf32(buf, pos + 12), buffer.readf32(buf, pos + 16), buffer.readf32(buf, pos + 20))
	),
		pos + 24
end

-- ColorSequence
UNPACK[T_COLSEQ + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local count = buffer.readu8(buf, pos)
	pos += 1
	local keypoints = table.create(count)
	for i = 1, count do
		local time = buffer.readf32(buf, pos)
		local r = buffer.readu8(buf, pos + 4)
		local g = buffer.readu8(buf, pos + 5)
		local b = buffer.readu8(buf, pos + 6)
		keypoints[i] = ColorSequenceKeypoint.new(time, Color3.fromRGB(r, g, b))
		pos += 7
	end
	return ColorSequence.new(keypoints), pos
end

-- NumberSequence
UNPACK[T_NUMSEQ + 1] = function(buf: buffer, pos: number, _: { any }?, _: number): (any, number)
	local count = buffer.readu8(buf, pos)
	pos += 1
	local keypoints = table.create(count)
	for i = 1, count do
		local time = buffer.readf32(buf, pos)
		local value = buffer.readf32(buf, pos + 4)
		local envelope = buffer.readf32(buf, pos + 8)
		keypoints[i] = NumberSequenceKeypoint.new(time, value, envelope)
		pos += 12
	end
	return NumberSequence.new(keypoints), pos
end

unpackValue = function(buf: buffer, pos: number, refs: { any }?): (any, number)
	local tag = buffer.readu8(buf, pos)
	return UNPACK[tag + 1](buf, pos + 1, refs, tag)
end

local function build(w: Writer): buffer
	local result = buffer.create(w.cursor)
	buffer.copy(result, 0, w.buf, 0, w.cursor)
	return result
end

local function buildWithRefs(w: Writer): (buffer, { any }?)
	local result = buffer.create(w.cursor)
	buffer.copy(result, 0, w.buf, 0, w.cursor)
	local refs = w.refs
	if #refs > 0 then
		w.refs = {}
		return result, refs
	end
	return result, nil
end

local function reset(w: Writer)
	w.cursor = 0
	table.clear(w.refs)
end

local Schema = {}
Schema.__custom_datatypes = {}

export type SchemaType = { type: string, [any]: any }

Schema.u8 = { type = "u8" }
Schema.i8 = { type = "i8" }
Schema.u16 = { type = "u16" }
Schema.i16 = { type = "i16" }
Schema.u32 = { type = "u32" }
Schema.i32 = { type = "i32" }
Schema.f16 = { type = "f16" }
Schema.f32 = { type = "f32" }
Schema.f64 = { type = "f64" }
Schema.boolean = { type = "boolean" }
Schema.vector3 = { type = "vector3" }
Schema.vector2 = { type = "vector2" }
Schema.cframe = { type = "cframe" }
Schema.color3 = { type = "color3" }
Schema.color3f16 = { type = "color3f16" }
Schema.instance = { type = "instance" }
Schema.string = { type = "string" }
Schema.udim2 = { type = "udim2" }
Schema.udim = { type = "udim" }
Schema.rect = { type = "rect" }
Schema.numberrange = { type = "numberrange" }
Schema.ray = { type = "ray" }
Schema.colorsequence = { type = "colorsequence" }
Schema.numbersequence = { type = "numbersequence" }
Schema.brickcolor = { type = "brickcolor" }
Schema.buffer = { type = "buffer" }
Schema.vector3int16 = { type = "vector3int16" }
Schema.vector2int16 = { type = "vector2int16" }
Schema.tweeninfo = { type = "tweeninfo" }
Schema.physicalproperties = { type = "physicalproperties" }
Schema.font = { type = "font" }
Schema.datetime = { type = "datetime" }

function Schema.optional(item: SchemaType): SchemaType
	return { type = "optional", item = item }
end

function Schema.array(item: SchemaType): SchemaType
	return { type = "array", item = item }
end

function Schema.map(key: SchemaType, value: SchemaType): SchemaType
	return { type = "map", key = key, value = value }
end

function Schema.struct(fields: { [string]: SchemaType }): SchemaType
	local orderedFields = {}
	for k, v in fields do
		table.insert(orderedFields, { key = k, schema = v })
	end
	table.sort(orderedFields, function(a, b)
		return a.key < b.key
	end)
	return { type = "struct", fields = orderedFields }
end

function Schema.custom_datatype(
	name: string,
	object: { any },
	writer: (w: Writer, v: any) -> (),
	reader: (b: buffer, c: number, refs: { Instance }?) -> (any, number)
)
	if Schema[name] then
		warn(`[Warp.Schema]: this 'custom_datatype': "{name}" is already exists, try changing the name.`)
		return
	end
	(object :: any).type = name
	Schema[name] = object
	Schema.__custom_datatypes[name] = {
		writer = writer,
		reader = reader,
	}
end

local SCHEMA_FIXED_SIZES: { [string]: number } = {
	u8 = 1,
	i8 = 1,
	u16 = 2,
	i16 = 2,
	u32 = 4,
	i32 = 4,
	f16 = 2,
	f32 = 4,
	f64 = 8,
	boolean = 1,
	vector3 = 6,
	vector2 = 4,
	cframe = 19,
	color3 = 3,
	color3f16 = 6,
	udim2 = 16,
	udim = 8,
	rect = 16,
	numberrange = 8,
	ray = 24,
	brickcolor = 2,
	vector3int16 = 6,
	vector2int16 = 4,
	tweeninfo = 15,
	physicalproperties = 20,
	datetime = 8,
}

local function compilePacker(s: SchemaType): (Writer, any) -> ()
	local schema_type = s.type

	if Schema.__custom_datatypes[schema_type] then
		return Schema.__custom_datatypes[schema_type].writer
	end

	if schema_type == "u8" then
		return function(w: Writer, v: any)
			ensureSpace(w, 1)
			rawU8(w, v)
		end
	end
	if schema_type == "i8" then
		return function(w: Writer, v: any)
			ensureSpace(w, 1)
			buffer.writei8(w.buf, w.cursor, v)
			w.cursor += 1
		end
	end
	if schema_type == "u16" then
		return function(w: Writer, v: any)
			ensureSpace(w, 2)
			rawU16(w, v)
		end
	end
	if schema_type == "i16" then
		return function(w: Writer, v: any)
			ensureSpace(w, 2)
			rawI16(w, v)
		end
	end
	if schema_type == "u32" then
		return function(w: Writer, v: any)
			ensureSpace(w, 4)
			rawU32(w, v)
		end
	end
	if schema_type == "i32" then
		return function(w: Writer, v: any)
			ensureSpace(w, 4)
			rawI32(w, v)
		end
	end
	if schema_type == "f16" then
		return function(w: Writer, v: any)
			ensureSpace(w, 2)
			rawF16(w, v)
		end
	end
	if schema_type == "f32" then
		return function(w: Writer, v: any)
			ensureSpace(w, 4)
			rawF32(w, v)
		end
	end
	if schema_type == "f64" then
		return function(w: Writer, v: any)
			ensureSpace(w, 8)
			rawF64(w, v)
		end
	end
	if schema_type == "boolean" then
		return function(w: Writer, v: any)
			ensureSpace(w, 1)
			rawU8(w, v and 1 or 0)
		end
	end
	if schema_type == "string" then
		return function(w: Writer, v: any)
			local len = #v
			ensureSpace(w, 5 + len)
			rawVarUInt(w, len)
			rawString(w, v, len)
		end
	end

	if schema_type == "vector3" then
		return function(w: Writer, v: any)
			ensureSpace(w, 6)
			rawF16(w, v.X)
			rawF16(w, v.Y)
			rawF16(w, v.Z)
		end
	end
	if schema_type == "vector2" then
		return function(w: Writer, v: any)
			ensureSpace(w, 4)
			rawF16(w, v.X)
			rawF16(w, v.Y)
		end
	end

	if schema_type == "cframe" then
		return function(w: Writer, v: any)
			ensureSpace(w, 19) -- 3xf32(12) + u8(1) + 3xi16(6)
			local pos = v.Position
			local qi, q0, q1, q2 = compressCFrameRotation(v)
			rawF32(w, pos.X)
			rawF32(w, pos.Y)
			rawF32(w, pos.Z)
			rawU8(w, qi)
			rawI16(w, q0)
			rawI16(w, q1)
			rawI16(w, q2)
		end
	end

	if schema_type == "color3" then
		return function(w: Writer, v: any)
			ensureSpace(w, 3)
			rawU8(w, math.clamp(math.round(v.R * 255), 0, 255))
			rawU8(w, math.clamp(math.round(v.G * 255), 0, 255))
			rawU8(w, math.clamp(math.round(v.B * 255), 0, 255))
		end
	end

	if schema_type == "color3f16" then
		return function(w: Writer, v: any)
			ensureSpace(w, 6)
			rawF16(w, math.clamp(v.R * 255, 0, 255))
			rawF16(w, math.clamp(v.G * 255, 0, 255))
			rawF16(w, math.clamp(v.B * 255, 0, 255))
		end
	end

	if schema_type == "udim2" then
		return function(w: Writer, v: any)
			ensureSpace(w, 16)
			rawF32(w, v.X.Scale)
			rawI32(w, v.X.Offset)
			rawF32(w, v.Y.Scale)
			rawI32(w, v.Y.Offset)
		end
	end
	if schema_type == "udim" then
		return function(w: Writer, v: any)
			ensureSpace(w, 8)
			rawF32(w, v.Scale)
			rawI32(w, v.Offset)
		end
	end
	if schema_type == "rect" then
		return function(w: Writer, v: any)
			ensureSpace(w, 16)
			rawF32(w, v.Min.X)
			rawF32(w, v.Min.Y)
			rawF32(w, v.Max.X)
			rawF32(w, v.Max.Y)
		end
	end
	if schema_type == "numberrange" then
		return function(w: Writer, v: any)
			ensureSpace(w, 8)
			rawF32(w, v.Min)
			rawF32(w, v.Max)
		end
	end
	if schema_type == "ray" then
		return function(w: Writer, v: any)
			ensureSpace(w, 24)
			rawF32(w, v.Origin.X)
			rawF32(w, v.Origin.Y)
			rawF32(w, v.Origin.Z)
			rawF32(w, v.Direction.X)
			rawF32(w, v.Direction.Y)
			rawF32(w, v.Direction.Z)
		end
	end
	if schema_type == "colorsequence" then
		return function(w: Writer, v: any)
			local kps = v.Keypoints
			local n = #kps
			ensureSpace(w, 1 + n * 7)
			rawU8(w, n)
			for _, kp in kps do
				rawF32(w, kp.Time)
				local c = kp.Value
				rawU8(w, math.clamp(math.round(c.R * 255), 0, 255))
				rawU8(w, math.clamp(math.round(c.G * 255), 0, 255))
				rawU8(w, math.clamp(math.round(c.B * 255), 0, 255))
			end
		end
	end
	if schema_type == "numbersequence" then
		return function(w: Writer, v: any)
			local kps = v.Keypoints
			local n = #kps
			ensureSpace(w, 1 + n * 12)
			rawU8(w, n)
			for _, kp in kps do
				rawF32(w, kp.Time)
				rawF32(w, kp.Value)
				rawF32(w, kp.Envelope)
			end
		end
	end
	if schema_type == "brickcolor" then
		return function(w: Writer, v: any)
			ensureSpace(w, 2)
			rawU16(w, v.Number)
		end
	end
	if schema_type == "buffer" then
		return function(w: Writer, v: any)
			local len = buffer.len(v)
			ensureSpace(w, 5 + len)
			rawVarUInt(w, len)
			buffer.copy(w.buf, w.cursor, v, 0, len)
			w.cursor += len
		end
	end
	if schema_type == "vector3int16" then
		return function(w: Writer, v: any)
			ensureSpace(w, 6)
			rawI16(w, v.X)
			rawI16(w, v.Y)
			rawI16(w, v.Z)
		end
	end
	if schema_type == "vector2int16" then
		return function(w: Writer, v: any)
			ensureSpace(w, 4)
			rawI16(w, v.X)
			rawI16(w, v.Y)
		end
	end
	if schema_type == "tweeninfo" then
		return function(w: Writer, v: any)
			ensureSpace(w, 15)
			rawF32(w, v.Time)
			rawU8(w, v.EasingStyle.Value)
			rawU8(w, v.EasingDirection.Value)
			rawI32(w, v.RepeatCount)
			rawU8(w, v.Reverses and 1 or 0)
			rawF32(w, v.DelayTime)
		end
	end
	if schema_type == "physicalproperties" then
		return function(w: Writer, v: any)
			ensureSpace(w, 20)
			rawF32(w, v.Density)
			rawF32(w, v.Friction)
			rawF32(w, v.Elasticity)
			rawF32(w, v.FrictionWeight)
			rawF32(w, v.ElasticityWeight)
		end
	end
	if schema_type == "font" then
		return function(w: Writer, v: any)
			local family = v.Family
			local familyLen = #family
			ensureSpace(w, 5 + familyLen + 3)
			rawVarUInt(w, familyLen)
			rawString(w, family, familyLen)
			rawU16(w, v.Weight.Value)
			rawU8(w, v.Style.Value)
		end
	end
	if schema_type == "datetime" then
		return function(w: Writer, v: any)
			ensureSpace(w, 8)
			rawF64(w, v.UnixTimestampMillis)
		end
	end

	if schema_type == "instance" then
		return function(w: Writer, v: any)
			table.insert(w.refs, v)
			ensureSpace(w, 5)
			rawVarUInt(w, #w.refs)
		end
	end

	if schema_type == "struct" then
		local fields = {}
		local optionalIndices = {}

		for idx, field in ipairs(s.fields) do
			local isOpt = field.schema.type == "optional"
			table.insert(fields, {
				key = field.key,
				packer = compilePacker(isOpt and field.schema.item or field.schema),
				optional = isOpt,
			})
			if isOpt then
				table.insert(optionalIndices, idx)
			end
		end

		local numOpt = #optionalIndices

		if numOpt == 0 then
			-- Pre-calculate total fixed size for all-fixed structs
			local totalFixed = 0
			local allFixed = true
			for _, field in ipairs(s.fields) do
				local size = SCHEMA_FIXED_SIZES[field.schema.type]
				if size then
					totalFixed += size
				else
					allFixed = false
					break
				end
			end

			if allFixed and totalFixed > 0 then
				return function(w: Writer, v: any)
					if type(v) ~= "table" then
						error(`Expected table for struct, got {typeof(v)}`)
					end
					ensureSpace(w, totalFixed)
					for _, f in fields do
						local val = v[f.key]
						if val == nil then
							error(`Schema Error: Missing required field '{f.key}'`)
						end
						f.packer(w, val)
					end
				end
			end

			return function(w: Writer, v: any)
				if type(v) ~= "table" then
					error(`Expected table for struct, got {typeof(v)}`)
				end
				for _, f in fields do
					local val = v[f.key]
					if val == nil then
						error(`Schema Error: Missing required field '{f.key}'`)
					end
					f.packer(w, val)
				end
			end
		end

		local maskBytes = math.ceil(numOpt / 8)

		return function(w: Writer, v: any)
			if type(v) ~= "table" then
				error(`Expected table for struct, got {typeof(v)}`)
			end

			ensureSpace(w, maskBytes)
			for i = 0, maskBytes - 1 do
				local byte = 0
				for b = 0, 7 do
					local optIdx = i * 8 + b + 1
					if optIdx > numOpt then
						break
					end
					local fieldIdx = optionalIndices[optIdx]
					if v[fields[fieldIdx].key] ~= nil then
						byte = bit32.bor(byte, bit32.lshift(1, b))
					end
				end
				buffer.writeu8(w.buf, w.cursor, byte)
				w.cursor += 1
			end

			for _, f in fields do
				local val = v[f.key]
				if f.optional then
					if val ~= nil then
						f.packer(w, val)
					end
				else
					if val == nil then
						error(`Schema Error: Missing required field '{f.key}'`)
					end
					f.packer(w, val)
				end
			end
		end
	end

	if schema_type == "array" then
		local itemSchema = s.item

		if itemSchema.type == "boolean" then
			return function(w: Writer, v: any)
				local len = #v
				local numBytes = math.ceil(len / 8)
				ensureSpace(w, 5 + numBytes)
				rawVarUInt(w, len)
				for i = 0, numBytes - 1 do
					local byte = 0
					for bit = 0, 7 do
						local idx = i * 8 + bit + 1
						if idx > len then
							break
						end
						if v[idx] then
							byte = bit32.bor(byte, bit32.lshift(1, bit))
						end
					end
					buffer.writeu8(w.buf, w.cursor, byte)
					w.cursor += 1
				end
			end
		end

		local itemPacker = compilePacker(itemSchema)
		return function(w: Writer, v: any)
			if type(v) ~= "table" then
				error(`Expected table for array, got {typeof(v)}`)
			end
			local len = #v
			wVarUInt(w, len)
			for i = 1, len do
				if v[i] == nil then
					error(`Schema Error: Array item at index {i} is nil`)
				end
				itemPacker(w, v[i])
			end
		end
	end

	if schema_type == "map" then
		local keyPacker = compilePacker(s.key)
		local valPacker = compilePacker(s.value)
		return function(w: Writer, v: any)
			local count = 0
			for _ in v do
				count += 1
			end
			wVarUInt(w, count)
			for k, val in v do
				keyPacker(w, k)
				valPacker(w, val)
			end
		end
	end

	if schema_type == "optional" then
		local itemPacker = compilePacker(s.item)
		return function(w: Writer, v: any)
			if v == nil then
				wByte(w, 0)
			else
				wByte(w, 1)
				itemPacker(w, v)
			end
		end
	end

	return function()
		return
	end
end

local function compileReader(s: SchemaType): (buffer, number, { any }?) -> (any, number)
	local schema_type = s.type

	if Schema.__custom_datatypes[schema_type] then
		return Schema.__custom_datatypes[schema_type].reader
	end

	if schema_type == "u8" then
		return function(b: buffer, c: number)
			return buffer.readu8(b, c), c + 1
		end
	end
	if schema_type == "i8" then
		return function(b: buffer, c: number)
			return buffer.readi8(b, c), c + 1
		end
	end
	if schema_type == "u16" then
		return function(b: buffer, c: number)
			return buffer.readu16(b, c), c + 2
		end
	end
	if schema_type == "i16" then
		return function(b: buffer, c: number)
			return buffer.readi16(b, c), c + 2
		end
	end
	if schema_type == "u32" then
		return function(b: buffer, c: number)
			return buffer.readu32(b, c), c + 4
		end
	end
	if schema_type == "i32" then
		return function(b: buffer, c: number)
			return buffer.readi32(b, c), c + 4
		end
	end
	if schema_type == "f16" then
		return function(b: buffer, c: number)
			return readF16(b, c), c + 2
		end
	end
	if schema_type == "f32" then
		return function(b: buffer, c: number)
			return buffer.readf32(b, c), c + 4
		end
	end
	if schema_type == "f64" then
		return function(b: buffer, c: number)
			return buffer.readf64(b, c), c + 8
		end
	end
	if schema_type == "boolean" then
		return function(b: buffer, c: number)
			return buffer.readu8(b, c) ~= 0, c + 1
		end
	end
	if schema_type == "string" then
		return function(b: buffer, c: number)
			local len
			len, c = readVarUInt(b, c)
			return buffer.readstring(b, c, len), c + len
		end
	end
	if schema_type == "vector3" then
		return function(b: buffer, c: number)
			local x = readF16(b, c)
			local y = readF16(b, c + 2)
			local z = readF16(b, c + 4)
			return Vector3.new(x, y, z), c + 6
		end
	end
	if schema_type == "vector2" then
		return function(b: buffer, c: number)
			local x = readF16(b, c)
			local y = readF16(b, c + 2)
			return Vector2.new(x, y), c + 4
		end
	end
	if schema_type == "color3" then
		return function(b: buffer, c: number)
			local r = buffer.readu8(b, c)
			local g = buffer.readu8(b, c + 1)
			local bVal = buffer.readu8(b, c + 2)
			return Color3.fromRGB(r, g, bVal), c + 3
		end
	end
	if schema_type == "color3f16" then
		return function(b: buffer, c: number)
			local r = readF16(b, c)
			local g = readF16(b, c + 2)
			local bVal = readF16(b, c + 4)
			return Color3.fromRGB(r, g, bVal), c + 6
		end
	end
	if schema_type == "cframe" then
		return function(b: buffer, c: number)
			local px = buffer.readf32(b, c)
			local py = buffer.readf32(b, c + 4)
			local pz = buffer.readf32(b, c + 8)
			local qi = buffer.readu8(b, c + 12)
			local q0 = buffer.readi16(b, c + 13)
			local q1 = buffer.readi16(b, c + 15)
			local q2 = buffer.readi16(b, c + 17)
			local qx, qy, qz, qw = decompressCFrameRotation(qi, q0, q1, q2)
			return CFrame.new(px, py, pz, qx, qy, qz, qw), c + 19
		end
	end

	if schema_type == "udim2" then
		return function(b: buffer, c: number)
			return UDim2.new(
				buffer.readf32(b, c),
				buffer.readi32(b, c + 4),
				buffer.readf32(b, c + 8),
				buffer.readi32(b, c + 12)
			),
				c + 16
		end
	end
	if schema_type == "udim" then
		return function(b: buffer, c: number)
			return UDim.new(buffer.readf32(b, c), buffer.readi32(b, c + 4)), c + 8
		end
	end
	if schema_type == "rect" then
		return function(b: buffer, c: number)
			return Rect.new(
				buffer.readf32(b, c),
				buffer.readf32(b, c + 4),
				buffer.readf32(b, c + 8),
				buffer.readf32(b, c + 12)
			),
				c + 16
		end
	end
	if schema_type == "numberrange" then
		return function(b: buffer, c: number)
			return NumberRange.new(buffer.readf32(b, c), buffer.readf32(b, c + 4)), c + 8
		end
	end
	if schema_type == "ray" then
		return function(b: buffer, c: number)
			return Ray.new(
				Vector3.new(buffer.readf32(b, c), buffer.readf32(b, c + 4), buffer.readf32(b, c + 8)),
				Vector3.new(buffer.readf32(b, c + 12), buffer.readf32(b, c + 16), buffer.readf32(b, c + 20))
			),
				c + 24
		end
	end
	if schema_type == "colorsequence" then
		return function(b: buffer, c: number)
			local n = buffer.readu8(b, c)
			c += 1
			local kps = table.create(n)
			for i = 1, n do
				local t = buffer.readf32(b, c)
				kps[i] = ColorSequenceKeypoint.new(
					t,
					Color3.fromRGB(buffer.readu8(b, c + 4), buffer.readu8(b, c + 5), buffer.readu8(b, c + 6))
				)
				c += 7
			end
			return ColorSequence.new(kps), c
		end
	end
	if schema_type == "numbersequence" then
		return function(b: buffer, c: number)
			local n = buffer.readu8(b, c)
			c += 1
			local kps = table.create(n)
			for i = 1, n do
				kps[i] =
					NumberSequenceKeypoint.new(buffer.readf32(b, c), buffer.readf32(b, c + 4), buffer.readf32(b, c + 8))
				c += 12
			end
			return NumberSequence.new(kps), c
		end
	end
	if schema_type == "brickcolor" then
		return function(b: buffer, c: number)
			return BrickColor.new(buffer.readu16(b, c)), c + 2
		end
	end
	if schema_type == "buffer" then
		return function(b: buffer, c: number)
			local len
			len, c = readVarUInt(b, c)
			local out = buffer.create(len)
			buffer.copy(out, 0, b, c, len)
			return out, c + len
		end
	end
	if schema_type == "vector3int16" then
		return function(b: buffer, c: number)
			return Vector3int16.new(buffer.readi16(b, c), buffer.readi16(b, c + 2), buffer.readi16(b, c + 4)), c + 6
		end
	end
	if schema_type == "vector2int16" then
		return function(b: buffer, c: number)
			return Vector2int16.new(buffer.readi16(b, c), buffer.readi16(b, c + 2)), c + 4
		end
	end
	if schema_type == "tweeninfo" then
		return function(b: buffer, c: number)
			return TweenInfo.new(
				buffer.readf32(b, c),
				Enum.EasingStyle:FromValue(buffer.readu8(b, c + 4)),
				Enum.EasingDirection:FromValue(buffer.readu8(b, c + 5)),
				buffer.readi32(b, c + 6),
				buffer.readu8(b, c + 10) ~= 0,
				buffer.readf32(b, c + 11)
			),
				c + 15
		end
	end
	if schema_type == "physicalproperties" then
		return function(b: buffer, c: number)
			return PhysicalProperties.new(
				buffer.readf32(b, c),
				buffer.readf32(b, c + 4),
				buffer.readf32(b, c + 8),
				buffer.readf32(b, c + 12),
				buffer.readf32(b, c + 16)
			),
				c + 20
		end
	end
	if schema_type == "font" then
		return function(b: buffer, c: number)
			local familyLen
			familyLen, c = readVarUInt(b, c)
			local family = buffer.readstring(b, c, familyLen)
			c += familyLen
			return Font.new(
				family,
				Enum.FontWeight:FromValue(buffer.readu16(b, c)),
				Enum.FontStyle:FromValue(buffer.readu8(b, c + 2))
			),
				c + 3
		end
	end
	if schema_type == "datetime" then
		return function(b: buffer, c: number)
			return DateTime.fromUnixTimestampMillis(buffer.readf64(b, c)), c + 8
		end
	end
	if schema_type == "instance" then
		return function(b: buffer, c: number, refs: { any }?)
			local idx
			idx, c = readVarUInt(b, c)
			return refs and refs[idx] or nil, c
		end
	end

	if schema_type == "struct" then
		local fields = {}
		local optionalIndices = {}

		for idx, field in ipairs(s.fields) do
			local isOpt = field.schema.type == "optional"
			table.insert(fields, {
				key = field.key,
				reader = compileReader(isOpt and field.schema.item or field.schema),
				optional = isOpt,
			})
			if isOpt then
				table.insert(optionalIndices, idx)
			end
		end

		local numOpt = #optionalIndices

		if numOpt == 0 then
			return function(b: buffer, c: number, refs: { any }?)
				local obj = {}
				for _, f in fields do
					obj[f.key], c = f.reader(b, c, refs)
				end
				return obj, c
			end
		end

		local maskBytes = math.ceil(numOpt / 8)

		return function(b: buffer, c: number, refs: { any }?)
			local present = {}
			for i = 0, maskBytes - 1 do
				local byte = buffer.readu8(b, c + i)
				for bit = 0, 7 do
					local optIdx = i * 8 + bit + 1
					if optIdx > numOpt then
						break
					end
					present[optIdx] = bit32.band(byte, bit32.lshift(1, bit)) ~= 0
				end
			end
			c += maskBytes

			local obj = {}
			local optIdx = 0
			for _, f in fields do
				if f.optional then
					optIdx += 1
					if present[optIdx] then
						obj[f.key], c = f.reader(b, c, refs)
					end
				else
					obj[f.key], c = f.reader(b, c, refs)
				end
			end

			return obj, c
		end
	end

	if schema_type == "array" then
		local itemSchema = s.item

		if itemSchema.type == "boolean" then
			return function(b: buffer, c: number, _: { any }?)
				local len
				len, c = readVarUInt(b, c)
				local arr = table.create(len)
				local numBytes = math.ceil(len / 8)
				for i = 0, numBytes - 1 do
					local byte = buffer.readu8(b, c + i)
					for bit = 0, 7 do
						local idx = i * 8 + bit + 1
						if idx > len then
							break
						end
						arr[idx] = bit32.band(byte, bit32.lshift(1, bit)) ~= 0
					end
				end
				return arr, c + numBytes
			end
		end

		local itemReader = compileReader(itemSchema)
		return function(b: buffer, c: number, refs: { any }?)
			local len
			len, c = readVarUInt(b, c)
			local arr = table.create(len)
			for i = 1, len do
				arr[i], c = itemReader(b, c, refs)
			end
			return arr, c
		end
	end

	if schema_type == "map" then
		local keyReader = compileReader(s.key)
		local valReader = compileReader(s.value)
		return function(b: buffer, c: number, refs: { any }?)
			local count
			count, c = readVarUInt(b, c)
			local map = {}
			for _ = 1, count do
				local k, val
				k, c = keyReader(b, c, refs)
				val, c = valReader(b, c, refs)
				map[k] = val
			end
			return map, c
		end
	end

	if schema_type == "optional" then
		local itemReader = compileReader(s.item)
		return function(b: buffer, c: number, refs: { any }?)
			local exists = buffer.readu8(b, c) ~= 0
			c += 1
			if exists then
				return itemReader(b, c, refs)
			else
				return nil, c
			end
		end
	end

	return function(_: buffer, c: number)
		return nil, c
	end
end

local packerCache = setmetatable({}, { __mode = "k" })
local readerCache = setmetatable({}, { __mode = "k" })

local function packStrict(w: Writer, s: SchemaType, v: any)
	local packer = packerCache[s]
	if not packer then
		packer = compilePacker(s)
		packerCache[s] = packer
	end
	packer(w, v)
end

local function readStrict(buf: buffer, cursor: number, s: SchemaType, refs: { any }?): (any, number)
	local reader = readerCache[s]
	if not reader then
		reader = compileReader(s)
		readerCache[s] = reader
	end
	return reader(buf, cursor, refs)
end

local function writeEvents(w: Writer, events: { { any } }, schemas: { [number]: SchemaType })
	local count = #events
	wVarUInt(w, count)
	for _, event in events do
		local id = event[1]
		local args = event[2]
		wByte(w, id)
		local schema = schemas[id]
		if schema then
			packStrict(w, schema, args[1])
		else
			packValue(w, args)
		end
	end
end

local function readEvents(buf: buffer, refs: { any }?, schemas: { [number]: SchemaType }): { { any } }
	local pos, count = 0, 0
	count, pos = readVarUInt(buf, pos)
	local events = table.create(count)
	for i = 1, count do
		local id: number = buffer.readu8(buf, pos)
		pos += 1
		local args: any
		local schema = schemas[id]
		if schema then
			local val
			val, pos = readStrict(buf, pos, schema, refs)
			args = { val }
		else
			args, pos = unpackValue(buf, pos, refs)
		end
		events[i] = { id, args }
	end
	return events
end

local function writeRepl(w: Writer, content: { [string]: number }, count: number, schema: SchemaType)
	wVarUInt(w, count)
	for name, id in content do
		wByte(w, id)
		if schema then
			packStrict(w, schema, name)
		else
			packValue(w, name)
		end
	end
end

local function readRepl(buf: buffer, schema: SchemaType): { { any } }
	local pos, count = 0, 0
	count, pos = readVarUInt(buf, pos)
	local events = table.create(count)
	for i = 1, count do
		local id: number = buffer.readu8(buf, pos)
		pos += 1
		local args: any
		if schema then
			local val
			val, pos = readStrict(buf, pos, schema)
			args = val
		else
			args, pos = unpackValue(buf, pos)
		end
		events[i] = { id, args }
	end
	return events
end

local BufferSerdes = {}

BufferSerdes.Schema = Schema

BufferSerdes.writeRepl = writeRepl
BufferSerdes.readRepl = readRepl

BufferSerdes.writeEvents = writeEvents
BufferSerdes.readEvents = readEvents

BufferSerdes.compilePacker = compilePacker
BufferSerdes.compileReader = compileReader

BufferSerdes.packStrict = packStrict
BufferSerdes.readStrict = readStrict

function BufferSerdes.write(data: any): (buffer, { any }?)
	local w = createWriter()
	packValue(w, data)
	return buildWithRefs(w)
end

function BufferSerdes.read(buf: buffer, refs: { any }?): any
	return (unpackValue(buf, 0, refs))
end

function BufferSerdes.readAll(buf: buffer, refs: { any }?): { any }
	local bufLen = buffer.len(buf)
	local pos = 0
	local results = {}
	while pos < bufLen do
		local value
		value, pos = unpackValue(buf, pos, refs)
		table.insert(results, value)
	end
	return results
end

BufferSerdes.createWriter = createWriter
BufferSerdes.pack = packValue
BufferSerdes.build = build
BufferSerdes.buildWithRefs = buildWithRefs
BufferSerdes.reset = reset

BufferSerdes.readTagged = unpackValue
BufferSerdes.packTagged = packValue
BufferSerdes.unpack = unpackValue

-- for internal test
BufferSerdes.writeVarUInt = writeVarUInt
BufferSerdes.readVarUInt = readVarUInt
BufferSerdes.varUIntSize = varUIntSize

-- for custom datatype usage
BufferSerdes.ensureSpace = ensureSpace
BufferSerdes.writeu8 = wByte
BufferSerdes.writeu16 = wU16
BufferSerdes.writeu32 = wU32
BufferSerdes.writei16 = wI16
BufferSerdes.writei32 = wI32
BufferSerdes.writef16 = wF16
BufferSerdes.writef32 = wF32
BufferSerdes.writef64 = wF64
BufferSerdes.writestring = wString

return BufferSerdes :: typeof(BufferSerdes)
