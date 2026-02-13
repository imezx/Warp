# Signal <Badge type="tip" text="utilities" />

A alternative of BindableEvent.

## `.Signal`

Create new Signal.

::: code-group
```luau [Variable]
(
	Identifier: string
)
```

```luau [Example]
local Signal1 = Warp.Signal("Signal1")
```
:::

## `.fromSignalArray`

Create new Signal.

::: code-group
```luau [Variable]
(
    { string }
)
```

```luau [Example]
local Signals = Warp.fromSignalArray({"Signal1", "Signal2"})
Signals.Signal1:Connect(function(...) end)
Signals.Signal2:Connect(function(...) end)
```
:::

## `:Connect`

::: code-group
```luau [Variable]
(
	callback: (...any) -> ()
)
```

```luau [Example]
Signal1:Connect(function(...)
	print(...)
end)
```
:::

## `:Once`

This function likely `:Connect` but it disconnect the signal once it fired.

::: code-group
```luau [Variable]
(
	callback: (...any) -> ()
)
```

```luau [Example]
Signal1:Once(function(...)
	print(...)
end)
```
:::

## `:Disconnect`

Disconnect the signal connection.

::: code-group
```luau [Variable]
(
	key: string
)
```

```luau [Example]
local connection = Signal1:Connect(function(...) end) -- store the key

Signal1:Disconnect(connection)
```
:::

::: warning
This requires `key` to disconnect a signal connection.
:::

## `:DisconnectAll`

Disconnect All signal connections.

```luau [Example]
Signal1:DisconnectAll()
```

## `:Fire`

Fire the signal (Immediate)

::: code-group
```luau [Variable]
(
	...: any
)
```

```luau [Example]
Signal1:Fire("Hello World!")
```
:::

## `:DeferFire`

Fire the signal (Deferred)

::: code-group
```luau [Variable]
(
	...: any
)
```

```luau [Example]
Signal1:Fire("Hello World!")
```
:::

::: warning
This uses `pcall`, which means it never error (safe-mode, sacrificed debugging), But gains performance here `(upto 5x faster)`.
:::

## `:FireTo`

Fire to other signal, this uses `:Fire`.

::: code-group
```luau [Variable]
(
    signal: string,
	...: any
)
```

```luau [Example]
Signals.Signal1:FireTo("Signal2", "Hello World!")
```
:::

::: warning
This requires `key`.
:::

## `:Invoke` <Badge type="warning" text="yield" />

::: code-group
```luau [Variable]
(
    key: string,
	...: any
) -> (...any)
```

```luau [Example]
local connection = Signal1:Conenct(function(...) return "hey!" end)
local Request = Signal1:Invoke(connection, "Hello World!")
```
:::

## `:InvokeTo` <Badge type="warning" text="yield" />

this use `:Invoke`.

::: code-group
```luau [Variable]
(
    signal: string,
    key: string,
	...: any
) -> (...any)
```

```luau [Example]
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