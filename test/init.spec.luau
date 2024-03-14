return function()
	local Warp = require(game:GetService("ReplicatedStorage").Warp)

    describe("Warp.Server", function()
        it("should be able to create a new server event", function()
            local test = Warp.Server("Test")
            expect(test).to.be.ok()
        end)

        it("should be able to create a new server event with ratelimit configuration", function()
            local test = Warp.Server("Test", {
                maxEntrance = 10,
                interval = 1,
            })
            expect(test).to.be.ok()
        end)
    end)

    describe("Warp.fromServerArray", function()
        it("should be able to create a new server event with arrays", function()
            local test = Warp.fromServerArray({
                "Test1",
                "Test2",
            })
            expect(test).to.be.ok()
            expect(test.Test1).to.be.ok()
            expect(test.Test2).to.be.ok()
        end)

        it("should be able to create a new server event with arrays & ratelimit configuration", function()
            local test = Warp.fromServerArray({
                "Test1",
                "Test2",
                ["Test3"] = {
                    maxEntrance = 10,
                    interval = 0.75,
                },
            })
            expect(test).to.be.ok()
            expect(test.Test1).to.be.ok()
            expect(test.Test2).to.be.ok()
            expect(test.Test3).to.be.ok()
        end)
    end)

    describe("Event.Connect", function()
        it("should be able to connect the event", function()
            local test = Warp.Server("Test")
            test:Connect(function() end)
            expect(test.IsConnected).to.be.ok()
        end)
    end)

    describe("Multi Event.Connect", function()
        it("should be able to multiple connect the event", function()
            local test = Warp.Server("Test")
            test:Connect(function() end)
            test:Connect(function() end)
            expect(test.IsConnected).to.be.ok()
        end)
    end)

    describe("Event.DisconnectAll", function()
        it("should be able to disconnect all the event connections", function()
            local test = Warp.Server("Test")
            test:DisconnectAll()
            expect(#test.fn).to.equal(0)
        end)
    end)

    describe("Event.Disconnect", function()
        it("should be able to disconnect the event connection", function()
            local test = Warp.Server("Test")
            local connection = test:Connect(function() end)
            expect(test:Disconnect(connection)).to.be.ok()
        end)
    end)

    describe("Warp.Signal", function()
        it("should be able to create a new signal", function()
            local test = Warp.Signal("Test")
            expect(test).to.be.ok()
        end)
    end)

    describe("Warp.fromSignalArray", function()
        it("should be able to create a new signal with arrays", function()
            local test = Warp.fromSignalArray({
                "Test1",
                "Test2"
            })
            expect(test).to.be.ok()
            expect(test.Test1).to.be.ok()
            expect(test.Test2).to.be.ok()
        end)
    end)

    describe("Signal.Connect", function()
        it("should be able to connect the signal", function()
            local test = Warp.Signal("Test")
            expect(test:Connect(function() end)).to.be.ok()
            test:DisconnectAll()
        end)
    end)

    describe("Multi Signal.Connect", function()
        it("should be able to multiple connect the signal", function()
            local test = Warp.Signal("Test")
            expect(test:Connect(function() end)).to.be.ok()
            expect(test:Connect(function() end)).to.be.ok()
            test:DisconnectAll()
        end)
    end)

    describe("Signal.Fire", function()
        it("should be able to fire the signal", function()
            local test = Warp.Signal("Test")
            test:Once(function(arg)
                expect(arg).to.equal("hello world!")
            end)
            test:Fire("hello world!")
        end)
    end)

    describe("Signal.Invoke", function()
        it("should be able to invoke the signal", function()
            local test = Warp.Signal("Test")
            local connection = test:Connect(function(arg)
                if arg ~= "test" then
                    return
                end
                return "hello world!"
            end)
            local receive = test:Invoke(connection, "test")
            expect(receive).to.equal("hello world!")
        end)
    end)

    describe("Signal.InvokeTo", function()
        it("should be able to invoke to a signal", function()
            local test = Warp.Signal("Test")
            local test2 = Warp.Signal("Test2")
            local connection = test2:Connect(function(arg)
                if arg ~= "test" then
                    return
                end
                return "hello world!"
            end)
            local receive = test:InvokeTo("Test2", connection, "test")
            expect(receive).to.equal("hello world!")
        end)
    end)

    describe("Signal.Wait", function()
        it("should be able to wait for the signal", function()
            local test = Warp.Signal("Test")
            test:Connect(function() end)
            task.spawn(function()
                local time =  test:Wait()
                expect(time).to.be.ok()
                expect(time).to.be.a("number")
            end)
            test:Fire()
        end)
    end)
end