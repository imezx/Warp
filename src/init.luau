-- Warp Library (@Eternity_Devs)
-- version 1.0.12
--!strict
--!native
--!optimize 2
local Index = require(script.Index)

return {
	Server = Index.Server,
	Client = Index.Client,
	fromServerArray = Index.fromServerArray,
	fromClientArray = Index.fromClientArray,
	
	Signal = Index.Signal,
	fromSignalArray = Index.fromSignalArray,

	buffer = Index.buffer,
}