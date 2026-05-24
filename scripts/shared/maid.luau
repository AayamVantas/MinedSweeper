
local function doTask(object)
	local t = type(object)
	if t == "function" then
		-- local s, e = pcall(function()
			coroutine.wrap(object)()
		-- end)
		-- print(s,e)
		-- if not s and e then
			-- print(e)
		-- end
		return
	end

	local f = (
		object.destroy
		or object.Destroy
		or object.disconnect
		or object.Disconnect
		or object.release
		or object.close
	)
	-- print(f)
	if f then
		local r = coroutine.wrap(function(obj)
			local s, e = pcall(f, obj)
			if s then
				return
			end

			s = pcall(f)
			if not s then
				if object.Name then
					print(object.Name)
				end
				print(`[color=orange]Maid Encountered an error: {e}[/color]`)
			end
		end)
		r(object)
		-- local s,e = pcall(coroutine.wrap(f), object)
		-- print("Properly Wrapping the stuff")
	end
end

local module = {}
module.__type = "Maid"
module.__index = function(self, i)
	local modHas = rawget(module, i)
	if modHas then
		return modHas
	end

	local selfHas = rawget(self, i)
	if selfHas then
		return selfHas
	end

	return self._tasks[i]
end

module.__newindex = function(self, i, v)
	if rawequal(self, module) then
		rawset(module, i, v)
		return
	end

	doTask(self[i])

	rawset(self._tasks, i, v)
end

module.New = function()
	return setmetatable({ _tasks = {} }, module)
end

function module:Add(task)
	self:GiveTask(task)
	return task
end

function module:GiveTask(task)
	table.insert(self._tasks, task)
end

function module:Destroy()
	local index, task = next(self._tasks)
	while index and task ~= nil do
		self[index] = nil
		index, task = next(self._tasks)
		if index and index % 100 == 0 then wait() end
	end
end

return module