local module = {}
module.__index = module
module.Derives = "Tile"

function module.New(self)
	self.Mine = true
    return self
end

function module:Reveal(mines, plr)
    self:SetColor(Color.New(1, 0, 0))
    self.Active = false

    local explosion = Instance.New("Explosion")
    explosion.Position = self.Tile.Position
    explosion.Parent = Environment

    local player = world.Players.LocalPlayer
    
    if plr ~= player then
        return
    end

    local dir = (player.Position - self.Tile.Position) :: Vector3
    -- player.Health -= 34
    player.Health = 0
    if player.Health > 0 then
        return
    end

    local randVariance = Vector3.New(math.random() - 0.5, 0, math.random() - 0.5)

    if player.Character then
        player.Character:StopRagdoll()

        local flingForce = (dir.Normalized + randVariance).Normalized * 1500
        player.Character:StartRagdoll(flingForce)
    end

    player:Kill()
end

return module