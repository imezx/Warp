--!strict
--!native
--!optimize 2
return function(condition: (any), errorMessage: string, level: number?): ()
	if not (condition) then error(`Warp: {errorMessage}`, level or 2) end
end