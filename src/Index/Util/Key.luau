--!strict
return function(): number?
	return tonumber(string.sub(tostring(Random.new():NextNumber()), 3, 6))
end