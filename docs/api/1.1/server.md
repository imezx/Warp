# Server <Badge type="tip" text="1.1" />

For Server-sided operations.

## Getting the Server Object

```lua
local Server = Warp.Server()
```

## `.Connect`

Connect to an event to receive incoming data from clients.

::: code-group
```lua [Variable]
(
	remoteName: string,
	fn: (player: Player, ...any) -> ...any
) -> Connection
```

```lua [Example]
local connection = Server.Connect("ServerNotify", function(player, message)
	print(`Client message from {player}: {message}`)
end)
print(connection.Connected)
```
:::

## `.Once`

Similar to `:Connect` but automatically disconnects after the first firing.

::: code-group
```lua [Variable]
(
	remoteName: string,
	fn: (player: Player, ...any) -> ...any
) -> Connection
```

```lua [Example]
Server.Once("WelcomeMessage", function(welcomeText)
	print(`Welcome: {welcomeText}`)
end)
```
:::

## `.Wait` <Badge type="warning" text="yield" />

Wait for an event to be triggered.

::: code-group
```lua [Variable]
(
	remoteName: string
) -> (number, ...any)
```

```lua [Example]
local elapsed, message = Server.Wait("ServerMessage")
print(`Received message after {elapsed} seconds: {message}`)
```
:::

## `.DisconnectAll`

Disconnect all connections for a specific event.

::: code-group
```lua [Variable]
(
	remoteName: string
)
```

```lua [Example]
Server.DisconnectAll("ServerNotify")
```
:::

## `.Destroy`

Disconnect all connections and remove the event.

::: code-group
```lua [Variable]
(
	remoteName: string
)
```

```lua [Example]
Server.Destroy("ServerNotify")
```
:::

## `.Fire`

Fire an event to a specific player.

::: code-group
```lua [Variable]
(
	remoteName: string,
	reliable: boolean,
	player: Player,
	...: any
)
```

```lua [Example]
Server.Fire("ServerNotify", true, player, "Hello from server!")
```
:::

## `.Fires`

Fire an event to all connected players.

::: code-group
```lua [Variable]
(
	remoteName: string,
	reliable: boolean,
	...: any
)
```

```lua [Example]
Server.Fires("Broadcast", true, "Server announcement!")
```
:::

## `.FireExcept`

Fire an event to all players except specified ones.

::: code-group
```lua [Variable]
(
	remoteName: string,
	reliable: boolean,
	except: { Player },
	...: any
)
```

```lua [Example]
local excludedPlayers = { player1, player2 }
Server.FireExcept("Update", true, excludedPlayers, "Game update")
```
:::

## `.Invoke` <Badge type="warning" text="yield" />

Invoke a client with timeout support.

::: code-group
```lua [Variable]
(
	remoteName: string,
	player: Player,
	timeout: number?,
	...: any
) -> ...any
```

```lua [Example]
local response = Server.Invoke("RequestData", player, 3, "userInfo")
if response then
	print("Client responded:", response)
else
	print("Request timed out")
end
```
:::

::: warning
This function is yielded. Returns `nil` if timeout occurs.
:::

## `.useSchema`

Define a schema for strict data packing on a specific event.

::: code-group
```lua [Variable]
(
	remoteName: string,
	schema: Buffer.SchemaType
)
```

```lua [Example]
local Server = Warp.Server()

local dataSchema = Server.Schema.struct({
	Coins = Server.Schema.u32,
	Level = Server.Schema.u8,
	Inventory = Server.Schema.array(Server.Schema.u32),
	Settings = Server.Schema.struct({
		VFX = Server.Schema.boolean,
		Volume = Server.Schema.f32,
		Language = Server.Schema.string,
	})
})

Server.useSchema("DataReplication", dataSchema)
```
:::

## `.Schema`

Access to Buffer.Schema for creating data schemas.
