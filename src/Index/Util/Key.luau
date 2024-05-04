--!strict
--!native
--!optimize 2
return function(): number?
	return tonumber(string.sub(tostring(Random.new():NextNumber()), 3, 6)) -- 4 digits
end