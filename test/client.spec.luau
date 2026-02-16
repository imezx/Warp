--!nocheck

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local WarpModule = ReplicatedStorage:WaitForChild("Warp")
	local Warp = require(WarpModule)

	describe("Warp.Client()", function()
		local Client = Warp.Client()

		it("returns a module with expected functions", function()
			expect(type(Client)).to.equal("table")
			expect(type(Client.Connect)).to.equal("function")
			expect(type(Client.Once)).to.equal("function")
			expect(type(Client.Wait)).to.equal("function")
			expect(type(Client.DisconnectAll)).to.equal("function")
			expect(type(Client.Destroy)).to.equal("function")
			expect(type(Client.Fire)).to.equal("function")
			expect(type(Client.Invoke)).to.equal("function")
			expect(type(Client.useSchema)).to.equal("function")
			expect(type(Client.Schema)).to.equal("table")
		end)

		it("Connect returns a connection that can disconnect", function()
			local conn = Client.Connect("_test_connect", function() return end)
			expect(conn).to.be.ok()
			--expect(conn.Connected).to.equal(true) -- .Connected is always false on studio mode
			expect(type(conn.Disconnect)).to.equal("function")

			conn:Disconnect()
			expect(conn.Connected).to.equal(false)
		end)
	end)
end