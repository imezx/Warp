--!strict
--!native
--!optimize 2
return function(condition: (any), errorMessage: string?): ()
	if not (condition) then error(`Warp: {errorMessage}`, 2) end
end