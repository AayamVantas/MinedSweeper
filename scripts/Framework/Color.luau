local module = {}
module.__index = module

function module.FromHSVA(h, s, v, a)
	local c = v * s
	local x = c * (1 - math.abs((h / 60) % 2 - 1))
	local m = v - c

	local r, g, b

	r = h < 60 and c or h < 120 and x or h < 180 and 0 or h < 240 and 0 or h < 300 and x or c

	g = h < 60 and x or h < 120 and c or h < 180 and c or h < 240 and x or 0

	b = h < 120 and 0 or h < 180 and x or h < 240 and c or h < 300 and c or x

	return Color.New(r + m, g + m, b + m, a)
end
function module.ToHex(color)
	-- print(color and color.R, color.G, color.B)
	-- local r, g, b = color.R * 255, color.G * 255, color.B * 255
	-- return string.format("#%02X%02X%02X", r, g, b)
	
	return Color.ToHex(color)
end
return module
