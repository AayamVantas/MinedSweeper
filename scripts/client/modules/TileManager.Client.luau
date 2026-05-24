local Framework = require(Hidden.Framework)
local module = {}
module.__index = module
module.Active = nil

local remotes = world.ScriptService.Events
local confirmReplicate = remotes.ConfirmReplicate
local invisTile = Hidden.Shared.Prefabs.Invis

function module.New(matrix: buffer, size: Vector2)
    print(matrix, "Matrix Recieved")
    if module.Active then
        module.Active:Destroy()
    end

    local self = setmetatable({}, module)
    self.Maid = Framework.Class.New("Maid")
    self.Tiles = {}
    self.OutlineTiles = {}
    self.ProcessedIDs = {}

    local debugDisplay = ""
    local playableCoords = {}
    local isPlayable = {}

    for y = 0, size.Y - 1 do
        debugDisplay ..= "\n"
        for x = 0, size.X - 1 do
            local offset = x + (y * size.X)
            local tile = buffer.readu8(matrix, offset)
            print(tile, offset)
            if tile == 2 then
                debugDisplay ..= " "
                continue
            end
            
            table.insert(playableCoords, {x = x, y = y})
            isPlayable[`{x},{y}`] = true
            
            local isMine = (tile == 1)
            local className = isMine and "Mine" or "Tile"
            local color = isMine and "red" or "white"
            debugDisplay ..= "[color=" .. color .. "]█[/color]"
            
            local tileObj = Framework.Class.New(className, x, y)
            self.Tiles[`{x},{y}`] = tileObj
            tileObj.ServerMineState = isMine
        end
    end

    local anchorX, anchorY, anchorTileObj
    for _, coord in playableCoords do
        anchorX = coord.x
        anchorY = coord.y
        anchorTileObj = self.Tiles[`{anchorX},{anchorY}`]
        if anchorTileObj then
            break
        end
    end

    if anchorTileObj and anchorTileObj.Tile and anchorTileObj.Tile.Brick then
        local p0 = Vector3.Zero
        local spacingX = Vector3.New(4, 0, 0)
        local spacingY = Vector3.New(0, 0, 4)

        local rightTile = self.Tiles[`{anchorX + 1},{anchorY}`]
        if rightTile and rightTile.Tile and rightTile.Tile.Brick then
            spacingX = rightTile.Tile.Brick.Position - anchorTileObj.Tile.Brick.Position
        end

        local upTile = self.Tiles[`{anchorX},{anchorY + 1}`]
        if upTile and upTile.Tile and upTile.Tile.Brick then
            spacingY = upTile.Tile.Brick.Position - anchorTileObj.Tile.Brick.Position
        end

        p0 = anchorTileObj.Tile.Brick.Position - (spacingX * anchorX) - (spacingY * anchorY)

        local outlineCoords = {}
        for _, coord in playableCoords do
            for dx = -2, 2 do
                for dy = -2, 2 do
                    if dx == 0 and dy == 0 then
                        continue
                    end
                    
                    local nx = coord.x + dx
                    local ny = coord.y + dy
                    local key = `{nx},{ny}`
                    
                    if isPlayable[key] then
                        continue
                    end
                    
                    if outlineCoords[key] then
                        continue
                    end
                    
                    outlineCoords[key] = true
                    local invis = invisTile:Clone()
                    invis.Position = p0 + (spacingX * nx) + (spacingY * ny)
                    invis.Parent = world
                    table.insert(self.OutlineTiles, invis)
                end
            end
        end
    end

    local mapLoadedMsg = NetMessage.New()
    self:ReliableInvoke(remotes.MapLoaded, mapLoadedMsg, "MapLoaded")

    if Framework.Debug.Value then
        print(debugDisplay)
    end

    local safeTiles = {}
    for _, tile in self.Tiles do
        if tile.ServerMineState then
            continue
        end
        
        local neighbors = tile:GetNeighbors()
        local mineCount = 0
        
        for _, n in neighbors do
            if not n.ServerMineState then
                continue
            end
            mineCount += 1
        end

        if mineCount ~= 0 then
            continue
        end
        
        table.insert(safeTiles, tile)
        print(tile)
    end
    
    spawn(function()
        local player = world.Players.LocalPlayer
        local timeout = 0

        while not player:HasTag("Alive") and timeout < 50 do
            timeout += 1
            wait(0.1)
        end
        
        if not player:HasTag("Alive") then
            return
        end
        
        player:AddTag("NotReady")
        local targetTile = safeTiles[math.random(#safeTiles)] or safeTiles[1]
        
        if not targetTile or not targetTile.Tile then
            player:RemoveTag("NotReady")
            return
        end
        
        print("Teleporting to board: I AM ALIVE")
        player:Jump()
        player.Position = targetTile.Tile.Brick.Position + Vector3.New(0, 5, 0)
        player.Velocity = Vector3.Zero
        player:RemoveTag("NotReady")
    end)

    self.Maid:GiveTask(remotes.ReplicateMatrix.InvokedClient:Connect(function(msg)
        local msgId = msg:GetString("ID") or ""

        local ack = NetMessage.New()
        ack:AddString("RemoteName", "ReplicateMatrix")
        ack:AddString("ID", msgId)
        confirmReplicate:InvokeServer(ack)

        if self.ProcessedIDs[msgId] then
            return
        end
        self.ProcessedIDs[msgId] = true

        local revealed = json.parse(msg:GetString("Revealed"))
        local plr = msg:GetInstance("Player")
        
        if not revealed then
            return
        end
        
        for _, data in revealed do
            local tile = self.Tiles[`{data.x},{data.y}`]
            if not tile then
                continue
            end
            tile:Reveal(data.Mines, plr)
        end
    end))

    self.Maid:GiveTask(remotes.PlaceFlag.InvokedClient:Connect(function(msg)
        local msgId = msg:GetString("ID") or ""

        local ack = NetMessage.New()
        ack:AddString("RemoteName", "PlaceFlag")
        ack:AddString("ID", msgId)
        confirmReplicate:InvokeServer(ack)

        if self.ProcessedIDs[msgId] then
            return
        end
        self.ProcessedIDs[msgId] = true

        local rawAllFlags = msg:GetString("AllFlags")
        if rawAllFlags and rawAllFlags ~= "" then
            local allFlags = json.parse(rawAllFlags)
            for key, state in allFlags do
                local tile = self.Tiles[key]
                if not tile then
                    continue
                end
                tile:SetFlagged(state)
            end
            return
        end

        local pos = json.parse(msg:GetString("Position"))
        local tile = self.Tiles[`{pos.x},{pos.y}`]
        
        if not tile then
            return
        end

        tile:SetFlagged(msg:GetBool("Flagged"))
    end))

    self.Maid:GiveTask(function()
        for _, tile in self.Tiles do
            tile:Destroy()
        end
        for _, invis in self.OutlineTiles do
            invis:Destroy()
        end
        self.Tiles = {}
        self.OutlineTiles = nil
        self.ProcessedIDs = nil
        Framework.Class.GetClass("InstancePool").GetPool("Tile"):Release()
        
        local spawnPos = Environment.Building.Spawn.Position
        local player = world.Players.LocalPlayer :: Player
        
        if player.IsDead then
            return
        end
        
        player.Health = player.MaxHealth
        player.Position = spawnPos + Vector3.New(0, 5, 0)
    end)

    module.Active = self
    return self
end

function module:ReliableInvoke(remote, msg, remoteName)
    local id = guid.new()
    msg:AddString("ID", id)

    spawn(function()
        while self.Tiles and not Framework.Class.GetClass("Tile").PendingConfirmations[id .. remoteName] do
            remote:InvokeServer(msg)
            wait(1)
        end
        
        if not Framework.Class.GetClass("Tile").PendingConfirmations then
            return
        end
        
        Framework.Class.GetClass("Tile").PendingConfirmations[id .. remoteName] = nil
    end)
end

function module:Destroy()
    self.Maid:Destroy()
    module.Active = nil
end

function module.Start()
    remotes.SendFieldMatrix.InvokedClient:Connect(function(msg)
        local msgId = msg:GetString("ID") or ""

        local ack = NetMessage.New()
        ack:AddString("RemoteName", "SendFieldMatrix")
        ack:AddString("ID", msgId)
        confirmReplicate:InvokeServer(ack)

        if module.Active and module.Active.ProcessedIDs[msgId] then
            return
        end

        local matrix = msg:GetBuffer("Matrix")
        local gridSize = msg:GetVector2("GridSize")
        local newGame = module.New(matrix, gridSize)
        newGame.ProcessedIDs[msgId] = true
    end)
end

return module