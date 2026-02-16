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
	"u8",
	"u16", 
	"u32",
	"i8",
	"i16",
	"i32",
	"f16",
	"f32",
	"f64",
	
	-- Roblox types
	"buffer"
	"vector2",
	"vector3",
	"cframe",
	"color3", -- u8
	"color3f16",
	"instance",

	-- other types
	"optional",
	"array",
	"map",
	"struct",
}
```

## Custom Datatypes

### `.custom_datatype`

::: code-group
```luau [Variable]
(
	name: string,
	object: { any },
	writer: (w: Writer, v: any) -> (),
	reader: (b: buffer, c: number, refs: { Instance }?) -> (buffer, number))
): Writer
```

```luau [Example]
local Buffer = Warp.Buffer()

-- # this custom datatype must be registered on both server & client side
Buffer.Schema.custom_datatype("u64", {}, function(writer, value)
	-- writing u64 logics here
end, function(b, cursor, refs)
	-- reading u64 logics here
	return b, cursor
end)

local DataSchema = Buffer.Schema.struct({
	LongInteger = Buffer.Schema.u64, -- use the custom datatype
})
```
:::

## Writer and Reader Functions

### `.createWriter`

Create a new buffer writer for serializing data.

::: code-group
```luau [Variable]
(
	capacity: number? -- Optional initial capacity (default: 64)
): Writer
```

```luau [Example]
local Buffer = Warp.Buffer()
local writer = Buffer.createWriter(256) -- Pre-allocate 256 bytes
```
:::

### `.build`

Build the final buffer for transmission.

::: code-group
```luau [Variable]
(
	writer: Writer
): buffer -- Returns buffer
```

```luau [Example]
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
```luau [Variable]
(
	writer: Writer
): (buffer, { Instance }?) -- Returns buffer and optional instance references
```

```luau [Example]
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
```luau [Variable]
(
	writer: Writer
)
```

```luau [Example]
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
