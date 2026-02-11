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

	describe("Warp.Buffer", function()
		local Buffer = Warp.Buffer

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
		end)

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

		it("encodes/decodes varUInt", function()
			local b = buffer.create(16)
			local endOffset = Buffer.writeVarUInt(b, 0, 300)
			local v, newOffset = Buffer.readVarUInt(b, 0)
			expect(v).to.equal(300)
			expect(newOffset).to.equal(endOffset)
		end)

		it("encodes/decodes event batches (writeEvents/readEvents), with and without schemas", function()
			local S = Buffer.Schema
			local schemas = {
				MyRemote = S.struct({
					count = S.u8,
					msg = S.string,
				}),
			}

			local payload = {
				count = 7,
				msg = "hello",
			}

			local events = {
				{ "MyRemote", { payload } },
				{ "OtherRemote", { 1, 2 } },
			}

			local w = Buffer.createWriter()
			Buffer.writeEvents(w, events, schemas)
			local buf, refs = Buffer.buildWithRefs(w)

			local decoded = Buffer.readEvents(buf, refs, schemas)
			expect(#decoded).to.equal(2)

			expect(decoded[1][1]).to.equal("MyRemote")
			expect(decoded[1][2][1].count).to.equal(7)
			expect(decoded[1][2][1].msg).to.equal("hello")

			expect(decoded[2][1]).to.equal("OtherRemote")
			expect(decoded[2][2][1]).to.equal(1)
			expect(decoded[2][2][2]).to.equal(2)
		end)
	end)
end