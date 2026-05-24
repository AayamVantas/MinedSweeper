local Framework = require(Hidden.Framework)
local GameModes = require(Hidden.Shared.Prefabs.Databanks.Modes)

local function FailCommand(msg, moderator)
	Chat:UnicastMessage(`[color=red]{msg}[/color]`, moderator)
end

local function getPlayer(moderator: Player, player: string, callback: (player: Player) -> any?)
	if string.lower(player) == "all" then
		for _, v in world.Players:GetPlayers() do
			callback(v)
		end
		return true
	end
	if string.lower(player) == "others" then
		for _, v in world.Players:GetPlayers() do
			if v == moderator then
				continue
			end
			callback(v)
		end
		return true
	end

	local target = world.Players:GetPlayer(player)
	if not target then
		return false
	end

	callback(target)
	return true
end

local activeVote = nil

return {
	Kick = {
		Rank = "Admin",
		Call = function(moderator, args)
			local call = getPlayer(moderator, args[1], function(player: Player)
				player:Kick(table.concat(args, " ", 2))
			end)
			if not call then
				FailCommand(`Kick: Failed to kick player {args[1]}`, moderator)
			end
		end,
	},

	ToggleDebug = {
		Rank = "Owner",
		Call = function(moderator, args)
			local bool = args[1] and args[1] == "true" or not Hidden.Framework.Debug.Value
			Hidden.Framework.Debug.Value = bool
			Chat:BroadcastMessage(`[color=#af00af]ToggleDebug: Set Global Debug to {bool}[/color]`)
		end,
	},

	SetNick = {
		Rank = "Admin",
		Call = function(moderator, args)
			local player = world.Players:GetPlayer(args[1])
			if not player then
				FailCommand(`VoteKick: Failed to initiate a votekick on player {args[1]}`, moderator)
				return
			end
			player.Shared.Nick = table.concat(args, " ", 2)
		end,
	},

	VoteKick = {
		Rank = "Player",
		Call = function(moderator, args)
			if activeVote then
				FailCommand("VoteKick: There is already an active vote.", moderator)
				return
			end

			local target = world.Players:GetPlayer(args[1])
			if not target then
				FailCommand(`VoteKick: Failed to find player {args[1]}`, moderator)
				return
			end

			if target == moderator then
				FailCommand("VoteKick: You cannot votekick yourself.", moderator)
				return
			end

			activeVote = {
				Target = target,
				Voters = { [moderator.UserID] = true },
				Yes = 1,
				No = 0,
				TotalNeeded = math.ceil(#world.Players:GetPlayers() * 0.6),
			}

			Chat:BroadcastMessage(
				`[color=yellow][lb]VoteKick[rb] :[/color] {moderator.Name} started a vote to kick {target.Name} for: {table.concat(
					args,
					" ",
					2
				) or "Unknown"}\n Type :Yes or :No (Needs {activeVote.TotalNeeded} votes)`
			)

			spawn(function()
				for i = 1, 60 do
					wait(1)
					if not activeVote then
						return
					end
					if activeVote.Yes >= activeVote.TotalNeeded then
						break
					end
				end
				if not activeVote then
					return
				end

				if activeVote.Yes >= activeVote.TotalNeeded then
					Chat:BroadcastMessage(
						`[color=green]VoteKick: Vote passed! Kicking {activeVote.Target.Name}...[/color]`
					)
                    world.Shared.Kicked = world.Shared.Kicked or {}
                    world.Shared.Kicked[activeVote.Target.UserID] = true 
					activeVote.Target:Kick("Votekicked by community.")
				else
					Chat:BroadcastMessage("[color=red]VoteKick: Vote failed. Not enough votes.[/color]")
				end
				activeVote = nil
			end)
		end,
	},

	Yes = {
		Rank = "Player",
		Call = function(moderator)
			print("voted yes")
			if not activeVote or activeVote.Voters[moderator.UserID] then
				FailCommand("VoteKick: No Active Votekicks", moderator)
				return
			end
			activeVote.Voters[moderator.UserID] = true
			activeVote.Yes += 1
			Chat:UnicastMessage(
				`[color=green]Voted Yes. ({activeVote.Yes}/{activeVote.TotalNeeded})[/color]`,
				moderator
			)
		end,
	},

	No = {
		Rank = "Player",
		Call = function(moderator)
			print("voted no")
			if not activeVote or activeVote.Voters[moderator.UserID] then
				FailCommand("VoteKick: No Active Votekicks", moderator)
				return
			end
			activeVote.Voters[moderator.UserID] = true
			activeVote.No += 1
			Chat:UnicastMessage("[color=red]Voted No.[/color]", moderator)
		end,
	},

	SetNext = {
		Rank = "Admin",
		Call = function(moderator, args)
			local name = table.concat(args, " ")
			local found
			for _, v in GameModes do
				if v.Display ~= name then
					continue
				end
				found = v
				break
			end
			if not found then
				FailCommand(`SetNext: {name} is an invalid board`, moderator)
				return
			end
			world.Shared["NextBoard"] = found
			print(world.Shared["NextBoard"])
		end,
	},
    CheckAlive = {
        Rank = "Player",
        Call = function(moderator)
            local alive = #Players:GetChildrenWithTag("Alive")
            Chat:UnicastMessage(`Players Alive: {alive}`, moderator)
        end
    },
    EndRound = {
        Rank = "Owner",
        Call = function(moderator)
            Hidden.GameData.Timer.Value = 0
        end
    },
	ViewData = {
		Rank = "Owner",
		Call = function(moderator,args)
			local player = args[2] and Players:FindChild(args[1]) or moderator
			local category = args[2] or args[1]
			local handler = Framework.Class.GetClass("Player").Get(player)
			if not handler then
				FailCommand(`Could not find a player handler for {player}`, moderator)
				return
			end
			Chat:UnicastMessage(`[ViewData]: {category} {handler.Cache[category]}`, moderator)
		end
	}
}
