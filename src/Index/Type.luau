--!strict
export type rateLimitArg = {
	maxEntrance: number?,
	interval: number?,
}

export type Client = {
	Fire: (self: Client, reliable: boolean, ...any) -> (),
	Invoke: (self: Client, timeout: number, ...any) -> any,
	Connect: (self: Client, callback: (...any) -> ()) -> string,
	Once: (self: Client, callback: (player: Player, ...any) -> ()) -> string,
	Disconnect: (self: Client, key: string) -> (),
	DisconnectAll: (self: Client) -> (),
	Destroy: (self: Client) -> (),
	Wait: (self: Client) -> number,
}

export type Server = {
	Fire: (self: Server, reliable: boolean, player: Player, ...any) -> (),
	Fires: (self: Server, reliable: boolean, ...any) -> (),
	Invoke: (self: Server, timeout: number, player: Player, ...any) -> any,
	Connect: (self: Server, callback: (player: Player, ...any) -> ()) -> string,
	Once: (self: Server, callback: (player: Player, ...any) -> ()) -> string,
	Disconnect: (self: Server, key: string) -> (),
	DisconnectAll: (self: Server) -> (),
	Destroy: (self: Server) -> (),
	Wait: (self: Server) -> number,
}

export type Event = {
	Reliable: RemoteEvent,
	Unreliable: UnreliableRemoteEvent,
	Request: RemoteEvent,
}

export type QueueMap = {
	[string]: {
		[any]: any,
	}
}

export type CallbackMap = {
	[string]: (any),
}

export type StoredRatelimit = {
	[string]: any
}

export type fromServerArray = {
	[string]: Server
}

export type fromClientArray = {
	[string]: Client
}

return nil