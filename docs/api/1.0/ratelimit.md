# Rate Limit

Ratelimit is one of most useful feature.

( Configured on Server and For Client )

## `Setup`

When creating a event on Server, you can add second argument as table `rateLimit` to limit the number of times the event can be called and the interval for reset the counter.

::: code-group
```lua [Server]
-- Server
-- Let's make the event have ratelimit with max 50 entrance for 2 seconds.
local Remote = Warp.Server("Remote1", {
	maxEntrance = 50, -- maximum 50 fires.
	interval = 2, -- 2 seconds
})
-- Now the Event RateLimit is configured, and ready to use.
-- No need anything to adds on client side.
```

```lua [Client]
-- Client
local Remote = Warp.Client("Remote1")
-- The Event will automatic it self for retreiving the rate limit configuration from the server.
```
:::