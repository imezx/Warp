# Example

Let's try and play something with Warp!

::: code-group
```lua [Server]
local Warp = require("path.to.module")

-- Events
local Example = Warp.Server("Example")
local Ping = Warp.Server("Ping")
local Pong = Warp.Server("Pong")
local PingAll = Warp.Server("PingAll")

Example:Connect(function(player, arg1, arg2)
    print(arg1, arg2)
    return "Whooo!"
end)

Ping:Connect(function(player, ping)
    if ping then
        print("PING!")
        Pong:Fire(true, player, "pong!")
        PingAll:Fires(true, "ey!")
    end
end)
```

```lua [Client]
local Players = game:GetService("Players")
local Warp = require("path.to.module")

-- Events
local Example = Warp.Client("Example")
local Ping = Warp.Client("Ping")
local Pong = Warp.Client("Pong")
local PingAll = Warp.Client("PingAll")

-- Connect the events
local connection1
connection1 = Pong:Connect(function(pong: boolean)
    if pong then
        print("PONG!")
    end
end)

PingAll:Connect(function(isPing: boolean)
    if isPing then
        print("I GET PINGED!")
    end
end)

-- Try request a event from server!
print(Example:Invoke(5, "Hello!", "this is from > "..Players.LocalPlayer.Name))
-- Do a ping & pong to server!
Ping:Fire(true, "ping!")

task.wait(1) -- lets wait 1 seconds!

-- Disconnect All the events
Pong:DisconnectAll()
PingAll:DisconnectAll()
-- or Just disconnect spesific connection
Pong:Disconnect(connection1)

-- Destroying/Deleting a Event?
Pong:Destroy()

-- Yay Done!
```
:::