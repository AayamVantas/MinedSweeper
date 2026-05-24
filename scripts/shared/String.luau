local module = {}
module.__index = module

module.prettyPrint = function(...)
	local function serializeTable(tbl, indent)
		indent = indent or 0
		local indentStr = string.rep("  ", indent)
		local str = "{"

		for key, val in next, tbl do
			local formattedKey
			if type(key) == "string" then
				formattedKey = string.format('[[color=#00ff00]"%s"[/color]]', key)
			else
				formattedKey = string.format("[[color=#ffaa00]%s[/color]]", tostring(key))
			end

			local vType = type(val)
			local formattedVal

			if vType == "table" then
				formattedVal = serializeTable(val, indent + 1)
			elseif vType == "string" then
				formattedVal = string.format('[color=#00ff00]"%s"[/color]', val)
			elseif vType == "boolean" then
				formattedVal = string.format("[color=%s]%s[/color]", val and "#00ff00" or "#ff0000", tostring(val))
			elseif vType == "function" then
				formattedVal = "[color=#aaaaaa]<function>[/color]"
			elseif val == nil then
				formattedVal = "[color=#ff0000]nil[/color]"
			else
				formattedVal = string.format("[color=#ffaa00]%s[/color]", tostring(val))
			end

			str = str .. indentStr .. "  " .. formattedKey .. " = " .. formattedVal .. ","
		end

		return str .. indentStr .. "}"
	end

	local function getBit(value)
		if value == nil then
			return "[color=#ff0000]nil[/color]"
		end

		local vType = type(value)
		if vType == "string" then
			return value
		end
		if vType == "number" then
			return tostring(value)
		end
		if vType == "boolean" then
			return string.format("[color=%s]%s[/color]", value and "#00ff00" or "#ff0000", tostring(value))
		end

		if vType == "function" then
			local status, result = pcall(value)
			if not status then
				return string.format("[color=#ff0000]<function error: %s>[/color]", result)
			end
			return tostring(result)
		end

		if vType == "table" then
			if getmetatable(value) then
				return "table with metatable:" .. serializeTable(value)
			end
			return serializeTable(value)
		end

		return string.format("[color=#ff0000]<Unsupported data type: %s>[/color]", vType)
	end

	local args = table.pack(...)
	local segments = {}
	for i = 1, args.n do
		segments[i] = getBit(args[i])
	end
	print(table.concat(segments, ", "))
end
module.warn = function(message, ...)
	local extra = { ... }
	local concat = table.concat(extra, ", ")
	local str = message .. (concat and ", " .. concat or "")
	print(string.format("[color=#FFA01C]%s[/color]",str)) 
end
return module