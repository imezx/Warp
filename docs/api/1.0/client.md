# Client

For Client-sided

## `.Client`

Create new Warp event.

::: code-group
```lua [Variable]
(
	Identifier: string
)
```

```lua [Example]
local Remote = Warp.new("Remote")
```
:::

## `:Connect`

Connect event to receive incoming from server way.

::: code-group
```lua [Variable]
(
	callback: (...any) -> ()
)
```

```lua [Example]
Remote:Connect(function(...)
	print(...)
end)
```
:::

## `:Once`

This function likely `:Connect` but it disconnect the event once it fired.

::: code-group
```lua [Variable]
(
	callback: (...any) -> ()
)
```

```lua [Example]
Remote:Once(function(...)
	print(...)
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

Fire the event to the spesific server with data.

::: code-group
```lua [Variable]
(
	reliable: boolean,
	...: any
)
```

```lua [Example]
Remote:Fire(true, "Hello World!")
```
:::

::: warning
This function have rate limiting it self and configured from server.
:::

## `:Invoke`

Semiliar to `:InvokeServer`, its for Invoke to a server.

::: code-group
```lua [Variable]
(
	timeout: number,
	...: any
) -> (...any)
```

```lua [Example]
local Request = Remote:Invoke(2, "Hello World!")
```
:::

::: warning
This function is yielded, once it timeout it will return nil.
:::

## `:Wait`

Wait the event being triggered.

```lua
Remote:Wait()
```

::: warning
This function is yielded, Invoke might also ping this one and also causing error.
:::

## `:Destroy`

Disconnect all connection of event and remove the event from Warp

```lua
Remote:Destroy()
```