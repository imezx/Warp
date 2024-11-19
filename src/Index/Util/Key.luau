--!strict
--!optimize 2
return function(): number?
	return tonumber(string.sub(tostring(Random.new():NextNumber()), 3, 8)) -- 6 digits
end