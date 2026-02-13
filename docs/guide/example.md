# Example <Badge type="tip" text="1.1" />

Let's try and play something with Warp!

::: code-group
```luau [Schemas]
local Schema = require(path.to.warp).Buffer.Schema

return {
    Example = Schema.array(Schema.string()),
    Ping = Schema.string(),
    Pong = Schema.string(),
    PingAll = Schema.string(),
}
```
```luau [Server]
local Warp = require(path.to.warp).Server()
local Schemas = require(path.to.schemas)

-- Use schemas
for eventName, schema in Schemas do
    Warp.useSchema(eventName, schema)
end

Warp.Connect("Example", function(player, arg)
    print(table.unpack(arg))
    return "Hey!"
end)
Warp.Connect("Ping", function(player, ping)
    if ping then
        print("PING!")
        Warp.Fire("Pong", true, player, "pong!") -- Fire to spesific player through reliable event
        Warp.Fire("PingAll", true, "ey!") -- Fire to all clients through reliable event
    end
end)
```

```luau [Client]
local Players = game:GetService("Players")
local Warp = require(path.to.warp).Client()
local Schemas = require(path.to.schemas)

-- Use schemas
for eventName, schema in Schemas do
    Warp.useSchema(eventName, schema)
end

-- Connect the events
local connection1
connection1 = Warp.Connect("Pong", function(pong: boolean) -- we store the connection so we can disconnect it later
    if pong then
        print("PONG!")
    end
end)
Warp.Connect("PingAll", function(isPing: boolean)
    if isPing then
        print("I GET PINGED!")
    end
end)

-- Try request a event from server!
print(Warp.Invoke("Example", 1, { "Hello!", `this is from: @{Players.LocalPlayer.Name}` }))
-- Do a ping & pong to server!
Warp.Fire("Ping", true, "ping!") -- we send through reliable event

task.wait(1) -- lets wait 1 seconds!

-- Disconnect All the events
connection1:DisconnectAll()
-- or just disconnect spesific connection
Warp.Disconnect("PingAll")

-- Destroying/Deleting a Event?
Warp.Destroy("Pong")
```
:::