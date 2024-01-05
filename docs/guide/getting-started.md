# Getting Started

### `Step 1:`
First, you have to require the Warp module.

```lua
local Warp = require('path.to.module');
```

### `Step 2:`
Then, to create a new event you have to use `.Server` function

```lua
local Remote = Warp.Server("EventName");
```

### `Step 3:`
Firing event everytime player join

```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    Remote:Fire(true, player, "Welcome!")
end)
```