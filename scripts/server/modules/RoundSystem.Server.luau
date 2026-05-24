local Framework = require(Hidden.Framework)
local Modes = require(Hidden.Shared.Prefabs.Databanks.Modes)

local module = {}

module.__index = module
module.Derives = "Component"

local remotes = world.ScriptService.Events
local confirmReplicate = remotes.ConfirmReplicate

local function changeStatus(newStatus: string, color: Color)
    color = color or Color.New(1)
    local hex = type(color) ~= "string" and `#{Color.ToHex(color)}` or color
    newStatus = `[color={hex}]{newStatus}[/color]`
    Hidden.GameData.Status.Value = newStatus
end

local function Countdown(time: number)
    for i = time, 0, -1 do
        Hidden.GameData.Timer.Value = i
        wait(1)
    end
end

function module.New(self)
    self.CurrentLoop = 0
    self.Maid = Framework.Class.New("Maid")
    self.ProcessedIDs = {}
    self:BeginGame()
    return self
end

function module:BeginGame()
    while true do
        for _, player in world.Players:GetPlayers() do
            player:RemoveTag("Alive")
        end

        changeStatus("Waiting For Players")
        if #world.Players:GetPlayers() == 0 then
            wait()
            continue
        end
        
        changeStatus("Intermission")
        Countdown(Framework.Config.IntermissionLength.Value * (self.CurrentLoop < 1 and 3 or 1))
        
        local gameResult = nil
        local function checkLoss()
            local alive = 0
            for _, player in world.Players:GetPlayers() do
                if player.IsDead then
                    player:RemoveTag("Alive")
                    continue
                end

                if player:HasTag("Alive") then
                    alive += 1
                end
            end
            if alive == 0 then
                gameResult = "Loss"
            end
            print("Players alive", alive)
        end

        local gamemode = world.Shared["NextBoard"] or Framework.Utility.Number.WeightedRarity(Modes)
        local gameMaid = Framework.Class.New("Maid")
        
        world.Shared["NextBoard"] = nil
        changeStatus(gamemode.Display, gamemode.DisplayColor)

        Hidden.GameData.MineCount.Value = gamemode.Mines
        Hidden.GameData.GameActive.Value = true

        for _, player : Player in world.Players:GetPlayers() do
            if not player:HasTag("Ready") then continue end
            player:AddTag("Alive")
            player.CanMove = false
            gameMaid:Add(player.Died:Connect(function()  
                player:RemoveTag("Alive")
                checkLoss()
            end))
        end

        local tileManager = gameMaid:Add(Framework.Class.New("TileManager", gamemode))

        gameMaid:GiveTask(tileManager.Victory:Connect(function()
            gameResult = "Victory"
        end))

        local mapLoaded = false
        local mapLoadedConn
        
        mapLoadedConn = remotes.MapLoaded.InvokedServer:Connect(function(sender, msg)
            local msgId = msg:GetString("ID") or ""
            
            local ack = NetMessage.New()
            ack:AddString("RemoteName", "MapLoaded")
            ack:AddString("ID", msgId)
            confirmReplicate:InvokeClient(ack, sender)

            if self.ProcessedIDs[msgId] then
                return
            end
            self.ProcessedIDs[msgId] = true

            mapLoaded = true
        end)
        
        repeat wait() until mapLoaded
        mapLoadedConn:Disconnect()

        gameMaid:GiveTask(world.Players.PlayerRemoved:Connect(checkLoss))
        
        local timer = gamemode.TimeLimit
        while timer > 0 and not gameResult do
            Hidden.GameData.Timer.Value = timer
            timer -= 1
            wait(1)
            
            checkLoss()
        end

        if gameResult == "Victory" then
            changeStatus("Victory!", Color.New(0, 1, 0))
            for _, player in world.Players:GetPlayers() do
                if not player:HasTag("Alive") then continue end
                Framework.Utility.Challenges.AddValue("victory", player, 1)
                Framework.Class.GetClass("Player").Get(player).Cache.Wins += 1
                Framework.Utility.Challenges.AwardAchievement(player,160774)
            end
        else
            changeStatus("Game Over", Color.New(1, 0, 0))
        end

        Countdown(10)
        
        for _, player in world.Players:GetPlayers() do
            player:RemoveTag("Alive")
            player.Position = world.Environment.Building.Spawn.Position
        end

        gameMaid:Destroy()
        self.ProcessedIDs = {}
        self.CurrentLoop += 1
    end
end

return module