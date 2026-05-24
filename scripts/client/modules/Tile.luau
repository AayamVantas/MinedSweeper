local module = {}
module.__index = module
local Framework = require(Hidden.Framework)
local prefabs = Hidden.Shared.Prefabs
local colorData = require(prefabs.Databanks.ColorData)
local tileOffset = Framework.Config["TileSize"].Value

local remotes = world.ScriptService.Events
local confirmReplicate = remotes.ConfirmReplicate

module.Pool = nil
module.All = {}
module.LastClickTime = 0
module.PendingConfirmations = {}

function module.New(x: number, y: number)
    local self = setmetatable({}, module)
    self.Maid = Framework.Class.New("Maid")
    self.X, self.Y = x, y
    self.Active = true
    self.Flagged = false
    self.FlagMaid = Framework.Class.New("Maid")
    self.Mines = 0
    self.Mine = false

    self.Tile = module.Pool:Get()
    self.Tile.Parent = Environment.Tiles
    self.Tile.Position = Vector3.New(-x * tileOffset, 0, y * tileOffset)

    local label = self.Tile:FindChild("Text")
    if label then
        label.Text = ""
        label.Color = Color.New(1, 1, 1)
    end


    self:SetColor()

    module.All[`{x},{y}`] = self

    self.Maid:GiveTask(self.Tile.Hitbox.Touched:Connect(function(hit : Player)
        if not hit:IsA("Player") or self.Flagged or not self.Active then
            return
        end
        if not hit:HasTag("Alive") or hit:HasTag("NotReady") then return end
        hit.CanMove = true
        self.Active = false
        self:OnTouch(hit)
    end))

    self.Maid:GiveTask(self.Tile.Brick.Clicked:Connect(function(plr)
        if not plr:HasTag("Alive") then return end
        self:OnClick(plr)
    end))
    self.Maid:GiveTask(self.Tile.Hitbox.Clicked:Connect(function(plr)
        if not plr:HasTag("Alive") then return end
        self:OnClick(plr)
    end))

    self.Maid:GiveTask(function()
        module.All[`{x},{y}`] = nil
        self.FlagMaid:Destroy()
        module.Pool:Return(self.Tile)
    end)

    return self
end

function module:ReliableInvoke(remote, msg, remoteName)
    local id = guid.new()
    msg:AddString("ID", id)
    
    spawn(function()
        while self.Active ~= nil and module.All[`{self.X},{self.Y}`] and not module.PendingConfirmations[id .. remoteName] do
            remote:InvokeServer(msg)
            wait(1)
        end
        module.PendingConfirmations[id .. remoteName] = nil
    end)
end

function module:GetNeighbors()
    local neighbors = {}
    for x = self.X - 1, self.X + 1 do
        for y = self.Y - 1, self.Y + 1 do
            if x == self.X and y == self.Y then
                continue
            end

            local neighbor = module.All[`{x},{y}`]
            if neighbor then
                table.insert(neighbors, neighbor)
            end
        end
    end
    return neighbors
end

function module:OnClick(plr: Player)
    local now = tick()
    if now - module.LastClickTime < 0.3 then
        return
    end
    module.LastClickTime = now

    if not self.Active then
        if self.Mines == 0 or self.Mine then
            return
        end

        local flags = 0
        local toReveal = {}
        local neighbors = self:GetNeighbors()

        for _, neighbor in neighbors do
            if neighbor.Flagged or (not neighbor.Active and neighbor.Mine) then
                flags += 1
            elseif neighbor.Active then
                table.insert(toReveal, { x = neighbor.X, y = neighbor.Y })
            end
        end

        if flags == self.Mines and #toReveal > 0 then
            local remote = remotes.RevealTile
            local msg = NetMessage.New()
            msg:AddString("Position", json.serialize(toReveal))
            self:ReliableInvoke(remote, msg, "RevealTile")
        end
        return
    end

    local remote = remotes.PlaceFlag
    local msg = NetMessage.New()
    msg:AddString("Position", json.serialize({ x = self.X, y = self.Y }))
    self:ReliableInvoke(remote, msg, "PlaceFlag")
end

function module:SetFlagged(newVal)
    self.Flagged = if newVal ~= nil then newVal else not self.Flagged
    self.FlagMaid:Destroy()
    if not self.Flagged then
        return
    end
    local flagModels = prefabs.Flags:GetChildren()

    local flag = self.FlagMaid:Add(flagModels[math.random(1,#flagModels)]:Clone())
    flag.Name = "Flag"
    flag.Parent = self.Tile

    local flagBounds = flag:GetBounds()
    if not flagBounds then
        return
    end

    local offset = (flagBounds.Size.Y / 2) + (self.Tile.Brick.Size.Y / 2)
    flag.Position = self.Tile.Position + Vector3.New(0, offset, 0)

    for _, v in flag:GetDescendants() do
        if not v:IsA("Part") then
            continue
        end
        v.Clicked:Connect(function(plr)
            self:OnClick(plr)
        end)
    end
end

function module:SetText(text, textColor)
    if not text or text == 0 then
        return
    end
    local label = self.Tile:FindChild("Text")
    if not label then
        return
    end

    label.Text = tostring(text)
    label.Color = textColor or Color.Random()
    return self
end

function module:SetColor(color)
    local isEven = (self.X + self.Y) % 2 == 0
    local baseColor = color or Framework.Config["TileColor"].Value

    local offset = isEven and Color.New(0.05, 0.05, 0.05, 0) or Color.New(0, 0, 0, 0)
    self.Tile.Brick.Color = baseColor - offset
    return self
end

function module:Reveal(mines, plr)
    if Framework.Debug.Value then

        local prt = self.Maid:Add(Instance.New("Part"))
        prt.Parent = Environment.Temp
        prt.Position = Vector3.New(-self.X * tileOffset, 5, self.Y * tileOffset)
        prt.Size = Vector3.One * 3
        prt.Color = Color.New(1, 0, 0.3, .2)
        prt.CanCollide = false
        prt:Destroy(5)
    end
    if self.Flagged then
        self:SetFlagged(false)
    end

    if not self.Active and self.Mines ~= 0 then
        return
    end

    self.Mines = mines or 0
    self.Active = false

    if self.Mine == nil then
        self.Mine = false
    end

    local color = colorData.MineColors[self.Mines]
    self:SetColor(Color.New(0.8)):SetText(self.Mines, color)
end

function module:OnTouch(hit: Instance)
    local remote = remotes.RevealTile
    local msg = NetMessage.New()
    msg:AddString("Position", json.serialize({ x = self.X, y = self.Y }))
    self:ReliableInvoke(remote, msg, "RevealTile")
end

function module.Init()
    module.Pool = Framework.Class.New("InstancePool", "Tile", prefabs["Tile"], 300)
    
    confirmReplicate.InvokedClient:Connect(function(msg)
        local remoteName = msg:GetString("RemoteName")
        local id = msg:GetString("ID")
        module.PendingConfirmations[id .. remoteName] = true
    end)
end

function module:Destroy()
    self.Active = nil
    self.Maid:Destroy()
end

return module