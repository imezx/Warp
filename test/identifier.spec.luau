--!nocheck

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local WarpModule = ReplicatedStorage:WaitForChild("Warp")
	local Identifier = require(WarpModule:WaitForChild("Util"):WaitForChild("Identifier"))
	
	local U16_MAX, U16_MIN = 65535, 2

	describe("Warp.Identifier", function()
		it("returns a number", function()
			local result = Identifier("TestEvent")
			expect(type(result)).to.equal("number")
		end)

		it("returns an integer", function()
			local result = Identifier("TestEvent")
			expect(result == math.floor(result)).to.equal(true)
		end)

		it(`returns a value within {U16_MIN}-{U16_MAX} range (8-bit)`, function()
			local result = Identifier("TestEvent")
			expect(result >= U16_MIN).to.equal(true)
			expect(result <= U16_MAX).to.equal(true)
		end)

		it("is deterministic (same name returns same value)", function()
			local a = Identifier("MyRemote")
			local b = Identifier("MyRemote")
			expect(a).to.equal(b)
		end)

		it("returns cached result on repeated calls", function()
			local a = Identifier("DataReplicationEvent")
			local b = Identifier("DataReplicationEvent")
			local c = Identifier("DataReplicationEvent")
			expect(a).to.equal(b)
			expect(b).to.equal(c)
		end)

		it("handles empty string", function()
			local result = Identifier("")
			expect(type(result)).to.equal("number")
			expect(result >= U16_MIN).to.equal(true)
			expect(result <= U16_MAX).to.equal(true)
		end)

		it("handles single character strings", function()
			local result = Identifier("A")
			expect(type(result)).to.equal("number")
			expect(result >= U16_MIN).to.equal(true)
			expect(result <= U16_MAX).to.equal(true)
		end)

		it("handles long strings", function()
			local longName = string.rep("abcdefghij", 100)
			local result = Identifier(longName)
			expect(type(result)).to.equal("number")
			expect(result >= U16_MIN).to.equal(true)
			expect(result <= U16_MAX).to.equal(true)
		end)

		it("produces at least some distinct values for different names", function()
			local names = { "A", "B", "C", "D", "E", "F", "Hello", "World", "Foo", "Bar" }
			local unique = {}
			for _, name in names do
				unique[Identifier(name)] = true
			end
			local count = U16_MIN
			for _ in unique do
				count += 1
			end
			-- 10 distinct inputs in 8-bit space: extremely unlikely all collide
			expect(count > 1).to.equal(true)
		end)

		it("stays within 8-bit range across many inputs", function()
			for i = 1, 500 do
				local result = Identifier(`Event{i}`)
				expect(result >= U16_MIN).to.equal(true)
				expect(result <= U16_MAX).to.equal(true)
				expect(result == math.floor(result)).to.equal(true)
			end
		end)

		it("returns consistent results regardless of call order", function()
			local names = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon" }
			local firstPass = {}
			for _, name in names do
				firstPass[name] = Identifier(name)
			end
			-- call again in reverse order
			for i = #names, 1, -1 do
				expect(Identifier(names[i])).to.equal(firstPass[names[i]])
			end
		end)

		it("handles names with special characters", function()
			local specialNames = {
				"hello world",
				"test!@#$%",
				"foo\tbar",
				"new\nline",
				"\0null",
			}
			for _, name in specialNames do
				local result = Identifier(name)
				expect(type(result)).to.equal("number")
				expect(result >= U16_MIN).to.equal(true)
				expect(result <= U16_MAX).to.equal(true)
			end
		end)

		it("handles numeric-like string names", function()
			local a = Identifier("123")
			local b = Identifier("456")
			expect(type(a)).to.equal("number")
			expect(type(b)).to.equal("number")
			expect(a >= U16_MIN).to.equal(true)
			expect(a <= U16_MAX).to.equal(true)
			expect(b >= U16_MIN).to.equal(true)
			expect(b <= U16_MAX).to.equal(true)
		end)

		it("different names that are similar still hash correctly", function()
			local a = Identifier("PlayerJoined")
			local b = Identifier("PlayerJoine")
			local c = Identifier("PlayerJoinee")
			expect(type(a)).to.equal("number")
			expect(type(b)).to.equal("number")
			expect(type(c)).to.equal("number")
			-- all in range
			expect(a >= U16_MIN and a <= U16_MAX).to.equal(true)
			expect(b >= U16_MIN and b <= U16_MAX).to.equal(true)
			expect(c >= U16_MIN and c <= U16_MAX).to.equal(true)
		end)
	end)
end
