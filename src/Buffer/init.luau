--!native
--!optimize 2
--@EternityDev
export type Writer = {
	buf: buffer,
	cursor: number,
	capacity: number,
	refs: {any},
}

local DEFAULT_CAPACITY: number = 64

-- 0x00-0x7F: + fixint (0-127) - single byte
-- 0x80-0x9F: - fixint (-32 to -1) - single byte
local T_NIL = 0xA0
local T_FALSE = 0xA1
local T_TRUE = 0xA2
local T_U8 = 0xA3
local T_U16 = 0xA4
local T_U32 = 0xA5
local T_I8 = 0xA6
local T_I16 = 0xA7
local T_I32 = 0xA8
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

-- Typed arrays (homogeneous, no per-element tags)
local T_TYPED_ARR = 0xDB
local T_BUFFER = 0xDC

local T_VEC3 = 0xE0 -- f32 precision (12 bytes)
local T_VEC3_F16 = 0xE1 -- f16 precision (6 bytes)
local T_VEC2 = 0xE2 -- f32 precision (8 bytes)
local T_VEC2_F16 = 0xE3 -- f16 precision (4 bytes)
local T_CFRAME = 0xE4 -- f32 pos + f32 orient (24 bytes)
local T_CFRAME_F16 = 0xE5 -- f16 pos + f16 orient (12 bytes)
local T_COLOR3 = 0xE6 -- RGB bytes (3 bytes)
local T_COLOR3_F = 0xE7 -- RGB floats (12 bytes)
local T_BRICKCOLOR = 0xE8
local T_INSTANCE = 0xE9
local T_ENUMITEM = 0xEA
local T_ENUM = 0xEB
local T_UDIM2 = 0xEC
local T_UDIM = 0xED
local T_RECT = 0xEE
local T_NUMBERRANGE = 0xEF
local T_RAY = 0xF0
local T_COLSEQ = 0xF2 -- ColorSequence
local T_NUMSEQ = 0xF3 -- NumberSequence

local TYPED_READERS = {
	[1] = function(b, o) return buffer.readu8(b, o), o + 1 end,
	[2] = function(b, o) return buffer.readi8(b, o), o + 1 end,
	[3] = function(b, o) return buffer.readu16(b, o), o + 2 end,
	[4] = function(b, o) return buffer.readi16(b, o), o + 2 end,
	[5] = function(b, o) return buffer.readu32(b, o), o + 4 end,
	[6] = function(b, o) return buffer.readi32(b, o), o + 4 end,
	[7] = function(b, o) return buffer.readf32(b, o), o + 4 end,
	[8] = function(b, o) return buffer.readf64(b, o), o + 8 end,
}

local F16_MANTISSA_BITS = 1024
local F16_DENORM do
	F16_DENORM = table.create(1024)
	F16_DENORM[1] = 0
	for m = 1, 1023 do
		F16_DENORM[m + 1] = math.ldexp(m / F16_MANTISSA_BITS, -14)
	end
end
local F16_EXP2 do
	F16_EXP2 = table.create(31)
	for e = 1, 30 do
		F16_EXP2[e] = math.ldexp(1, e - 15)
	end
end
local F16_NORM_MANTISSA do
	F16_NORM_MANTISSA = table.create(1024)
	for m = 0, 1023 do
		F16_NORM_MANTISSA[m + 1] = 1 + m / F16_MANTISSA_BITS
	end
end
local F32TOF16_SUBNORM_POW2 = { 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }

local function f32ToF16(value: number): number
	if value ~= value then return 0x7E00 end
	if value == math.huge then return 0x7C00 end
	if value == -math.huge then return 0xFC00 end
	if value == 0 then return 0 end

	local sign = 0
	if value < 0 then
		sign = 0x8000
		value = -value
	end

	local mantissa, exponent = math.frexp(value)
	exponent += 14

	if exponent <= 0 then
		if exponent < -10 then return sign end
		local scale = F32TOF16_SUBNORM_POW2[10 + exponent] or bit32.lshift(1, 10 + exponent)
		mantissa = math.floor(mantissa * scale + 0.5)
		return bit32.bor(sign, mantissa)
	elseif exponent >= 31 then
		return bit32.bor(sign, 0x7C00)
	end

	mantissa = math.floor((mantissa * 2 - 1) * F16_MANTISSA_BITS + 0.5)
	if mantissa == F16_MANTISSA_BITS then
		mantissa = 0
		exponent += 1
		if exponent >= 31 then return bit32.bor(sign, 0x7C00) end
	end
	return bit32.bor(sign, bit32.lshift(exponent, 10), mantissa)
end

local function f16ToF32(bits: number): number
	local sign = bit32.band(bits, 0x8000)
	local exponent = bit32.band(bit32.rshift(bits, 10), 0x1F)
	local mantissa = bit32.band(bits, 0x03FF)

	local value: number
	if exponent == 0 then
		value = mantissa == 0 and 0 or (F16_DENORM[mantissa + 1] or math.ldexp(mantissa / 1024, -14))
	elseif exponent == 31 then
		value = mantissa == 0 and math.huge or 0/0
	else
		value = F16_NORM_MANTISSA[mantissa + 1] * F16_EXP2[exponent]
	end

	return sign ~= 0 and -value or value
end

local function varUIntSize(value: number): number
	if value < 0x80 then return 1 end
	if value < 0x4000 then return 2 end
	if value < 0x200000 then return 3 end
	if value < 0x10000000 then return 4 end
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
	if needed <= w.capacity then return end

	local newCap = w.capacity
	while newCap < needed do
		newCap *= 2
	end

	local newBuf = buffer.create(newCap)
	buffer.copy(newBuf, 0, w.buf, 0, w.cursor)
	w.buf = newBuf
	w.capacity = newCap
end

local function wByte(w: Writer, v: number)
	ensureSpace(w, 1)
	buffer.writeu8(w.buf, w.cursor, v)
	w.cursor += 1
end

local function wU16(w: Writer, v: number)
	ensureSpace(w, 2)
	buffer.writei16(w.buf, w.cursor, v)
	w.cursor += 2
end

local function wI16(w: Writer, v: number)
	ensureSpace(w, 2)
	buffer.writei16(w.buf, w.cursor, v)
	w.cursor += 2
end

local function wU32(w: Writer, v: number)
	ensureSpace(w, 4)
	buffer.writei32(w.buf, w.cursor, v)
	w.cursor += 4
end

local function wI32(w: Writer, v: number)
	ensureSpace(w, 4)
	buffer.writei32(w.buf, w.cursor, v)
	w.cursor += 4
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

local function wF16(w: Writer, v: number)
	ensureSpace(w, 2)
	buffer.writei16(w.buf, w.cursor, f32ToF16(v))
	w.cursor += 2
end

local function wVarUInt(w: Writer, v: number)
	ensureSpace(w, varUIntSize(v))
	w.cursor = writeVarUInt(w.buf, w.cursor, v)
end

local function wString(w: Writer, s: string)
	local n = #s
	ensureSpace(w, n)
	buffer.writestring(w.buf, w.cursor, s)
	w.cursor += n
end

local packValue: (w: Writer, v: any) -> ()

local function packNumber(w: Writer, n: number)
	if n ~= n then
		wByte(w, T_F64)
		wF64(w, n)
		return
	end

	local isInt = n == math.floor(n)

	if isInt then
		-- + fixint: 0-127 in single byte
		if n >= 0 and n <= 127 then
			wByte(w, n)
			return
		end

		-- - fixint: -32 to -1 in single byte
		if n >= -32 and n < 0 then
			wByte(w, bit32.bor(0x80, n + 32))
			return
		end

		-- larger ints
		if n >= 0 then
			if n <= 255 then
				wByte(w, T_U8)
				wByte(w, n)
			elseif n <= 65535 then
				wByte(w, T_U16)
				wU16(w, n)
			elseif n <= 4294967295 then
				wByte(w, T_U32)
				wU32(w, n)
			else
				wByte(w, T_F64)
				wF64(w, n)
			end
		else
			if n >= -128 then
				wByte(w, T_I8)
				ensureSpace(w, 1)
				buffer.writei8(w.buf, w.cursor, n)
				w.cursor += 1
			elseif n >= -32768 then
				wByte(w, T_I16)
				wI16(w, n)
			elseif n >= -2147483648 then
				wByte(w, T_I32)
				wI32(w, n)
			else
				wByte(w, T_F64)
				wF64(w, n)
			end
		end
	else
		-- float: try f32 first
		local testBuf = buffer.create(4)
		buffer.writef32(testBuf, 0, n)
		local f32Val = buffer.readf32(testBuf, 0)

		if f32Val == n or math.abs(n - f32Val) < math.abs(n) * 1e-6 then
			wByte(w, T_F32)
			wF32(w, n)
		else
			wByte(w, T_F64)
			wF64(w, n)
		end
	end
end

local function packString(w: Writer, s: string)
	local n = #s

	if n <= 15 then
		wByte(w, T_STR_BASE + n)
	elseif n <= 255 then
		wByte(w, T_STR8)
		wByte(w, n)
	elseif n <= 65535 then
		wByte(w, T_STR16)
		wU16(w, n)
	else
		wByte(w, T_STRVAR)
		wVarUInt(w, n)
	end
	wString(w, s)
end

-- is the table a homogeneous number array
local function analyzeNumberArray(t: {any}): (boolean, string?, number)
	local count = #t
	if count == 0 then return false, nil, 0 end

	local minVal, maxVal = math.huge, -math.huge
	local allInt = true

	for i = 1, count do
		local v = t[i]
		if type(v) ~= "number" then return false, nil, count end
		if v ~= math.floor(v) then allInt = false end
		if v < minVal then minVal = v end
		if v > maxVal then maxVal = v end
	end

	if not allInt then
		return true, "f32", count
	elseif minVal >= 0 and maxVal <= 255 then
		return true, "u8", count
	elseif minVal >= -128 and maxVal <= 127 then
		return true, "i8", count
	elseif minVal >= 0 and maxVal <= 65535 then
		return true, "u16", count
	elseif minVal >= -32768 and maxVal <= 32767 then
		return true, "i16", count
	elseif minVal >= 0 and maxVal <= 4294967295 then
		return true, "u32", count
	elseif minVal >= -2147483648 and maxVal <= 2147483647 then
		return true, "i32", count
	end
	return true, "f64", count
end

local TYPED_CODES = { u8 = 1, i8 = 2, u16 = 3, i16 = 4, u32 = 5, i32 = 6, f32 = 7, f64 = 8 }
local TYPED_SIZES = { u8 = 1, i8 = 1, u16 = 2, i16 = 2, u32 = 4, i32 = 4, f32 = 4, f64 = 8 }
local TYPED_WRITERS = {
	u8 = buffer.writeu8, i8 = buffer.writei8, u16 = buffer.writeu16, i16 = buffer.writei16,
	u32 = buffer.writeu32, i32 = buffer.writei32, f32 = buffer.writef32, f64 = buffer.writef64,
}

local function packTable(w: Writer, t: {[any]: any})
	local count = 0
	local maxIdx = 0
	local isArray = true

	for k in t do
		count += 1
		if type(k) == "number" and k > 0 and k == math.floor(k) then
			if k > maxIdx then maxIdx = k end
		else
			isArray = false
		end
	end

	isArray = isArray and maxIdx == count

	if isArray then
		-- typed array optimization (worth it for 4+ elements)
		local isHomogeneous, dtype, arrCount = analyzeNumberArray(t)
		if isHomogeneous and dtype and arrCount >= 4 then
			local code = TYPED_CODES[dtype]
			local size = TYPED_SIZES[dtype]
			local writer = TYPED_WRITERS[dtype]

			wByte(w, T_TYPED_ARR)
			wByte(w, code)
			wVarUInt(w, arrCount)
			ensureSpace(w, arrCount * size)

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
			wByte(w, T_ARR8)
			wByte(w, count)
		elseif count <= 65535 then
			wByte(w, T_ARR16)
			wU16(w, count)
		else
			wByte(w, T_ARRVAR)
			wVarUInt(w, count)
		end

		for i = 1, count do
			packValue(w, t[i])
		end
	else
		-- map
		if count <= 7 then
			wByte(w, T_MAP_BASE + count)
		elseif count <= 255 then
			wByte(w, T_MAP8)
			wByte(w, count)
		elseif count <= 65535 then
			wByte(w, T_MAP16)
			wU16(w, count)
		else
			wByte(w, T_MAPVAR)
			wVarUInt(w, count)
		end

		for k, v in t do
			packValue(w, k)
			packValue(w, v)
		end
	end
end

local function packVector3(w: Writer, v: Vector3)
	local x, y, z = v.X, v.Y, v.Z
	local maxComp = math.max(math.abs(x), math.abs(y), math.abs(z))

	if maxComp < 65000 and maxComp > 0.00006 then
		wByte(w, T_VEC3_F16)
		wF16(w, x)
		wF16(w, y)
		wF16(w, z)
	else
		wByte(w, T_VEC3)
		wF32(w, x)
		wF32(w, y)
		wF32(w, z)
	end
end

local function packVector2(w: Writer, v: Vector2)
	local x, y = v.X, v.Y
	local maxComp = math.max(math.abs(x), math.abs(y))

	if maxComp < 65000 and maxComp > 0.00006 then
		wByte(w, T_VEC2_F16)
		wF16(w, x)
		wF16(w, y)
	else
		wByte(w, T_VEC2)
		wF32(w, x)
		wF32(w, y)
	end
end

local function packCFrame(w: Writer, cf: CFrame)
	local pos = cf.Position
	local rx, ry, rz = cf:ToOrientation()

	local px, py, pz = pos.X, pos.Y, pos.Z
	local maxPos = math.max(math.abs(px), math.abs(py), math.abs(pz))

	-- f16
	if maxPos < 65000 and (maxPos > 0.00006 or maxPos == 0) then
		wByte(w, T_CFRAME_F16)
		wF16(w, px)
		wF16(w, py)
		wF16(w, pz)
		wF16(w, rx)
		wF16(w, ry)
		wF16(w, rz)
	else
		wByte(w, T_CFRAME)
		wF32(w, px)
		wF32(w, py)
		wF32(w, pz)
		wF32(w, rx)
		wF32(w, ry)
		wF32(w, rz)
	end
end

local function packColor3(w: Writer, c: Color3)
	local r, g, b = c.R, c.G, c.B

	if r > 1 or g > 1 or b > 1 then
		wByte(w, T_COLOR3_F)
		wF32(w, r)
		wF32(w, g)
		wF32(w, b)
	else
		wByte(w, T_COLOR3)
		wByte(w, math.clamp(math.round(r * 255), 0, 255))
		wByte(w, math.clamp(math.round(g * 255), 0, 255))
		wByte(w, math.clamp(math.round(b * 255), 0, 255))
	end
end

packValue = function(w: Writer, v: any): ()
	local t: string = typeof(v)

	if t == "nil" then
		wByte(w, T_NIL)
	elseif t == "boolean" then
		wByte(w, v and T_TRUE or T_FALSE)
	elseif t == "number" then
		packNumber(w, v)
	elseif t == "string" then
		packString(w, v)
	elseif t == "table" then
		packTable(w, v)
	elseif t == "Vector3" then
		packVector3(w, v)
	elseif t == "Vector2" then
		packVector2(w, v)
	elseif t == "CFrame" then
		packCFrame(w, v)
	elseif t == "Color3" then
		packColor3(w, v)
	elseif t == "Instance" then
		wByte(w, T_INSTANCE)
		table.insert(w.refs, v)
		wVarUInt(w, #w.refs)
	elseif t == "EnumItem" then
		wByte(w, T_ENUMITEM)
		local enumName = `{v.EnumType}`
		wVarUInt(w, #enumName)
		wString(w, enumName)
		wU16(w, v.Value)
	elseif t == "BrickColor" then
		wByte(w, T_BRICKCOLOR)
		wU16(w, v.Number)
	elseif t == "Enum" then
		wByte(w, T_ENUM)
		local name = v.Name
		wVarUInt(w, #name)
		wString(w, name)
	elseif t == "UDim2" then
		local X, Y = v.X, v.Y
		wByte(w, T_UDIM2)
		wF32(w, X.Scale)
		wI32(w, X.Offset)
		wF32(w, Y.Scale)
		wI32(w, Y.Offset)
	elseif t == "UDim" then
		wByte(w, T_UDIM)
		wF32(w, v.Scale)
		wI32(w, v.Offset)
	elseif t == "Rect" then
		local Min, Max = v.Min, v.Max
		wByte(w, T_RECT)
		wF32(w, Min.X)
		wF32(w, Min.Y)
		wF32(w, Max.X)
		wF32(w, Max.Y)
	elseif t == "NumberRange" then
		wByte(w, T_NUMBERRANGE)
		wF32(w, v.Min)
		wF32(w, v.Max)
	elseif t == "Ray" then
		local Origin, Direction = v.Origin, v.Direction
		wByte(w, T_RAY)
		wF32(w, Origin.X)
		wF32(w, Origin.Y)
		wF32(w, Origin.Z)
		wF32(w, Direction.X)
		wF32(w, Direction.Y)
		wF32(w, Direction.Z)
	elseif t == "ColorSequence" then
		local keypoints = v.Keypoints
		wByte(w, T_COLSEQ)
		wByte(w, #keypoints)
		for _, kp in keypoints do
			wF32(w, kp.Time)
			local c = kp.Value
			wByte(w, math.clamp(math.round(c.R * 255), 0, 255))
			wByte(w, math.clamp(math.round(c.G * 255), 0, 255))
			wByte(w, math.clamp(math.round(c.B * 255), 0, 255))
		end
	elseif t == "NumberSequence" then
		local keypoints = v.Keypoints
		wByte(w, T_NUMSEQ)
		wByte(w, #keypoints)
		for _, kp in keypoints do
			wF32(w, kp.Time)
			wF32(w, kp.Value)
			wF32(w, kp.Envelope)
		end
	elseif t == "buffer" then
		wByte(w, T_BUFFER)
		local len = buffer.len(v)
		wVarUInt(w, len)
		ensureSpace(w, len)
		buffer.copy(w.buf, w.cursor, v, 0, len)
		w.cursor += len
	else
		error(`Unsupported type: {t}`)
	end
end

local function readF16(b: buffer, o: number): number
	return f16ToF32(buffer.readu16(b, o))
end

local unpackValue: (buf: buffer, pos: number, refs: {any}?) -> (any, number)

unpackValue = function(buf: buffer, pos: number, refs: {any}?): (any, number)
	local t = buffer.readu8(buf, pos)
	pos += 1

	-- + fixint (0-127)
	if t <= 0x7F then
		return t, pos
	end

	-- - fixint (-32 to -1)
	if t >= 0x80 and t <= 0x9F then
		return t - 0x80 - 32, pos
	end

	if t == T_NIL then return nil, pos end
	if t == T_FALSE then return false, pos end
	if t == T_TRUE then return true, pos end

	if t == T_U8 then return buffer.readu8(buf, pos), pos + 1 end
	if t == T_U16 then return buffer.readu16(buf, pos), pos + 2 end
	if t == T_U32 then return buffer.readu32(buf, pos), pos + 4 end
	if t == T_I8 then return buffer.readi8(buf, pos), pos + 1 end
	if t == T_I16 then return buffer.readi16(buf, pos), pos + 2 end
	if t == T_I32 then return buffer.readi32(buf, pos), pos + 4 end
	if t == T_F32 then return buffer.readf32(buf, pos), pos + 4 end
	if t == T_F64 then return buffer.readf64(buf, pos), pos + 8 end

	-- inline str len (0-15)
	if t >= T_STR_BASE and t <= T_STR_BASE + 15 then
		local n = t - T_STR_BASE
		return buffer.readstring(buf, pos, n), pos + n
	end

	if t == T_STR8 then
		local n = buffer.readu8(buf, pos)
		return buffer.readstring(buf, pos + 1, n), pos + 1 + n
	end
	if t == T_STR16 then
		local n = buffer.readu16(buf, pos)
		return buffer.readstring(buf, pos + 2, n), pos + 2 + n
	end
	if t == T_STRVAR then
		local n; n, pos = readVarUInt(buf, pos)
		return buffer.readstring(buf, pos, n), pos + n
	end

	-- inline array len (0-7)
	if t >= T_ARR_BASE and t <= T_ARR_BASE + 7 then
		local count = t - T_ARR_BASE
		local arr = table.create(count)
		for i = 1, count do
			arr[i], pos = unpackValue(buf, pos, refs)
		end
		return arr, pos
	end

	if t == T_ARR8 then
		local count = buffer.readu8(buf, pos); pos += 1
		local arr = table.create(count)
		for i = 1, count do
			arr[i], pos = unpackValue(buf, pos, refs)
		end
		return arr, pos
	end
	if t == T_ARR16 then
		local count = buffer.readu16(buf, pos); pos += 2
		local arr = table.create(count)
		for i = 1, count do
			arr[i], pos = unpackValue(buf, pos, refs)
		end
		return arr, pos
	end
	if t == T_ARRVAR then
		local count; count, pos = readVarUInt(buf, pos)
		local arr = table.create(count)
		for i = 1, count do
			arr[i], pos = unpackValue(buf, pos, refs)
		end
		return arr, pos
	end

	-- inline map len (0-7)
	if t >= T_MAP_BASE and t <= T_MAP_BASE + 7 then
		local count = t - T_MAP_BASE
		local map = {}
		for _ = 1, count do
			local k, v
			k, pos = unpackValue(buf, pos, refs)
			v, pos = unpackValue(buf, pos, refs)
			map[k] = v
		end
		return map, pos
	end

	if t == T_MAP8 then
		local count = buffer.readu8(buf, pos); pos += 1
		local map = {}
		for _ = 1, count do
			local k, v
			k, pos = unpackValue(buf, pos, refs)
			v, pos = unpackValue(buf, pos, refs)
			map[k] = v
		end
		return map, pos
	end
	if t == T_MAP16 then
		local count = buffer.readu16(buf, pos); pos += 2
		local map = {}
		for _ = 1, count do
			local k, v
			k, pos = unpackValue(buf, pos, refs)
			v, pos = unpackValue(buf, pos, refs)
			map[k] = v
		end
		return map, pos
	end
	if t == T_MAPVAR then
		local count; count, pos = readVarUInt(buf, pos)
		local map = {}
		for _ = 1, count do
			local k, v
			k, pos = unpackValue(buf, pos, refs)
			v, pos = unpackValue(buf, pos, refs)
			map[k] = v
		end
		return map, pos
	end

	-- typed array
	if t == T_TYPED_ARR then
		local subtype = buffer.readu8(buf, pos); pos += 1
		local count; count, pos = readVarUInt(buf, pos)
		local reader = TYPED_READERS[subtype]
		local arr = table.create(count)
		for i = 1, count do
			arr[i], pos = reader(buf, pos)
		end
		return arr, pos
	end

	-- Vector3
	if t == T_VEC3 then
		local x = buffer.readf32(buf, pos)
		local y = buffer.readf32(buf, pos + 4)
		local z = buffer.readf32(buf, pos + 8)
		return Vector3.new(x, y, z), pos + 12
	end
	if t == T_VEC3_F16 then
		local x = readF16(buf, pos)
		local y = readF16(buf, pos + 2)
		local z = readF16(buf, pos + 4)
		return Vector3.new(x, y, z), pos + 6
	end

	-- Vector2
	if t == T_VEC2 then
		local x = buffer.readf32(buf, pos)
		local y = buffer.readf32(buf, pos + 4)
		return Vector2.new(x, y), pos + 8
	end
	if t == T_VEC2_F16 then
		local x = readF16(buf, pos)
		local y = readF16(buf, pos + 2)
		return Vector2.new(x, y), pos + 4
	end

	-- CFrame
	if t == T_CFRAME then
		local px = buffer.readf32(buf, pos)
		local py = buffer.readf32(buf, pos + 4)
		local pz = buffer.readf32(buf, pos + 8)
		local rx = buffer.readf32(buf, pos + 12)
		local ry = buffer.readf32(buf, pos + 16)
		local rz = buffer.readf32(buf, pos + 20)
		return CFrame.new(px, py, pz) * CFrame.fromOrientation(rx, ry, rz), pos + 24
	end
	if t == T_CFRAME_F16 then
		local px = readF16(buf, pos)
		local py = readF16(buf, pos + 2)
		local pz = readF16(buf, pos + 4)
		local rx = readF16(buf, pos + 6)
		local ry = readF16(buf, pos + 8)
		local rz = readF16(buf, pos + 10)
		return CFrame.new(px, py, pz) * CFrame.fromOrientation(rx, ry, rz), pos + 12
	end

	-- Color3
	if t == T_COLOR3 then
		local r = buffer.readu8(buf, pos)
		local g = buffer.readu8(buf, pos + 1)
		local b = buffer.readu8(buf, pos + 2)
		return Color3.fromRGB(r, g, b), pos + 3
	end
	if t == T_COLOR3_F then
		local r = buffer.readf32(buf, pos)
		local g = buffer.readf32(buf, pos + 4)
		local b = buffer.readf32(buf, pos + 8)
		return Color3.new(r, g, b), pos + 12
	end

	if t == T_BRICKCOLOR then
		return BrickColor.new(buffer.readu16(buf, pos)), pos + 2
	end

	if t == T_INSTANCE then
		local idx; idx, pos = readVarUInt(buf, pos)
		return refs and refs[idx] or nil, pos
	end

	if t == T_ENUMITEM then
		local nameLen; nameLen, pos = readVarUInt(buf, pos)
		local enumName = buffer.readstring(buf, pos, nameLen)
		pos += nameLen
		local val = buffer.readu16(buf, pos)
		return (Enum :: any)[enumName]:FromValue(val), pos + 2
	end

	if t == T_ENUM then
		local nameLen; nameLen, pos = readVarUInt(buf, pos)
		local enumName = buffer.readstring(buf, pos, nameLen)
		return (Enum :: any)[enumName], pos + nameLen
	end

	if t == T_UDIM2 then
		local xs = buffer.readf32(buf, pos)
		local xo = buffer.readi32(buf, pos + 4)
		local ys = buffer.readf32(buf, pos + 8)
		local yo = buffer.readi32(buf, pos + 12)
		return UDim2.new(xs, xo, ys, yo), pos + 16
	end

	if t == T_UDIM then
		local s = buffer.readf32(buf, pos)
		local o = buffer.readi32(buf, pos + 4)
		return UDim.new(s, o), pos + 8
	end

	if t == T_RECT then
		return Rect.new(
			buffer.readf32(buf, pos), buffer.readf32(buf, pos + 4),
			buffer.readf32(buf, pos + 8), buffer.readf32(buf, pos + 12)
		), pos + 16
	end

	if t == T_NUMBERRANGE then
		return NumberRange.new(buffer.readf32(buf, pos), buffer.readf32(buf, pos + 4)), pos + 8
	end

	if t == T_RAY then
		return Ray.new(
			Vector3.new(buffer.readf32(buf, pos), buffer.readf32(buf, pos + 4), buffer.readf32(buf, pos + 8)),
			Vector3.new(buffer.readf32(buf, pos + 12), buffer.readf32(buf, pos + 16), buffer.readf32(buf, pos + 20))
		), pos + 24
	end

	if t == T_COLSEQ then
		local count = buffer.readu8(buf, pos); pos += 1
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

	if t == T_NUMSEQ then
		local count = buffer.readu8(buf, pos); pos += 1
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

	if t == T_BUFFER then
		local len; len, pos = readVarUInt(buf, pos)
		local b = buffer.create(len)
		buffer.copy(b, 0, buf, pos, len)
		return b, pos + len
	end

	error(`(serdes) unknown type: {t}`)
end

local function build(w: Writer): buffer
	local result = buffer.create(w.cursor)
	buffer.copy(result, 0, w.buf, 0, w.cursor)
	return result
end

local function buildWithRefs(w: Writer): (buffer, {any}?)
	local result = buffer.create(w.cursor)
	buffer.copy(result, 0, w.buf, 0, w.cursor)
	return result, #w.refs > 0 and table.clone(w.refs) or nil
end

local function reset(w: Writer)
	w.cursor = 0
	table.clear(w.refs)
end

local Schema = {}
export type SchemaType = { type: string, [any]: any }

Schema.u8 = { type = "u8" }
Schema.i8 = { type = "i8" }
Schema.u16 = { type = "u16" }
Schema.i16 = { type = "i16" }
Schema.u32 = { type = "u32" }
Schema.i32 = { type = "i32" }
Schema.f32 = { type = "f32" }
Schema.f64 = { type = "f64" }
Schema.f16 = { type = "f16" }
Schema.boolean = { type = "boolean" }
Schema.vector3 = { type = "vector3" }
Schema.vector2 = { type = "vector2" }
Schema.cframe = { type = "cframe" }
Schema.color3 = { type = "color3" }
Schema.instance = { type = "instance" }
Schema.string = { type = "string" }

function Schema.optional(item: SchemaType): SchemaType
	return { type = "optional", item = item }
end

function Schema.array(item: SchemaType): SchemaType
	return { type = "array", item = item }
end

function Schema.map(key: SchemaType, value: SchemaType): SchemaType
	return { type = "map", key = key, value = value }
end

function Schema.struct(fields: {[string]: SchemaType}): SchemaType
	local orderedFields = {}
	for k, v in fields do
		table.insert(orderedFields, { key = k, schema = v })
	end
	table.sort(orderedFields, function(a, b) return a.key < b.key end)
	return { type = "struct", fields = orderedFields }
end

local function compilePacker(s: SchemaType): (Writer, any) -> ()
	if s.type == "u8" then return wByte end
	if s.type == "i8" then return function(w, v) ensureSpace(w, 1) buffer.writei8(w.buf, w.cursor, v) w.cursor += 1 end end
	if s.type == "u16" then return wU16 end
	if s.type == "i16" then return wI16 end
	if s.type == "u32" then return wU32 end
	if s.type == "i32" then return wI32 end
	if s.type == "f32" then return wF32 end
	if s.type == "f64" then return wF64 end
	if s.type == "f16" then return wF16 end
	if s.type == "boolean" then return function(w, v) wByte(w, v and 1 or 0) end end
	if s.type == "string" then return function(w, v) local len = #v wVarUInt(w, len) wString(w, v) end end
	
	if s.type == "vector3" then return function(w, v) wF16(w, f32ToF16(v.X)) wF16(w, f32ToF16(v.Y)) wF16(w, f32ToF16(v.Z)) end end
	if s.type == "vector2" then return function(w, v) wF16(w, f32ToF16(v.X)) wF16(w, f32ToF16(v.Y)) end end
	
	if s.type == "cframe" then 
		return function(w, v) 
			local pos = v.Position
			local rx, ry, rz = v:ToOrientation()
			wF16(w, f32ToF16(pos.X)) wF16(w, f32ToF16(pos.Y)) wF16(w, f32ToF16(pos.Z))
			wF16(w, f32ToF16(rx)) wF16(w, f32ToF16(ry)) wF16(w, f32ToF16(rz))
		end 
	end

	if s.type == "color3" then 
		return function(w, v) 
			wByte(w, math.clamp(math.round(v.R * 255), 0, 255))
			wByte(w, math.clamp(math.round(v.G * 255), 0, 255))
			wByte(w, math.clamp(math.round(v.B * 255), 0, 255))
		end 
	end

	if s.type == "instance" then return function(w, v) table.insert(w.refs, v) wVarUInt(w, #w.refs) end end
	
	if s.type == "struct" then
		local fields = {}
		for _, field in s.fields do
			table.insert(fields, { key = field.key, packer = compilePacker(field.schema) })
		end
		return function(w, v)
			if type(v) ~= "table" then error(`Expected table for struct, got {typeof(v)}`) end
			for _, f in fields do
				local val = v[f.key]
				if val == nil then error(`Schema Error: Missing required field '{f.key}'`) end
				f.packer(w, val)
			end
		end
	end

	if s.type == "array" then
		local itemPacker = compilePacker(s.item)
		return function(w, v)
			if type(v) ~= "table" then error(`Expected table for array, got {typeof(v)}`) end
			local len = #v
			wVarUInt(w, len)
			for i = 1, len do
				if v[i] == nil then error(`Schema Error: Array item at index {i} is nil`) end
				itemPacker(w, v[i])
			end
		end
	end

	if s.type == "map" then
		local keyPacker = compilePacker(s.key)
		local valPacker = compilePacker(s.value)
		return function(w, v)
			local count = 0
			for _ in v do count += 1 end
			wVarUInt(w, count)
			for k, val in v do
				keyPacker(w, k)
				valPacker(w, val)
			end
		end
	end

	if s.type == "optional" then
		local itemPacker = compilePacker(s.item)
		return function(w, v)
			if v == nil then
				wByte(w, 0)
			else
				wByte(w, 1)
				itemPacker(w, v)
			end
		end
	end

	return function() end
end

local function compileReader(s: SchemaType): (buffer, number, {any}?) -> (any, number)
	if s.type == "u8" then return function(b, c) return buffer.readu8(b, c), c + 1 end end
	if s.type == "i8" then return function(b, c) return buffer.readi8(b, c), c + 1 end end
	if s.type == "u16" then return function(b, c) return buffer.readu16(b, c), c + 2 end end
	if s.type == "i16" then return function(b, c) return buffer.readi16(b, c), c + 2 end end
	if s.type == "u32" then return function(b, c) return buffer.readu32(b, c), c + 4 end end
	if s.type == "i32" then return function(b, c) return buffer.readi32(b, c), c + 4 end end
	if s.type == "f32" then return function(b, c) return buffer.readf32(b, c), c + 4 end end
	if s.type == "f64" then return function(b, c) return buffer.readf64(b, c), c + 8 end end
	if s.type == "f16" then return function(b, c) return f16ToF32(buffer.readu16(b, c)), c + 2 end end
	if s.type == "boolean" then return function(b, c) return buffer.readu8(b, c) ~= 0, c + 1 end end
	if s.type == "string" then 
		return function(b, c) 
			local len; len, c = readVarUInt(b, c) 
			return buffer.readstring(b, c, len), c + len 
		end 
	end
	if s.type == "vector3" then
		return function(b, c)
			local x = f16ToF32(buffer.readu16(b, c))
			local y = f16ToF32(buffer.readu16(b, c + 2))
			local z = f16ToF32(buffer.readu16(b, c + 4))
			return Vector3.new(x, y, z), c + 6
		end
	end
	
	if s.type == "vector2" then
		return function(b, c)
			local x = f16ToF32(buffer.readu16(b, c))
			local y = f16ToF32(buffer.readu16(b, c + 2))
			return Vector2.new(x, y), c + 4
		end
	end
	
	if s.type == "color3" then
		return function(b, c)
			local r = buffer.readu8(b, c)
			local g = buffer.readu8(b, c + 1)
			local bVal = buffer.readu8(b, c + 2)
			return Color3.fromRGB(r, g, bVal), c + 3
		end
	end

	if s.type == "cframe" then
		return function(b, c)
			local px = f16ToF32(buffer.readu16(b, c))
			local py = f16ToF32(buffer.readu16(b, c + 2))
			local pz = f16ToF32(buffer.readu16(b, c + 4))
			local rx = f16ToF32(buffer.readu16(b, c + 6))
			local ry = f16ToF32(buffer.readu16(b, c + 8))
			local rz = f16ToF32(buffer.readu16(b, c + 10))
			return CFrame.new(px, py, pz) * CFrame.fromOrientation(rx, ry, rz), c + 12
		end
	end
	if s.type == "instance" then
		return function(b, c, refs)
			local idx; idx, c = readVarUInt(b, c)
			return refs and refs[idx] or nil, c
		end
	end
	
	if s.type == "struct" then
		local fields = {}
		for _, field in s.fields do
			table.insert(fields, { key = field.key, reader = compileReader(field.schema) })
		end
		return function(b, c, refs)
			local obj = {}
			for _, f in fields do
				obj[f.key], c = f.reader(b, c, refs)
			end
			return obj, c
		end
	end

	if s.type == "array" then
		local itemReader = compileReader(s.item)
		return function(b, c, refs)
			local len; len, c = readVarUInt(b, c)
			local arr = table.create(len)
			for i = 1, len do
				arr[i], c = itemReader(b, c, refs)
			end
			return arr, c
		end
	end

	if s.type == "map" then
		local keyReader = compileReader(s.key)
		local valReader = compileReader(s.value)
		return function(b, c, refs)
			local count; count, c = readVarUInt(b, c)
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

	if s.type == "optional" then
		local itemReader = compileReader(s.item)
		return function(b, c, refs)
			local exists = buffer.readu8(b, c) ~= 0
			c += 1
			if exists then
				return itemReader(b, c, refs)
			else
				return nil, c
			end
		end
	end
	
	return function(_, c) return nil, c end
end

local function packStrict(w: Writer, s: SchemaType, v: any)
	local packer = compilePacker(s)
	packer(w, v)
end

local function readStrict(buf: buffer, cursor: number, s: SchemaType, refs: { any }?): (any, number)
	local reader = compileReader(s)
	return reader(buf, cursor, refs)
end

local function writeEvents(w: Writer, events: {{any}}, schemas: {[string]: SchemaType})
	local count = #events
	wVarUInt(w, count)
	for _, event in events do
		local remote = event[1]
		local args = event[2]
		packValue(w, remote)
		local schema = schemas[remote]
		if schema then
			packStrict(w, schema, args[1])
		else
			packValue(w, args)
		end
	end
end

local function readEvents(buf: buffer, refs: {any}?, schemas: {[string]: SchemaType}): {{any}}
	local pos, count = 0
	count, pos = readVarUInt(buf, pos)
	local events = table.create(count)
	for i = 1, count do
		local remote
		remote, pos = unpackValue(buf, pos, refs)
		local args
		local schema = schemas[remote]
		if schema then
			local val
			val, pos = readStrict(buf, pos, schema, refs)
			args = {val}
		else
			args, pos = unpackValue(buf, pos, refs)
		end
		events[i] = {remote, args}
	end
	return events
end

local BufferSerdes = {}

BufferSerdes.writeEvents = writeEvents
BufferSerdes.readEvents = readEvents
BufferSerdes.Schema = Schema
BufferSerdes.compilePacker = compilePacker
BufferSerdes.compileReader = compileReader
BufferSerdes.packStrict = packStrict
BufferSerdes.readStrict = readStrict

function BufferSerdes.write(data: any): (buffer, {any}?)
	local w = createWriter()
	packValue(w, data)
	return buildWithRefs(w)
end

function BufferSerdes.read(buf: buffer, refs: {any}?): any
	return (unpackValue(buf, 0, refs))
end

function BufferSerdes.readAll(buf: buffer, refs: {any}?): {any}
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

BufferSerdes.varUIntSize = varUIntSize
BufferSerdes.writeVarUInt = writeVarUInt
BufferSerdes.readVarUInt = readVarUInt
BufferSerdes.f32ToF16 = f32ToF16
BufferSerdes.f16ToF32 = f16ToF32

BufferSerdes.readTagged = unpackValue
BufferSerdes.packTagged = packValue
BufferSerdes.unpack = unpackValue

return BufferSerdes :: typeof(BufferSerdes)