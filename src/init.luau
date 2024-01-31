-- Warp Library (@Eternity_Devs)
-- version 1.0.5
--!strict
--!native
local Index = require(script.Index)

return {
	Server = Index.Server,
	Client = Index.Client,
	fromServerArray = Index.fromServerArray,
	fromClientArray = Index.fromClientArray,
	
	Signal = Index.Signal,
	fromSignalArray = Index.fromSignalArray,
}