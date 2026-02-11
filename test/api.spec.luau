--!nocheck

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local WarpModule = ReplicatedStorage:WaitForChild("Warp")
	local Warp = require(WarpModule)

	describe("public api", function()
		it("exports Client/Server factories and Buffer", function()
			expect(type(Warp)).to.equal("table")
			expect(type(Warp.Client)).to.equal("function")
			expect(type(Warp.Server)).to.equal("function")
			expect(type(Warp.Buffer)).to.equal("table")
		end)

		it("creates RemoteEvent/RemoteFunction under the module (server only)", function()
			if not RunService:IsServer() then
				return
			end

			local ev = WarpModule:FindFirstChild("Event")
			local fn = WarpModule:FindFirstChild("Function")

			expect(ev).to.be.ok()
			expect(fn).to.be.ok()
			expect((ev :: Instance):IsA("RemoteEvent")).to.equal(true)
			expect((fn :: Instance):IsA("RemoteFunction")).to.equal(true)
		end)
	end)
end