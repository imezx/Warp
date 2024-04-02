--!strict
return function(): string?
	return string.sub(Random.new():NextNumber(), 3, 7) -- 4 digits
end
