# Buffer <Badge type="tip" text="module" />

For efficient data serialization and schema definition with optimized packing.

## Getting the Buffer Object

```lua
local Buffer = Warp.Buffer
```

## Schema System <Badge type="tip" text="v1.1" />

Define strict data schemas for optimized serialization and type safety.

### Available Schema Types

```lua
{
	-- Basic types
	"boolean",
	"string",
	
	-- Numeric types
	"u8", -- unsigned-int
	"u16",
	"u32",
	"i8", -- signed-int
	"i16",
	"i32",
	"f16", -- floating-point
	"f32",
	"f64",
	
	-- Roblox types
	"buffer",
	"vector2", -- f16 x/y
	"vector3", -- f16 x/y/z
	"vector2int16", -- i16 x/y
	"vector3int16", -- i16 x/y/z
	"cframe", -- f32 position + compressed rotation (f16)
	"color3", -- u8 r/g/b
	"color3f16",
	"udim",
	"udim2",
	"rect",
	"ray",
	"numberrange",
	"colorsequence",
	"numbersequence",
	"brickcolor",
	"tweeninfo",
	"physicalproperties",
	"font",
	"datetime",
	"instance",

	-- other types
	"optional",
	"array",
	"map",
	"struct",
}
```

::: info
there is no standalone `"nil"` schema type. To represent a value that can be `nil`, wrap it with `"optional"` (e.g. `Buffer.Schema.optional(Buffer.Schema.u16)`).
:::

## Custom Datatypes

### `.custom_datatype`

::: code-group
```luau [Variable]
(
	name: string,
	object: { any },
	writer: (w: Writer, v: any) -> (),
	reader: (b: buffer, c: number, refs: { Instance }?) -> (buffer, number))
)
```

```luau [Example]
local Buffer = Warp.Buffer

-- # this custom datatype must be registered on both server & client side
Buffer.Schema.custom_datatype("u64", {}, function(w: Buffer.Writer, value: any) -- just for reference
	-- writing u64 logics here
end, function(b: buffer, cursor: number, refs)
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
local Buffer = Warp.Buffer
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
local Buffer = Warp.Buffer
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
local Buffer = Warp.Buffer
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
local Buffer = Warp.Buffer
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
