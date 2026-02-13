--!nocheck

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local WarpModule = ReplicatedStorage:WaitForChild("Warp")
	local Warp = require(WarpModule)

	local function roundTrip<T>(Buffer: any, value: T): T
		local buf, refs = Buffer.write(value)
		local decoded = Buffer.read(buf, refs)
		return decoded
	end

	local function approxEqual(a: number, b: number, epsilon: number?): boolean
		local eps = epsilon or 1e-4
		return math.abs(a - b) < eps
	end

	describe("Warp.Buffer", function()
		local Buffer = Warp.Buffer

		-- primitives

		it("round-trips tagged primitives (write/read)", function()
			expect(roundTrip(Buffer, true)).to.equal(true)
			expect(roundTrip(Buffer, false)).to.equal(false)
			expect(roundTrip(Buffer, 0)).to.equal(0)
			expect(roundTrip(Buffer, 127)).to.equal(127)
			expect(roundTrip(Buffer, 128)).to.equal(128)
			expect(roundTrip(Buffer, -1)).to.equal(-1)
			expect(roundTrip(Buffer, -32)).to.equal(-32)
			expect(roundTrip(Buffer, -33)).to.equal(-33)
			expect(roundTrip(Buffer, 255)).to.equal(255)
			expect(roundTrip(Buffer, 256)).to.equal(256)
			expect(roundTrip(Buffer, "hi")).to.equal("hi")
			expect(roundTrip(Buffer, string.rep("a", 40))).to.equal(string.rep("a", 40))
		end)

		it("round-trips nil", function()
			local result = roundTrip(Buffer, nil)
			expect(result).to.equal(nil)
		end)

		-- numbers

		it("round-trips positive fixint (0-127)", function()
			expect(roundTrip(Buffer, 0)).to.equal(0)
			expect(roundTrip(Buffer, 1)).to.equal(1)
			expect(roundTrip(Buffer, 63)).to.equal(63)
			expect(roundTrip(Buffer, 127)).to.equal(127)
		end)

		it("round-trips negative fixint (-32 to -1)", function()
			expect(roundTrip(Buffer, -1)).to.equal(-1)
			expect(roundTrip(Buffer, -16)).to.equal(-16)
			expect(roundTrip(Buffer, -32)).to.equal(-32)
		end)

		it("round-trips u8 range (128-255)", function()
			expect(roundTrip(Buffer, 128)).to.equal(128)
			expect(roundTrip(Buffer, 200)).to.equal(200)
			expect(roundTrip(Buffer, 255)).to.equal(255)
		end)

		it("round-trips u16 range (256-65535)", function()
			expect(roundTrip(Buffer, 256)).to.equal(256)
			expect(roundTrip(Buffer, 1000)).to.equal(1000)
			expect(roundTrip(Buffer, 65535)).to.equal(65535)
		end)

		it("round-trips u32 range (65536-4294967295)", function()
			expect(roundTrip(Buffer, 65536)).to.equal(65536)
			expect(roundTrip(Buffer, 1000000)).to.equal(1000000)
			expect(roundTrip(Buffer, 4294967295)).to.equal(4294967295)
		end)

		it("round-trips i8 range (-128 to -33)", function()
			expect(roundTrip(Buffer, -33)).to.equal(-33)
			expect(roundTrip(Buffer, -100)).to.equal(-100)
			expect(roundTrip(Buffer, -128)).to.equal(-128)
		end)

		it("round-trips i16 range (-32768 to -129)", function()
			expect(roundTrip(Buffer, -129)).to.equal(-129)
			expect(roundTrip(Buffer, -10000)).to.equal(-10000)
			expect(roundTrip(Buffer, -32768)).to.equal(-32768)
		end)

		it("round-trips i32 range (-2147483648 to -32769)", function()
			expect(roundTrip(Buffer, -32769)).to.equal(-32769)
			expect(roundTrip(Buffer, -1000000)).to.equal(-1000000)
			expect(roundTrip(Buffer, -2147483648)).to.equal(-2147483648)
		end)

		it("round-trips f32 floats", function()
			local val = roundTrip(Buffer, 3.14)
			expect(approxEqual(val, 3.14)).to.equal(true)
		end)

		it("round-trips f64 floats (high precision)", function()
			local val = roundTrip(Buffer, 3.141592653589793)
			expect(approxEqual(val, 3.141592653589793, 1e-12)).to.equal(true)
		end)

		it("round-trips large integers as f64", function()
			local big = 2 ^ 40
			expect(roundTrip(Buffer, big)).to.equal(big)
		end)

		it("round-trips NaN", function()
			local val = roundTrip(Buffer, 0 / 0)
			expect(val ~= val).to.equal(true) -- NaN ~= NaN
		end)

		-- strings

		it("round-trips empty string", function()
			expect(roundTrip(Buffer, "")).to.equal("")
		end)

		it("round-trips inline string (1-15 chars)", function()
			expect(roundTrip(Buffer, "a")).to.equal("a")
			expect(roundTrip(Buffer, "hello world!!!!")).to.equal("hello world!!!!")
		end)

		it("round-trips str8 string (16-255 chars)", function()
			local s = string.rep("x", 200)
			expect(roundTrip(Buffer, s)).to.equal(s)
		end)

		it("round-trips str16 string (256-65535 chars)", function()
			local s = string.rep("y", 1000)
			expect(roundTrip(Buffer, s)).to.equal(s)
		end)

		-- arrays & maps

		it("round-trips arrays and maps (write/read)", function()
			local arr = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
			local decodedArr = roundTrip(Buffer, arr)
			expect(type(decodedArr)).to.equal("table")
			expect(#decodedArr).to.equal(#arr)
			for i = 1, #arr do
				expect(decodedArr[i]).to.equal(arr[i])
			end

			local map = { a = 1, b = true, c = "ok" }
			local decodedMap = roundTrip(Buffer, map)
			expect(type(decodedMap)).to.equal("table")
			expect(decodedMap.a).to.equal(1)
			expect(decodedMap.b).to.equal(true)
			expect(decodedMap.c).to.equal("ok")
		end)

		it("round-trips empty array", function()
			local decoded = roundTrip(Buffer, {})
			expect(type(decoded)).to.equal("table")
			expect(#decoded).to.equal(0)
		end)

		it("round-trips inline array (1-7 elements)", function()
			local arr = { "a", "b", "c" }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(3)
			expect(decoded[1]).to.equal("a")
			expect(decoded[2]).to.equal("b")
			expect(decoded[3]).to.equal("c")
		end)

		it("round-trips arr8 array (8-255 elements)", function()
			local arr = {}
			for i = 1, 100 do
				arr[i] = "item" .. i
			end
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(100)
			expect(decoded[1]).to.equal("item1")
			expect(decoded[100]).to.equal("item100")
		end)

		it("round-trips arr16 array (256+ elements)", function()
			local arr = {}
			for i = 1, 300 do
				arr[i] = "v" .. i
			end
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(300)
			expect(decoded[1]).to.equal("v1")
			expect(decoded[300]).to.equal("v300")
		end)

		it("round-trips inline map (1-7 pairs)", function()
			local map = { x = 1, y = 2 }
			local decoded = roundTrip(Buffer, map)
			expect(decoded.x).to.equal(1)
			expect(decoded.y).to.equal(2)
		end)

		it("round-trips map8 map (8-255 pairs)", function()
			local map = {}
			for i = 1, 50 do
				map["key" .. i] = i
			end
			local decoded = roundTrip(Buffer, map)
			for i = 1, 50 do
				expect(decoded["key" .. i]).to.equal(i)
			end
		end)

		it("round-trips deeply nested tables", function()
			local nested = { a = { b = { c = { d = { 1, 2, 3 } } } } }
			local decoded = roundTrip(Buffer, nested)
			expect(decoded.a.b.c.d[1]).to.equal(1)
			expect(decoded.a.b.c.d[2]).to.equal(2)
			expect(decoded.a.b.c.d[3]).to.equal(3)
		end)

		it("round-trips mixed nested arrays and maps", function()
			local data = {
				{ name = "Alice", scores = { 10, 20, 30 } },
				{ name = "Bob", scores = { 40, 50 } },
			}
			local decoded = roundTrip(Buffer, data)
			expect(#decoded).to.equal(2)
			expect(decoded[1].name).to.equal("Alice")
			expect(#decoded[1].scores).to.equal(3)
			expect(decoded[1].scores[2]).to.equal(20)
			expect(decoded[2].name).to.equal("Bob")
			expect(decoded[2].scores[1]).to.equal(40)
		end)

		-- typed number arrays

		it("round-trips typed u8 array", function()
			local arr = { 0, 50, 100, 200, 255 }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(5)
			for i = 1, 5 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("round-trips typed i8 array", function()
			local arr = { -128, -50, 0, 50, 127 }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(5)
			for i = 1, 5 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("round-trips typed u16 array", function()
			local arr = { 0, 1000, 30000, 65535 }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(4)
			for i = 1, 4 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("round-trips typed i16 array", function()
			local arr = { -32768, -1000, 0, 1000, 32767 }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(5)
			for i = 1, 5 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("round-trips typed u32 array", function()
			local arr = { 0, 100000, 1000000, 4294967295 }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(4)
			for i = 1, 4 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("round-trips typed i32 array", function()
			local arr = { -2147483648, -100000, 0, 100000, 2147483647 }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(5)
			for i = 1, 5 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("round-trips typed f32 array", function()
			local arr = { 1.5, 2.5, 3.5, 4.5 }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(4)
			for i = 1, 4 do
				expect(approxEqual(decoded[i], arr[i])).to.equal(true)
			end
		end)

		it("does not use typed array for fewer than 4 homogeneous numbers", function()
			-- 3 elements should use regular array path, not typed
			local arr = { 10, 20, 30 }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(3)
			for i = 1, 3 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		-- boolean array bitpacking

		it("round-trips boolean array (exact 8 = 1 byte boundary)", function()
			local arr = { true, false, true, true, false, false, true, false }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(8)
			for i = 1, 8 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("round-trips boolean array (9 elements = partial last byte)", function()
			local arr = { true, false, true, true, false, false, true, false, true }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(9)
			for i = 1, 9 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("round-trips boolean array (2 elements = minimum for bitpacking)", function()
			local arr = { true, false }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(2)
			expect(decoded[1]).to.equal(true)
			expect(decoded[2]).to.equal(false)
		end)

		it("round-trips boolean array (all true)", function()
			local arr = {}
			for i = 1, 32 do
				arr[i] = true
			end
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(32)
			for i = 1, 32 do
				expect(decoded[i]).to.equal(true)
			end
		end)

		it("round-trips boolean array (all false)", function()
			local arr = {}
			for i = 1, 32 do
				arr[i] = false
			end
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(32)
			for i = 1, 32 do
				expect(decoded[i]).to.equal(false)
			end
		end)

		it("round-trips large boolean array (100 elements)", function()
			local arr = {}
			for i = 1, 100 do
				arr[i] = (i % 3 == 0)
			end
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(100)
			for i = 1, 100 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("round-trips large boolean array (1000 elements)", function()
			local arr = {}
			for i = 1, 1000 do
				arr[i] = (i % 7 < 3)
			end
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(1000)
			for i = 1, 1000 do
				expect(decoded[i]).to.equal(arr[i])
			end
		end)

		it("boolean array is smaller than per-element encoding", function()
			local arr = {}
			for i = 1, 64 do
				arr[i] = (i % 2 == 0)
			end
			local packedBuf = Buffer.write(arr)
			-- 64 bools bitpacked = tag(1) + varuint(1) + 8 bytes = 10 bytes
			-- 64 bools tagged individually would be much larger
			-- Use a reasonable threshold that accounts for bitpacking
			expect(buffer.len(packedBuf) < 66).to.equal(true)
		end)

		it("does not bitpack a single boolean in an array", function()
			-- count=1 should NOT trigger bitpacking, should use regular array
			local arr = { true }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(1)
			expect(decoded[1]).to.equal(true)
		end)

		it("does not bitpack mixed boolean/number array", function()
			local arr = { true, false, 42, true }
			local decoded = roundTrip(Buffer, arr)
			expect(#decoded).to.equal(4)
			expect(decoded[1]).to.equal(true)
			expect(decoded[2]).to.equal(false)
			expect(decoded[3]).to.equal(42)
			expect(decoded[4]).to.equal(true)
		end)

		-- roblox types

		it("round-trips Vector3", function()
			local v = Vector3.new(1.5, -2.5, 3.75)
			local decoded = roundTrip(Buffer, v)
			expect(approxEqual(decoded.X, 1.5)).to.equal(true)
			expect(approxEqual(decoded.Y, -2.5)).to.equal(true)
			expect(approxEqual(decoded.Z, 3.75)).to.equal(true)
		end)

		it("round-trips Vector3.zero", function()
			local decoded = roundTrip(Buffer, Vector3.zero)
			expect(decoded.X).to.equal(0)
			expect(decoded.Y).to.equal(0)
			expect(decoded.Z).to.equal(0)
		end)

		it("round-trips Vector2", function()
			local v = Vector2.new(10.5, -20.25)
			local decoded = roundTrip(Buffer, v)
			expect(approxEqual(decoded.X, 10.5)).to.equal(true)
			expect(approxEqual(decoded.Y, -20.25)).to.equal(true)
		end)

		it("round-trips CFrame", function()
			local cf = CFrame.new(1, 2, 3) * CFrame.Angles(0.5, 1.0, 1.5)
			local decoded = roundTrip(Buffer, cf)
			expect(approxEqual(decoded.Position.X, cf.Position.X)).to.equal(true)
			expect(approxEqual(decoded.Position.Y, cf.Position.Y)).to.equal(true)
			expect(approxEqual(decoded.Position.Z, cf.Position.Z)).to.equal(true)

			local rx1, ry1, rz1 = cf:ToOrientation()
			local rx2, ry2, rz2 = decoded:ToOrientation()
			expect(approxEqual(rx1, rx2, 1e-3)).to.equal(true)
			expect(approxEqual(ry1, ry2, 1e-3)).to.equal(true)
			expect(approxEqual(rz1, rz2, 1e-3)).to.equal(true)
		end)

		it("round-trips CFrame.identity", function()
			local decoded = roundTrip(Buffer, CFrame.identity)
			expect(approxEqual(decoded.Position.X, 0)).to.equal(true)
			expect(approxEqual(decoded.Position.Y, 0)).to.equal(true)
			expect(approxEqual(decoded.Position.Z, 0)).to.equal(true)
		end)

		it("round-trips Color3 (byte precision)", function()
			local c = Color3.fromRGB(128, 64, 255)
			local decoded = roundTrip(Buffer, c)
			expect(math.round(decoded.R * 255)).to.equal(128)
			expect(math.round(decoded.G * 255)).to.equal(64)
			expect(math.round(decoded.B * 255)).to.equal(255)
		end)

		it("round-trips Color3 (float precision for HDR)", function()
			local c = Color3.new(2.0, 0.5, 1.5) -- R > 1 triggers float path
			local decoded = roundTrip(Buffer, c)
			expect(approxEqual(decoded.R, 2.0)).to.equal(true)
			expect(approxEqual(decoded.G, 0.5)).to.equal(true)
			expect(approxEqual(decoded.B, 1.5)).to.equal(true)
		end)

		it("round-trips BrickColor", function()
			local bc = BrickColor.new("Bright red")
			local decoded = roundTrip(Buffer, bc)
			expect(decoded.Number).to.equal(bc.Number)
		end)

		it("round-trips UDim2", function()
			local ud = UDim2.new(0.5, 10, 1.0, -20)
			local decoded = roundTrip(Buffer, ud)
			expect(approxEqual(decoded.X.Scale, 0.5)).to.equal(true)
			expect(decoded.X.Offset).to.equal(10)
			expect(approxEqual(decoded.Y.Scale, 1.0)).to.equal(true)
			expect(decoded.Y.Offset).to.equal(-20)
		end)

		it("round-trips UDim", function()
			local ud = UDim.new(0.75, -5)
			local decoded = roundTrip(Buffer, ud)
			expect(approxEqual(decoded.Scale, 0.75)).to.equal(true)
			expect(decoded.Offset).to.equal(-5)
		end)

		it("round-trips Rect", function()
			local r = Rect.new(10, 20, 300, 400)
			local decoded = roundTrip(Buffer, r)
			expect(approxEqual(decoded.Min.X, 10)).to.equal(true)
			expect(approxEqual(decoded.Min.Y, 20)).to.equal(true)
			expect(approxEqual(decoded.Max.X, 300)).to.equal(true)
			expect(approxEqual(decoded.Max.Y, 400)).to.equal(true)
		end)

		it("round-trips NumberRange", function()
			local nr = NumberRange.new(-5, 10)
			local decoded = roundTrip(Buffer, nr)
			expect(approxEqual(decoded.Min, -5)).to.equal(true)
			expect(approxEqual(decoded.Max, 10)).to.equal(true)
		end)

		it("round-trips Ray", function()
			local r = Ray.new(Vector3.new(1, 2, 3), Vector3.new(0, 1, 0))
			local decoded = roundTrip(Buffer, r)
			expect(approxEqual(decoded.Origin.X, 1)).to.equal(true)
			expect(approxEqual(decoded.Origin.Y, 2)).to.equal(true)
			expect(approxEqual(decoded.Origin.Z, 3)).to.equal(true)
			expect(approxEqual(decoded.Direction.X, 0)).to.equal(true)
			expect(approxEqual(decoded.Direction.Y, 1)).to.equal(true)
			expect(approxEqual(decoded.Direction.Z, 0)).to.equal(true)
		end)

		it("round-trips EnumItem", function()
			local e = Enum.Material.Grass
			local decoded = roundTrip(Buffer, e)
			expect(decoded).to.equal(e)
		end)

		it("round-trips ColorSequence", function()
			local cs = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 255)),
			})
			local decoded = roundTrip(Buffer, cs)
			expect(#decoded.Keypoints).to.equal(3)
			expect(approxEqual(decoded.Keypoints[1].Time, 0)).to.equal(true)
			expect(math.round(decoded.Keypoints[1].Value.R * 255)).to.equal(255)
			expect(approxEqual(decoded.Keypoints[2].Time, 0.5)).to.equal(true)
			expect(math.round(decoded.Keypoints[2].Value.G * 255)).to.equal(255)
		end)

		it("round-trips NumberSequence", function()
			local ns = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0, 0),
				NumberSequenceKeypoint.new(0.5, 1, 0.2),
				NumberSequenceKeypoint.new(1, 0, 0),
			})
			local decoded = roundTrip(Buffer, ns)
			expect(#decoded.Keypoints).to.equal(3)
			expect(approxEqual(decoded.Keypoints[2].Time, 0.5)).to.equal(true)
			expect(approxEqual(decoded.Keypoints[2].Value, 1)).to.equal(true)
			expect(approxEqual(decoded.Keypoints[2].Envelope, 0.2)).to.equal(true)
		end)

		-- buffer type

		it("round-trips buffer value", function()
			local b = buffer.create(8)
			buffer.writeu32(b, 0, 12345678)
			buffer.writef32(b, 4, 3.14)

			local decoded = roundTrip(Buffer, b)
			expect(buffer.len(decoded)).to.equal(8)
			expect(buffer.readu32(decoded, 0)).to.equal(12345678)
			expect(approxEqual(buffer.readf32(decoded, 4), 3.14)).to.equal(true)
		end)

		it("round-trips empty buffer", function()
			local b = buffer.create(0)
			local decoded = roundTrip(Buffer, b)
			expect(buffer.len(decoded)).to.equal(0)
		end)

		-- instances

		it("round-trips Instances through refs (write/read)", function()
			local inst = Instance.new("Folder")
			inst.Name = "WarpBufferTestFolder"

			local buf, refs = Buffer.write(inst)
			expect(type(buf)).to.equal("buffer")
			expect(type(refs)).to.equal("table")
			expect((refs :: { any })[1]).to.equal(inst)

			local decodedWithRefs = Buffer.read(buf, refs)
			expect(decodedWithRefs).to.equal(inst)

			local decodedWithoutRefs = Buffer.read(buf)
			expect(decodedWithoutRefs).to.equal(nil)

			inst:Destroy()
		end)

		it("round-trips multiple instances with correct ref indices", function()
			local a = Instance.new("Folder")
			local b = Instance.new("Folder")
			a.Name = "A"
			b.Name = "B"

			local data = { a, b, a } -- 'a' appears twice
			local buf, refs = Buffer.write(data)
			local decoded = Buffer.read(buf, refs)

			expect(decoded[1]).to.equal(a)
			expect(decoded[2]).to.equal(b)
			expect(decoded[3]).to.equal(a)

			a:Destroy()
			b:Destroy()
		end)

		-- writer ops

		it("can pack multiple tagged values and read them back (readAll)", function()
			local w = Buffer.createWriter()
			Buffer.pack(w, "a")
			Buffer.pack(w, 123)
			Buffer.pack(w, { 1, 2, 3, 4 })

			local buf, refs = Buffer.buildWithRefs(w)
			local values = Buffer.readAll(buf, refs)
			expect(#values).to.equal(3)
			expect(values[1]).to.equal("a")
			expect(values[2]).to.equal(123)
			expect(type(values[3])).to.equal("table")
			expect(#(values[3] :: { any })).to.equal(4)
		end)

		it("writer reset clears cursor and refs", function()
			local w = Buffer.createWriter()
			Buffer.pack(w, "hello")
			Buffer.pack(w, 42)
			expect(w.cursor > 0).to.equal(true)

			Buffer.reset(w)
			expect(w.cursor).to.equal(0)
			expect(#w.refs).to.equal(0)
		end)

		it("writer grows capacity automatically", function()
			local w = Buffer.createWriter(4) -- tiny initial capacity
			local longStr = string.rep("z", 200)
			Buffer.pack(w, longStr)
			expect(w.capacity >= 200).to.equal(true)

			local buf = Buffer.build(w)
			local decoded = Buffer.read(buf)
			expect(decoded).to.equal(longStr)
		end)

		-- varuint

		it("encodes/decodes varUInt", function()
			local b = buffer.create(16)
			local endOffset = Buffer.writeVarUInt(b, 0, 300)
			local v, newOffset = Buffer.readVarUInt(b, 0)
			expect(v).to.equal(300)
			expect(newOffset).to.equal(endOffset)
		end)

		it("encodes/decodes varUInt edge values", function()
			local testValues = { 0, 1, 127, 128, 16383, 16384, 2097151, 2097152 }
			local b = buffer.create(64)
			for _, val in testValues do
				local endOff = Buffer.writeVarUInt(b, 0, val)
				local decoded, readOff = Buffer.readVarUInt(b, 0)
				expect(decoded).to.equal(val)
				expect(readOff).to.equal(endOff)
			end
		end)

		it("varUIntSize returns correct sizes", function()
			expect(Buffer.varUIntSize(0)).to.equal(1)
			expect(Buffer.varUIntSize(127)).to.equal(1)
			expect(Buffer.varUIntSize(128)).to.equal(2)
			expect(Buffer.varUIntSize(16383)).to.equal(2)
			expect(Buffer.varUIntSize(16384)).to.equal(3)
		end)

		-- schema: primitives

		it("schema round-trips u8", function()
			local S = Buffer.Schema
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.u8, 200)
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, S.u8)
			expect(val).to.equal(200)
		end)

		it("schema round-trips i16", function()
			local S = Buffer.Schema
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.i16, -1234)
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, S.i16)
			expect(val).to.equal(-1234)
		end)

		it("schema round-trips f32", function()
			local S = Buffer.Schema
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.f32, 3.14)
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, S.f32)
			expect(approxEqual(val, 3.14)).to.equal(true)
		end)

		it("schema round-trips boolean", function()
			local S = Buffer.Schema
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.boolean, true)
			Buffer.packStrict(w, S.boolean, false)
			local buf = Buffer.build(w)
			local v1, pos = Buffer.readStrict(buf, 0, S.boolean)
			local v2 = Buffer.readStrict(buf, pos, S.boolean)
			expect(v1).to.equal(true)
			expect(v2).to.equal(false)
		end)

		it("schema round-trips string", function()
			local S = Buffer.Schema
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.string, "test string!")
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, S.string)
			expect(val).to.equal("test string!")
		end)

		-- (schema) roblox types

		it("schema round-trips vector3", function()
			local S = Buffer.Schema
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.vector3, Vector3.new(1, 2, 3))
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, S.vector3)
			expect(approxEqual(val.X, 1)).to.equal(true)
			expect(approxEqual(val.Y, 2)).to.equal(true)
			expect(approxEqual(val.Z, 3)).to.equal(true)
		end)

		it("schema round-trips vector2", function()
			local S = Buffer.Schema
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.vector2, Vector2.new(-5, 10))
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, S.vector2)
			expect(approxEqual(val.X, -5)).to.equal(true)
			expect(approxEqual(val.Y, 10)).to.equal(true)
		end)

		it("schema round-trips color3", function()
			local S = Buffer.Schema
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.color3, Color3.fromRGB(100, 200, 50))
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, S.color3)
			expect(math.round(val.R * 255)).to.equal(100)
			expect(math.round(val.G * 255)).to.equal(200)
			expect(math.round(val.B * 255)).to.equal(50)
		end)

		it("schema round-trips cframe", function()
			local S = Buffer.Schema
			local cf = CFrame.new(10, -5, 3) * CFrame.Angles(0.1, 0.2, 0.3)
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.cframe, cf)
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, S.cframe)
			expect(approxEqual(val.Position.X, cf.Position.X)).to.equal(true)
			expect(approxEqual(val.Position.Y, cf.Position.Y)).to.equal(true)
			expect(approxEqual(val.Position.Z, cf.Position.Z)).to.equal(true)
		end)

		it("schema round-trips instance", function()
			local S = Buffer.Schema
			local inst = Instance.new("Folder")
			local w = Buffer.createWriter()
			Buffer.packStrict(w, S.instance, inst)
			local buf, refs = Buffer.buildWithRefs(w)
			local val = Buffer.readStrict(buf, 0, S.instance, refs)
			expect(val).to.equal(inst)
			inst:Destroy()
		end)

		-- (schema) composites

		it("schema round-trips struct", function()
			local S = Buffer.Schema
			local schema = S.struct({
				x = S.f32,
				y = S.f32,
				name = S.string,
				active = S.boolean,
			})

			local data = { x = 1.5, y = -2.5, name = "test", active = true }
			local w = Buffer.createWriter()
			Buffer.packStrict(w, schema, data)
			local buf = Buffer.build(w)
			local decoded = Buffer.readStrict(buf, 0, schema)

			expect(decoded.name).to.equal("test")
			expect(decoded.active).to.equal(true)
			expect(approxEqual(decoded.x, 1.5)).to.equal(true)
			expect(approxEqual(decoded.y, -2.5)).to.equal(true)
		end)

		it("schema round-trips array of primitives", function()
			local S = Buffer.Schema
			local schema = S.array(S.u16)

			local data = { 100, 200, 300, 65535 }
			local w = Buffer.createWriter()
			Buffer.packStrict(w, schema, data)
			local buf = Buffer.build(w)
			local decoded = Buffer.readStrict(buf, 0, schema)

			expect(#decoded).to.equal(4)
			for i = 1, 4 do
				expect(decoded[i]).to.equal(data[i])
			end
		end)

		it("schema round-trips map", function()
			local S = Buffer.Schema
			local schema = S.map(S.string, S.i32)

			local data = { hp = 100, mp = -50, xp = 99999 }
			local w = Buffer.createWriter()
			Buffer.packStrict(w, schema, data)
			local buf = Buffer.build(w)
			local decoded = Buffer.readStrict(buf, 0, schema)

			expect(decoded.hp).to.equal(100)
			expect(decoded.mp).to.equal(-50)
			expect(decoded.xp).to.equal(99999)
		end)

		it("schema round-trips optional (present)", function()
			local S = Buffer.Schema
			local schema = S.optional(S.u32)

			local w = Buffer.createWriter()
			Buffer.packStrict(w, schema, 42)
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, schema)
			expect(val).to.equal(42)
		end)

		it("schema round-trips optional (nil)", function()
			local S = Buffer.Schema
			local schema = S.optional(S.u32)

			local w = Buffer.createWriter()
			Buffer.packStrict(w, schema, nil)
			local buf = Buffer.build(w)
			local val = Buffer.readStrict(buf, 0, schema)
			expect(val).to.equal(nil)
		end)

		it("schema round-trips nested struct with arrays", function()
			local S = Buffer.Schema
			local schema = S.struct({
				name = S.string,
				scores = S.array(S.u16),
				pos = S.vector3,
			})

			local data = {
				name = "Player1",
				scores = { 100, 250, 999 },
				pos = Vector3.new(10, 20, 30),
			}

			local w = Buffer.createWriter()
			Buffer.packStrict(w, schema, data)
			local buf = Buffer.build(w)
			local decoded = Buffer.readStrict(buf, 0, schema)

			expect(decoded.name).to.equal("Player1")
			expect(#decoded.scores).to.equal(3)
			expect(decoded.scores[1]).to.equal(100)
			expect(decoded.scores[2]).to.equal(250)
			expect(decoded.scores[3]).to.equal(999)
			expect(approxEqual(decoded.pos.X, 10)).to.equal(true)
		end)

		it("schema round-trips array of structs", function()
			local S = Buffer.Schema
			local schema = S.array(S.struct({
				id = S.u16,
				alive = S.boolean,
			}))

			local data = {
				{ id = 1, alive = true },
				{ id = 2, alive = false },
				{ id = 100, alive = true },
			}

			local w = Buffer.createWriter()
			Buffer.packStrict(w, schema, data)
			local buf = Buffer.build(w)
			local decoded = Buffer.readStrict(buf, 0, schema)

			expect(#decoded).to.equal(3)
			expect(decoded[1].id).to.equal(1)
			expect(decoded[1].alive).to.equal(true)
			expect(decoded[2].id).to.equal(2)
			expect(decoded[2].alive).to.equal(false)
			expect(decoded[3].id).to.equal(100)
			expect(decoded[3].alive).to.equal(true)
		end)

		-- event batches

		it("encodes/decodes event batches (writeEvents/readEvents), with and without schemas", function()
			local S = Buffer.Schema
			local schemas = {
				[1] = S.struct({ -- this defined in id since remoteName (string) will be converted into integer (u8) through Identifier
					count = S.u8,
					msg = S.string,
				}),
			}
		
			local payload = {
				count = 7,
				msg = "hello",
			}
		
			local events = {
				{ 1, { payload } },
				{ 2, { 1, 2 } },
			}
		
			local w = Buffer.createWriter()
			Buffer.writeEvents(w, events, schemas)
			local buf, refs = Buffer.buildWithRefs(w)
		
			local decoded = Buffer.readEvents(buf, refs, schemas)
			expect(#decoded).to.equal(2)
		
			expect(decoded[1][1]).to.equal(1)
			expect(decoded[1][2][1].count).to.equal(7)
			expect(decoded[1][2][1].msg).to.equal("hello")
		
			expect(decoded[2][1]).to.equal(2)
			expect(decoded[2][2][1]).to.equal(1)
			expect(decoded[2][2][2]).to.equal(2)
		end)

		it("encodes/decodes empty event batch", function()
			local w = Buffer.createWriter()
			Buffer.writeEvents(w, {}, {})
			local buf, refs = Buffer.buildWithRefs(w)
			local decoded = Buffer.readEvents(buf, refs, {})
			expect(#decoded).to.equal(0)
		end)

		-- edge cases

		it("round-trips table with nil holes treated as map", function()
			-- sparse table should not crash
			local data = { [1] = "a", [3] = "c", [5] = "e" }
			local decoded = roundTrip(Buffer, data)
			expect(decoded[1]).to.equal("a")
			expect(decoded[3]).to.equal("c")
			expect(decoded[5]).to.equal("e")
		end)

		it("round-trips complex real-world payload", function()
			local payload = {
				position = Vector3.new(100, 50, -200),
				health = 85,
				inventory = { 1, 2, 3, 4, 5, 6, 7, 8 },
				equipped = true,
				name = "SwordOfDoom",
				color = Color3.fromRGB(255, 128, 0),
				settings = {
					volume = 75,
					muted = false,
				},
			}

			local decoded = roundTrip(Buffer, payload)
			expect(approxEqual(decoded.position.X, 100)).to.equal(true)
			expect(decoded.health).to.equal(85)
			expect(#decoded.inventory).to.equal(8)
			expect(decoded.equipped).to.equal(true)
			expect(decoded.name).to.equal("SwordOfDoom")
			expect(decoded.settings.volume).to.equal(75)
			expect(decoded.settings.muted).to.equal(false)
		end)
	end)
end