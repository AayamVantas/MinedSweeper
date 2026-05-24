local Commands = require(script.ChatCommands)

local Ranks = {
    Player = 0,
    Admin = 1,
    Owner = 2
}

local Tags = {
    Owner = "[color=yellow][lb]Owner[rb][/color]",
    Admin = "[color=red][lb]Admin[rb][/color]",
    Player = ""
}

local function getRank(player: Player)
    if player.IsCreator then return "Owner" end
    if player.IsAdmin then return "Admin" end
    return "Player"
end

Chat.ChatPredicate = function(plr: Player, msg: string)
    local prefix = ":"
    local playerRank = getRank(plr)
    local chatTag = Tags[playerRank]

    if string.sub(msg, 1, 1) == prefix then
        local fullCommand = string.sub(msg, 2)
        local split = string.split(fullCommand, " ")
        local cmdName = split[1]

        local cmdData = Commands[cmdName]
        if not cmdData then
            return false
        end

        if Ranks[playerRank] < Ranks[cmdData.Rank] then
            Chat:UnicastMessage(`[color=red]You do not have permission to use: {cmdName}[/color]`, plr)
            return false
        end

        local args = {}
        for i = 2, #split do
            table.insert(args, split[i])
        end

        local success, err = pcall(function()
            cmdData.Call(plr, args)
        end)

        if not success then
            print(`[color=red]Error running command {cmdName}: {err}[/color]`)
        end

        return false
    end

    local restored = string.gsub(msg, "%[lb%]", "[")
    restored = string.gsub(restored, "%[rb%]", "]")
    
    local nameDisplay = plr.Shared.Nick or plr.Name
    local finalPrefix = chatTag ~= "" and `{chatTag} {nameDisplay}` or nameDisplay
    
    Chat:BroadcastMessage(`[b]{finalPrefix}:[/b] {restored}`)

    return false
end