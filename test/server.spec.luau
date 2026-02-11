--!nocheck

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local WarpModule = ReplicatedStorage:WaitForChild("Warp")
	local Warp = require(WarpModule)

	describe("Warp.Server()", function()
		local Server = Warp.Server()

		it("returns a module with expected functions", function()
			expect(type(Server)).to.equal("table")
			expect(type(Server.Connect)).to.equal("function")
			expect(type(Server.Once)).to.equal("function")
			expect(type(Server.Wait)).to.equal("function")
			expect(type(Server.DisconnectAll)).to.equal("function")
			expect(type(Server.Destroy)).to.equal("function")
			expect(type(Server.Fire)).to.equal("function")
			expect(type(Server.Fires)).to.equal("function")
			expect(type(Server.Invoke)).to.equal("function")
			expect(type(Server.useSchema)).to.equal("function")
			expect(type(Server.Schema)).to.equal("table")
		end)

		it("Connect returns a connection that can disconnect", function()
			local conn = Server.Connect("_test_connect", function() end)
			expect(conn).to.be.ok()
			expect(conn.Connected).to.equal(true)

			conn:Disconnect()
			expect(conn.Connected).to.equal(false)
		end)
	end)
end