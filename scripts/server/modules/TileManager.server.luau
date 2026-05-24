local Framework = require(Hidden.Framework)
local module = {}
module.__index = module
module.Active = nil

local remotes = ScriptService.Events
local confirmReplicate = remotes.ConfirmReplicate

local function debugPrint(...)
    if not Framework.Debug.Value then return end
    print(...)
end

function module.New(data)
    debugPrint("module.New: Starting initialization")
    local self = setmetatable({}, module)
    self.Maid = Framework.Class.New("Maid")
    self.Matrix = buffer.create(data.Grid.X * data.Grid.Y)
    self.Revealed = {}
    self.Flagged = {}
    self.FlagDebounces = {}
    self.PendingConfirmations = {}
    self.ProcessedIDs = {}
    self.GridVector = data.Grid :: Vector2
    self.Victory = self.Maid:Add(Framework.Class.New("Signal"))

    debugPrint("module.New: Creating board shape")
    for x, row in data.Shape or {} do
        for y, column in row do
            if column ~= 0 then continue end
            local offset = (x - 1) + ((y - 1) * data.Grid.X)
            buffer.writeu8(self.Matrix, offset, 2)
        end
    end

    local availableSpots = 0
    local maxOffset = (data.Grid.X * data.Grid.Y) - 1
    for offset = 0, maxOffset do
        if buffer.readu8(self.Matrix, offset) == 0 then
            availableSpots += 1
        end
    end

    local targetMines = math.min(data.Mines, availableSpots)
    local spawned = 0
    debugPrint(`module.New: Target Mines: {targetMines} / Available Spots: {availableSpots}`)

    if targetMines > 0 then
        repeat
            local x = math.random(0, data.Grid.X - 1)
            local y = math.random(0, data.Grid.Y - 1)
            local offset = x + (y * data.Grid.X)

            if buffer.readu8(self.Matrix, offset) == 0 then
                buffer.writeu8(self.Matrix, offset, 1)
                spawned = spawned + 1
            end
        until spawned == targetMines
    end
    debugPrint(`module.New: Mine generation complete. Spawned {spawned} mines.`)

    self:SendMatrix(self.Matrix)

    self.Maid:GiveTask(confirmReplicate.InvokedServer:Connect(function(sender, msg)
        local remoteName = msg:GetString("RemoteName")
        local id = msg:GetString("ID")
        local key = sender.UserID .. id .. remoteName
        debugPrint(`ConfirmReplicate: Received ACK for {remoteName} (ID: {id}) from {sender.UserID}`)
        self.PendingConfirmations[key] = true
    end))

    self.Maid:GiveTask(remotes.RevealTile.InvokedServer:Connect(function(sender, msg)
        local msgId = msg:GetString("ID") or ""
        debugPrint(`RevealTile: Received request ID {msgId} from {sender.UserID}`)

        local ack = NetMessage.New()
        ack:AddString("RemoteName", "RevealTile")
        ack:AddString("ID", msgId)
        
        spawn(function()
            confirmReplicate:InvokeClient(ack, sender)
        end)

        if self.ProcessedIDs[msgId] then
            debugPrint(`RevealTile: Dropped duplicate request ID {msgId}`)
            return
        end
        self.ProcessedIDs[msgId] = true

        local pos = json.parse(msg:GetString("Position"))
        local playerData = Framework.Class.GetClass("Player").Get(sender).Cache

        if not pos[1] then
            debugPrint(`RevealTile: Processing single coordinate reveal for {sender.UserID}`)
            self:RevealTiles(pos, sender)
        else
            debugPrint(`RevealTile: Processing multi-coordinate reveal for {sender.UserID}`)
            sender.Shared["tile_revealed"] = 0
            for _, position in pos do
                self:RevealTiles(position, sender)
            end
        end

        local total = sender.Shared["tile_revealed"]
        sender.Shared["tile_revealed"] = 0
        Framework.Utility.Challenges.AddValue("tile_revealed", sender, total)
        self:CheckWinCondition()
        
        if not playerData then
            return
        end
        
        if Framework.Debug.Value then
            debugPrint(playerData)
            local str = "{\n"
            for i, v in playerData do
                str = `{str}\t{i} = {v}`
            end
            str = `{str}\n\}`
            debugPrint(sender, str)
        end
        playerData.TilesRevealed += total
        debugPrint(`RevealTile: Completed request ID {msgId}`)
    end))

    self.Maid:GiveTask(Players.PlayerAdded:Connect(function(player)
        debugPrint(`PlayerAdded: Sending matrix and game state to {player.UserID}`)
        self:SendMatrix(self.Matrix, player)
        if next(self.Revealed) then
            self:ReplicateRevealed(self.Revealed, nil, player)
        end
        if next(self.Flagged) then
            self:ReplicateFlags(nil, player)
        end
    end))

    self.Maid:GiveTask(remotes.PlaceFlag.InvokedServer:Connect(function(sender, msg)
        local msgId = msg:GetString("ID") or ""
        debugPrint(`PlaceFlag: Received request ID {msgId} from {sender.UserID}`)

        local ack = NetMessage.New()
        ack:AddString("RemoteName", "PlaceFlag")
        ack:AddString("ID", msgId)
        
        spawn(function()
            confirmReplicate:InvokeClient(ack, sender)
        end)

        if self.ProcessedIDs[msgId] then
            return
        end
        self.ProcessedIDs[msgId] = true

        if not sender:HasTag("Alive") then
            return
        end

        local now = tick()
        local lastFlag = self.FlagDebounces[sender.UserID] or 0
        if now - lastFlag < 0.3 then
            debugPrint(`PlaceFlag: Debounced user {sender.UserID}`)
            return
        end
        self.FlagDebounces[sender.UserID] = now

        local pos = json.parse(msg:GetString("Position"))
        local key = pos.x .. "," .. pos.y

        if self.Revealed[key] then
            return
        end

        local newVal = not self.Flagged[key]
        self.Flagged[key] = newVal or nil

        Hidden.GameData.MineCount.Value -= (newVal and 1 or -1)

        local out = NetMessage.New()
        out:AddString("Position", msg:GetString("Position"))
        out:AddBool("Flagged", newVal)

        self:ReplicateFlags(out)
    end))

    self.Maid:GiveTask(Players.PlayerRemoved:Connect(function(player)
        self.FlagDebounces[player.UserID] = nil
    end))

    debugPrint("module.New: Initialization complete")
    return self
end

function module:ReliableInvoke(remote, msg, remoteName, client)
    local id = guid.new()
    msg:AddString("ID", id)

    local function attempt(target)
        local key = target.UserID .. id .. remoteName
        debugPrint(`ReliableInvoke: Queueing {remoteName} (ID: {id}) for {target.UserID}`)
        spawn(function()
            while self.Matrix and not self.PendingConfirmations[key] do
                debugPrint(`ReliableInvoke: Invoking {remoteName} (ID: {id}) for {target.UserID}`)
                remote:InvokeClient(msg, target)
                wait(1)
            end
            if not self.PendingConfirmations then
                return
            end
            debugPrint(`ReliableInvoke: Successfully delivered {remoteName} (ID: {id}) to {target.UserID}`)
            self.PendingConfirmations[key] = nil
        end)
    end

    if client then
        attempt(client)
        return
    end

    for _, player in Players:GetPlayers() do
        attempt(player)
    end
end

function module:Destroy()
    debugPrint("module:Destroy: Cleaning up game session")
    self.Maid:Destroy()
    self.Matrix = nil
    self.Revealed = nil
    self.Flagged = nil
    self.PendingConfirmations = nil
    self.ProcessedIDs = nil
end

function module:CheckWinCondition()
    local safeTilesRevealed = 0
    for key, _ in self.Revealed do
        local coords = string.split(key, ",")
        local x, y = tonumber(coords[1]), tonumber(coords[2])
        local offset = x + (y * self.GridVector.X)
        
        if buffer.readu8(self.Matrix, offset) == 0 then
            safeTilesRevealed += 1
        end
    end
    
    if safeTilesRevealed >= self.SafeTileRequirement then
        debugPrint("CheckWinCondition: Victory condition met")
        self.Victory:Fire()
    end
end

function module:ReplicateFlags(msg, client)
    local remote = remotes.PlaceFlag
    if msg then
        self:ReliableInvoke(remote, msg, "PlaceFlag", client)
        return
    end

    local fullMsg = NetMessage.New()
    fullMsg:AddString("AllFlags", json.serialize(self.Flagged))
    self:ReliableInvoke(remote, fullMsg, "PlaceFlag", client)
end

function module:RevealTiles(startingPos: { x: number, y: number }, player)
    debugPrint(`RevealTiles: Starting flood fill for {startingPos.x}, {startingPos.y}`)
    player.Shared["tile_revealed"] = player.Shared["tile_revealed"] or 0
    local revealed = {}
    local stack = {startingPos}
    local maxIterations = 50000 
    local currentIterations = 0

    while #stack > 0 do
        currentIterations += 1
        if currentIterations > maxIterations then
            debugPrint("RevealTiles: Iteration limit exceeded, breaking loop to prevent crash")
            break
        end

        local pos = table.remove(stack)
        local cx, cy = pos.x, pos.y
        local key = cx .. "," .. cy
        
        if not self.Matrix then
            continue
        end
        
        if cx < 0 or cx >= self.GridVector.X or cy < 0 or cy >= self.GridVector.Y then
            continue
        end
        
        if self.Revealed[key] or self.Flagged[key] then
            continue
        end
        
        local offset = cx + (cy * self.GridVector.X)
        local tileVal = buffer.readu8(self.Matrix, offset)
        
        if tileVal == 2 then
            continue
        end

        self.Revealed[key] = true
        
        local isMine = (tileVal == 1)
        local mines = 0
        local neighbors = {}
        
        for x = cx - 1, cx + 1 do
            for y = cy - 1, cy + 1 do
                if x == cx and y == cy then
                    continue
                end
                
                if x < 0 or x >= self.GridVector.X or y < 0 or y >= self.GridVector.Y then
                    continue
                end
                
                local nOffset = x + (y * self.GridVector.X)
                local nVal = buffer.readu8(self.Matrix, nOffset)
                
                if nVal == 2 then
                    continue
                end

                table.insert(neighbors, { x = x, y = y })
                
                if nVal == 1 then
                    mines += 1
                end
            end
        end
        
        pos.Mines = mines
        table.insert(revealed, pos)
        
        if isMine then
            Hidden.GameData.MineCount.Value -= 1
            continue
        end
        
        if mines > 0 then
            continue
        end
        
        for _, n in neighbors do
            table.insert(stack, n)
        end
    end

    debugPrint(`RevealTiles: Flood fill complete. Revealed {#revealed} tiles in {currentIterations} iterations.`)
    player.Shared["tile_revealed"] += #revealed
    
    if #revealed > 0 then
        self:ReplicateRevealed(revealed, player)
    end
end

function module:SendMatrix(matrix, client)
    local remote = remotes.SendFieldMatrix
    local msg = NetMessage.New()
    msg:AddBuffer("Matrix", matrix)
    msg:AddVector2("GridSize", self.GridVector)
    self:ReliableInvoke(remote, msg, "SendFieldMatrix", client)
end

function module:ReplicateRevealed(revealed, revealer, client)
    local remote = remotes.ReplicateMatrix
    local msg = NetMessage.New()
    msg:AddString("Revealed", json.serialize(revealed))
    if revealer then
        msg:AddInstance("Player", revealer)
    end
    self:ReliableInvoke(remote, msg, "ReplicateMatrix", client)
end

return module