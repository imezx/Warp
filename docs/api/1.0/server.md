# Server <Badge type="tip" text="event" />

For Server-sided

## `.Server` <Badge type="warning" text="yield" />

Create new Warp event.

::: code-group
```luau [Variable]
(
	Identifier: string,
	rateLimit: {
		maxEntrance: number?,
		interval: number?,
	}?
)
```

```luau [Example]
local Remote = Warp.Server("Remote")
```
:::

## `.fromServerArray` <Badge type="warning" text="yield" />

Create new Warp events with array.

::: code-group
```luau [Variable]
(
	{ any }
)
```

```luau [Example]
local Events = Warp.fromServerArray({
	["Remote1"] = {
		rateLimit = {
			maxEntrance: 50,
			interval: 1,
		}
	}, -- with rateLimit configuration
	"Remote2", -- without rateLimit configuration
	["Remote3"] = {
		rateLimit = {
			maxEntrance: 10,
		}
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
```luau [Variable]
(
	player: Player,
	callback: (...any) -> ()
): string
```

```luau [Example]
Remote:Connect(function(player, ...)
	print(player, ...)
end)
```
:::

## `:Once`

This function likely `:Connect` but it disconnect the event once it fired.

::: code-group
```luau [Variable]
(
	player: Player,
	callback: (...any) -> ()
)
```

```luau [Example]
Remote:Once(function(player, ...)
	print(player, ...)
end)
```
:::

## `:Disconnect`

Disconnect the event connection.

::: code-group
```luau [Variable]
(
	key: string
): boolean
```

```luau [Example]
local connection = Remote:Connect(function(player, ...) end) -- store the key

Remote:Disconnect(connection)
```
:::

## `:DisconnectAll`

Disconnect All the event connection.

```luau [Example]
Remote:DisconnectAll()
```

## `:Fire`

Fire the event to a client.

::: code-group
```luau [Variable]
(
	reliable: boolean,
    player: Player,
	...: any
)
```

```luau [Example]
Remote:Fire(true, player, "Hello World!")
```
:::

## `:Fires` <Badge type="tip" text="Server Only" />

Fire the event to all clients.

::: code-group
```luau [Variable]
(
	reliable: boolean,
	...: any
)
```

```luau [Example]
Remote:Fires(true, "Hello World!")
```
:::

## `:FireExcept` <Badge type="tip" text="Server Only" />

Fire the event to all clients but except a players.

::: code-group
```luau [Variable]
(
	reliable: boolean,
	except: { Player },
	...: any
)
```

```luau [Example]
Remote:FireExcept(true, { Players.Eternity_Devs, Players.Player2 }, "Hello World!") -- this will sent to all players except { Players.Eternity_Devs, Players.Player2 }.
```
:::

## `:Invoke` <Badge type="warning" text="yield" />

Semiliar to `:InvokeClient`,  but it have timeout system that not exists on `RemoteFunction.InvokeClient`.

::: code-group
```luau [Variable]
(
	timeout: number,
    player: Player,
	...: any
) -> (...any)
```

```luau [Example]
local Request = Remote:Invoke(2, player, "Hello World!")
```
:::

::: warning
This function is yielded, once it timeout it will return nil.
:::

## `:Wait` <Badge type="warning" text="yield" />

Wait the event being triggered.

```lua
Remote:Wait() -- :Wait return number value
```

::: warning
This function is yielded, Invoke might also ping this one and also causing error.
:::

## `:Destroy`

Disconnect all connection of event and remove the event from Warp.

```lua
Remote:Destroy()
```