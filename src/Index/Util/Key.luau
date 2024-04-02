--!strict
return function(): number?
	return tonumber(string.sub(tostring(Random.new():NextNumber()), 3, 7)) -- 4 digits
end