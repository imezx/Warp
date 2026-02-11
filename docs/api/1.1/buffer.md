# Buffer <Badge type="tip" text="module" />

For efficient data serialization and schema definition with optimized packing.

## Getting the Buffer Object

```lua
local Buffer = Warp.Buffer()
```

## Schema System <Badge type="tip" text="v1.1" />

Define strict data schemas for optimized serialization and type safety.

### Available Schema Types

```lua
{
	-- Basic types
	"boolean",
	"string",
	"nil",
	
	-- Numeric types
	"uint8",
	"uint16", 
	"uint32",
	"int8",
	"int16",
	"int32",
	"float32",
	"float64",
	
	-- Roblox types
	"buffer"
	"Vector2",
	"Vector3",
	"CFrame",
	"Color3",
	"BrickColor",
	"Instance",
	"EnumItem",
	"Enum",
	"UDim2",
	"UDim",
	"Rect",
	"NumberRange",
	"Ray",
	"ColorSequence",
	"NumberSequence",
}
```

## Writer and Reader Functions

### `.createWriter`

Create a new buffer writer for serializing data.

::: code-group
```lua [Variable]
(
	capacity: number? -- Optional initial capacity (default: 64)
): Writer
```

```lua [Example]
local Buffer = Warp.Buffer()
local writer = Buffer.createWriter(256) -- Pre-allocate 256 bytes
```
:::

### `.build`

Build the final buffer for transmission.

::: code-group
```lua [Variable]
(
	writer: Writer
): buffer -- Returns buffer
```

```lua [Example]
local Buffer = Warp.Buffer()
local writer = Buffer.createWriter()

-- Write some data
Buffer.packValue(writer, "Hello World")
Buffer.packValue(writer, 12345)

-- Build final buffer
local finalBuffer = Buffer.build(writer)
print(buffer.len(finalBuffer))
```
:::

### `.buildWithRefs`

Build the final buffer with instance references for transmission.

::: code-group
```lua [Variable]
(
	writer: Writer
): (buffer, { Instance }?) -- Returns buffer and optional instance references
```

```lua [Example]
local Buffer = Warp.Buffer()
local writer = Buffer.createWriter()

-- Write some data with instances
Buffer.packValue(writer, workspace.Part)
Buffer.packValue(writer, game.Players.LocalPlayer)

-- Build final buffer
local finalBuffer, refs = Buffer.buildWithRefs(writer)
print(buffer.len(finalBuffer), refs)
```
:::

### `.reset`

Reset a writer for reuse, clearing all data.

::: code-group
```lua [Variable]
(
	writer: Writer
)
```

```lua [Example]
local Buffer = Warp.Buffer()
local writer = Buffer.createWriter()

-- Use writer for first batch
Buffer.writeEvents(writer, events1)
local buffer1 = Buffer.build(writer)

-- Reset and reuse for second batch
Buffer.reset(writer)
Buffer.writeEvents(writer, events2)
local buffer2 = Buffer.build(writer)
```
:::
