--!strict
--!optimize 2
return function(): number?
	return tonumber(tostring(Random.new():NextNumber()):sub(3, 7)) -- 4-5 digits
end