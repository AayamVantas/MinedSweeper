
local module = {}
module.__index = module

local BASE_URL = "https://api.polytoria.com/v1/events/notify"
local buffer = {}

module.Award = module.AddValue

function module.Notify(event, player, value)
	value = value or 1

	local payload = json.serialize{
		event = event,
		userID = player.UserID,
		value = value,
	}

	Http:Post(BASE_URL, payload, function(data, error, errormsg)
		if error then
			print("Error notifying challenge event: " .. errormsg)
			return
		end

		local response = json.parse(data)
		if not response.success then
			print("Failed to notify challenge event: " .. response.message)
		end
	end, {
		["Content-Type"] = "application/json",
	})
end

function module.AddValue(event, player, value)
	if not buffer[event] then
		buffer[event] = {}
	end

	local key = player.UserID or 0
	buffer[event][key] = (buffer[event][key] or 0) + value
end

function module.AwardAchievement(player, id)
	return Achievements:Award(player.UserID, id, function(s, e)
		if not s then
			print(`[color=orange]Error Awarding Achievements: {e}[/color]`)
		end
	end)
end


local updateTimer = 0
local function update(dt)
	updateTimer = updateTimer + dt
    local player
	if updateTimer < 30 then
		return
	end
    for event, players in next, buffer do
			for playerID, value in next, players do
				player = world["Players"]:GetPlayerByID(playerID)

				if not player then
					print("Player with ID " .. playerID .. " not found for event: " .. event)
                    continue
				end
                module.Notify(event, player, value)

			end
		end

		buffer = {}
		updateTimer = 0
end

world.Rendered:Connect(update)

return module