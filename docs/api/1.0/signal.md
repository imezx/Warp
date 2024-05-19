# Signal <Badge type="tip" text="utilities" />

A alternative of BindableEvent.

## `.Signal`

Create new Signal.

::: code-group
```lua [Variable]
(
	Identifier: string
)
```

```lua [Example]
local Signal1 = Warp.Signal("Signal1")
```
:::

## `.fromSignalArray`

Create new Signal.

::: code-group
```lua [Variable]
(
    { string }
)
```

```lua [Example]
local Signals = Warp.fromSignalArray({"Signal1", "Signal2"})
Signals.Signal1:Connect(function(...) end)
Signals.Signal2:Connect(function(...) end)
```
:::

## `:Connect`

::: code-group
```lua [Variable]
(
	callback: (...any) -> ()
)
```

```lua [Example]
Signal1:Connect(function(...)
	print(...)
end)
```
:::

## `:Once`

This function likely `:Connect` but it disconnect the signal once it fired.

::: code-group
```lua [Variable]
(
	callback: (...any) -> ()
)
```

```lua [Example]
Signal1:Once(function(...)
	print(...)
end)
```
:::

## `:Disconnect`

Disconnect the signal connection.

::: code-group
```lua [Variable]
(
	key: string
)
```

```lua [Example]
local connection = Signal1:Connect(function(...) end) -- store the key

Signal1:Disconnect(connection)
```
:::

::: warning
This requires `key` to disconnect a signal connection.
:::

## `:DisconnectAll`

Disconnect All signal connections.

```lua [Example]
Signal1:DisconnectAll()
```

## `:Fire`

Fire the signal (Immediate)

::: code-group
```lua [Variable]
(
	...: any
)
```

```lua [Example]
Signal1:Fire("Hello World!")
```
:::

## `:DeferFire`

Fire the signal (Deferred)

::: code-group
```lua [Variable]
(
	...: any
)
```

```lua [Example]
Signal1:Fire("Hello World!")
```
:::

::: warning
This uses `pcall`, which means it never error (safe-mode, sacrificed debugging), But gains performance here `(upto 5x faster)`.
:::

## `:FireTo`

Fire to other signal, this uses `:Fire`.

::: code-group
```lua [Variable]
(
    signal: string,
	...: any
)
```

```lua [Example]
Signals.Signal1:FireTo("Signal2", "Hello World!")
```
:::

::: warning
This requires `key`.
:::

## `:Invoke` <Badge type="warning" text="yield" />

::: code-group
```lua [Variable]
(
    key: string,
	...: any
) -> (...any)
```

```lua [Example]
local connection = Signal1:Conenct(function(...) return "hey!" end)
local Request = Signal1:Invoke(connection, "Hello World!")
```
:::

## `:InvokeTo` <Badge type="warning" text="yield" />

this use `:Invoke`.

::: code-group
```lua [Variable]
(
    signal: string,
    key: string,
	...: any
) -> (...any)
```

```lua [Example]
local connection2 = Signals.Signal2:Conenct(function(...) return "hey!" end)
local Request = Signals.Signal1:Invoke("Signal2", connection2, "Hello World!")
```
:::

::: warning
This requires `key`.
:::

## `:Wait` <Badge type="warning" text="yield" />

Wait the signal get triggered.

```lua
Signal1:Wait() -- return number (time)
```

::: warning
This function is yielded
:::

## `:Destroy`

Disconnect all connection of signal and remove the signal from Signals

```lua
Signal1:Destroy()
```