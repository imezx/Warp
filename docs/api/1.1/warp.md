# Warp <Badge type="tip" text="1.1" /> <Badge type="warning" text="pre-release" />

The public main of the Warp library.
::: warning
This version (1.1.x) is not backward compatible with 1.0.x.
:::

## `.Server` <Badge type="tip" text="server side" />

Get the Server operation for server-side.

```lua
-- Server
local Server = Warp.Server()
```

## `.Client` <Badge type="tip" text="client side" />

Get the Client operation for client-side.

```lua
-- Client
local Client = Warp.Client()
```

## `.Buffer` <Badge type="tip" text="universal" />

Get the Buffer util for schema definition.

```lua
-- Universal (Server & Client)
local Buffer = Warp.Buffer()
local schema = Buffer.Schema
```