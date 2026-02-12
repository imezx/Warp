# Getting Started <Badge type="tip" text="1.1" />

### `Installation`
First, you have to require the Warp module.

```lua
local Warp = require(path.to.module)
```

Then, you should do `.Server` or `.Client`

```lua
local Server = Warp.Server() --> for Server-side only
local Client = Warp.Client() --> for Client-side only
```

### `Basic Usage`
Firing event everytime player join

```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player: Player)
    Server.Fire("MessageEvent", true, player, "Welcome!")
end)
```
Add a listener (works for both `.Invoke` & `.Fire`)

```lua
local connection = Server.Connect("Ping", function(player: Player)
    return "Pong"
end)
print(connection.Connected)
-- connection:Disconnect()
```
Send or Request a event

```lua
-- Reliable-RemoteEvent
Client.Fire("test", true, "hey")
-- Unreliable-RemoteEvent
Client.Fire("test", false, "hello from client!!")
-- Invoke
local response = Client.Invoke("Ping")
if not response then
    warn("Server didn't ping back :(")
    return
end
print(response, "from Server!")
```