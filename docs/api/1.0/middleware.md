# Middleware <Badge type="tip" text="feature" />

::: code-group
```lua [Server]
local Event1 = Warp.Server("Remote1")

local storeC = Event1:Connect(function(player: Player, arg1: string, arg2: number, arg3: boolean)
    print(player, arg1, arg2, arg3)
end):middleware(function(player: Player, arg1: string, arg2: number, arg3: boolean)
    assert(type(player) == "userdata" and player:IsA("Player"), "player must be a Player.")
    assert(typeof(arg1) == "string", "arg1 must be a string.")
    assert(typeof(arg2) == "number", "arg2 must be a number.")
    assert(typeof(arg3) == "boolean", "arg3 must be a boolean.")
end)

print(storeC:key())

task.delay(15, function()
    Event1:Disconnect(storeC:key())
end)

for _=1,5 do
    print("send incorrect values")
    Event1:Fires(true, 1e9, "hello world!")
    task.wait(0.5)
end

for _=1,5 do
    print("send correct values")
    Event1:Fires(true, "hello world!", 1e9)
    task.wait(0.5)
end
```

```lua [Client]
local Event1 = Warp.Client("Remote1")

local storeC = Event1:Connect(function(arg1: boolean, arg2: string, arg3: number)
    print(arg1, arg2, arg3)
end):middleware(function(arg1: boolean, arg2: string, arg3: number)
    assert(typeof(arg1) == "boolean", "arg1 must be a boolean.")
    assert(typeof(arg2) == "string", "arg2 must be a string.")
    assert(typeof(arg3) == "number", "arg3 must be a number.")
end)

print(storeC:key())

task.delay(15, function()
    Event1:Disconnect(storeC:key())
end)

for _=1,5 do
    print("send incorrect values")
    Event1:Fires("hello world!", false, 1e9)
    task.wait(0.5)
end

for _=1,5 do
    print("send correct values")
    Event1:Fires("hello world!", 1e9, false)
    task.wait(0.5)
end
```
:::