--!strict
return function(condition: (any), errorMessage: string?): ()
	if not (condition) then error(errorMessage, 2) end
end