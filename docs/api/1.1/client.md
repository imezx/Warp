# Client <Badge type="tip" text="1.1" />

For Client-sided operations.

## Getting the Client Object

```lua
local Client = Warp.Client()
```

## `.Connect`

Connect to an event to receive incoming data from the server.

::: code-group
```lua [Variable]
(
	remoteName: string,
	fn: (...any) -> ...any
) -> Connection
```

```lua [Example]
local connection = Client.Connect("ServerNotify", function(message, sender)
	print(`Server message from {sender}: {message}`)
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
	fn: (...any) -> ...any
) -> Connection
```

```lua [Example]
Client.Once("WelcomeMessage", function(welcomeText)
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
local elapsed, message = Client.Wait("ServerMessage")
print(`Received message after {elapsed} seconds: {message}`)
```
:::

## `.Disconnect`

Disconnect the event connection.

::: code-group
```lua [Variable]
()
```

```lua [Example]
local connection = Client.Connect("ServerNotify", function(message, sender)
	print(`Server message from {sender}: {message}`)
	-- Disconnect the connection
	connection:Disconnect()
end)
print(Connection.Connected)
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
Client.DisconnectAll("ServerNotify")
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
Client.Destroy("ServerNotify")
```
:::

## `.Fire`

Fire an event to the server.

::: code-group
```lua [Variable]
(
	remoteName: string,
	reliable: boolean,
	...: any
)
```

```lua [Example]
-- (TCP) Reliable event (guaranteed delivery)
Client.Fire("PlayerAction", true, "jump", playerPosition)

-- (UDP) Unreliable event (faster but not guaranteed)
Client.Fire("PositionUpdate", false, currentPosition)
```
:::

## `.Invoke` <Badge type="warning" text="yield" />

Invoke the server with timeout support.

::: code-group
```lua [Variable]
(
	remoteName: string,
	timeout: number?,
	...: any
) -> ...any
```

```lua [Example]
local Client = Warp.Client()
local response = Client.Invoke("RequestData", 3, "playerStats")
if response then
	print("Server responded:", response)
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
local Client = Warp.Client()

-- Define a schema for position updates
local positionSchema = Client.Schema.struct({
	x = Client.Schema.f32,
	y = Client.Schema.f32,
	z = Client.Schema.f32,
	timestamp = Client.Schema.u32
})
-- Define a schema for data updates
local dataSchema = Client.Schema.struct({
	Coins = Client.Schema.u32,
	Level = Client.Schema.u8,
	Inventory = Client.Schema.array(Client.Schema.u32),
	Settings = Client.Schema.struct({
		VFX = Client.Schema.boolean,
		Volume = Client.Schema.f32,
		Language = Client.Schema.string,
	})
})

-- Now this event will use the schema
Client.useSchema("DataReplication", dataSchema)
Client.useSchema("PositionUpdate", positionSchema)
Client.Connect("PositionUpdate", function(x, y, z, timestamp)
	-- Data is automatically deserialized according to schema
	updatePlayerPosition(x, y, z)
end)
```
:::

## `.Schema`

Access to Buffer.Schema for creating data schemas.
