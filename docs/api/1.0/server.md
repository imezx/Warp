# Server

For Server-sided

## `.Server` <Badge type="warning" text="yield" />

Create new Warp event.

::: code-group
```lua [Variable]
(
	Identifier: string,
	rateLimit: {
		maxEntrance: number,
		interval: number,
	}?
)
```

```lua [Example]
local Remote = Warp.Server("Remote")
```
:::

## `.fromServerArray` <Badge type="warning" text="yield" />

Create new Warp events with array.

::: code-group
```lua [Variable]
(
	{ any }
)
```

```lua [Example]
local Events = Warp.fromServerArray({
	["Remote1"] = {
		maxEntrance: 50,
		interval: 1,
	}, -- with rateLimit configuration
	"Remote2", -- without rateLimit configuration
	["Remote3"] = {
		maxEntrance: 10,
	}, -- with rateLimit configuration
})

-- Usage
Events.Remote1:Connect(function(player, ...) end)
Events.Remote2:Connect(function(player, ...) end)
Events.Remote3:Connect(function(player, ...) end)
```
:::
## `:Connect`

Connect event to receive incoming from client way.

::: code-group
```lua [Variable]
(
	player: Player,
	callback: (...any) -> ()
): string
```

```lua [Example]
Remote:Connect(function(player, ...)
	print(player, ...)
end)
```
:::

## `:Once`

This function likely `:Connect` but it disconnect the event once it fired.

::: code-group
```lua [Variable]
(
	player: Player,
	callback: (...any) -> ()
)
```

```lua [Example]
Remote:Once(function(player, ...)
	print(player, ...)
end)
```
:::

## `:Disconnect`

Disconnect the event connection.

::: code-group
```lua [Variable]
(
	key: string
)
```

```lua [Example]
local connection = Remote:Connect(function(player, ...) end) -- store the key

Remote:Disconnect(connection)
```
:::

## `:DisconnectAll`

Disconnect All the event connection.

```lua [Example]
Remote:DisconnectAll()
```

## `:Fire`

Fire the event to a client.

::: code-group
```lua [Variable]
(
	reliable: boolean,
    player: Player,
	...: any
)
```

```lua [Example]
Remote:Fire(true, player, "Hello World!")
```
:::

## `:Fires` <Badge type="tip" text="Server Only" />

Fire the event to all clients.

::: code-group
```lua [Variable]
(
	reliable: boolean,
	...: any
)
```

```lua [Example]
Remote:Fires(true, "Hello World!")
```
:::

## `:Invoke` <Badge type="warning" text="yield" />

Semiliar to `:InvokeClient`, its for Invoke to a client.

::: code-group
```lua [Variable]
(
	timeout: number,
    player: Player,
	...: any
) -> (...any)
```

```lua [Example]
local Request = Remote:Invoke(2, player, "Hello World!")
```
:::

::: warning
This function is yielded, once it timeout it will return nil.
:::

## `:Wait` <Badge type="warning" text="yield" />

Wait the event being triggered.

```lua
Remote:Wait()
```

::: warning
This function is yielded, Invoke might also ping this one and also causing error.
:::

## `:Destroy`

Disconnect all connection of event and remove the event from Warp.

```lua
Remote:Destroy()
```