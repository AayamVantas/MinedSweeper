local module = {}
module.__index = module

function module.nextRandom(tbl)
	local chosenIndexes = {}
	local count = 0
	local total = #tbl

	return function()
		if count >= total then
			return nil
		end

		local rnd
		repeat
			rnd = math.random(1, total)
		until not chosenIndexes[rnd]

		chosenIndexes[rnd] = true
		count = count + 1

		return rnd, tbl[rnd]
	end
end

return module