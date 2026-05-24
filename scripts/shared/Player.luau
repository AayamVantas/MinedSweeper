---@diagnostic disable: undefined-global
local Framework = require(Hidden.Framework)
local module = {}
module.__index = module
module.All = {}
function module.New(player: Player)
	local self = setmetatable({}, module)
	self.Maid = Framework.Class.New("Maid")
	self.Died = Framework.Class.New("Signal")
	self.Plr = player
	local debounce = false
	self.playerDied = function()
		if debounce then
			return
		end
		debounce = true
		print("Firing the died Signal")
		self.Died:Fire(player)
		wait(0.001)
		debounce = false
	end
	player.Died:Connect(self.playerDied) -- wrapping because .Died doesn't pass the player and to disconnect a event in poly you need to pass the same function in, meaning very annoying to disconnect a died function
	module.All[player] = self

	if world.Shared.IsClient then
		self:OnClient()
	else
		self:OnServer()
	end

	return self
end
function module:OnClient() end

function module:OnServer()
	if world.IsLocalTest then
		self.Plr:LoadAppearance(94852)
		self.Plr.AutoLoadAppearance = true
		self.Plr.Respawned:Connect(function(...)
			self.Plr:LoadAppearance(94852)
		end)
	end
	if world.Shared.Kicked and world.Shared.Kicked[self.Plr.UserID] then
		self.Plr:Kick("You are banned from this specific server, please join a different one")
	end
	self.Data = Datastore:GetDatastore(tostring(self.Plr.UserID))
	self.Data:Get("Banned", function(value, success)
		if success and value then
			self.Plr:Kick(value)
		end
	end)
	Framework.Utility.Challenges.AwardAchievement(self.Plr, 160773)
	self.Cache = { Wins = 0, Losses = 0, TilesRevealed = 0 }
	self.Data:Get("Data", function(value, success)
		local data = success and value and json.parse(value)
		self.Cache = not json.isNull(data) and data or self.Cache
	end)

	if Framework.Debug.Value then
		local str = "{\n"
		for i, v in self.Cache do
			str = `{str}\t{i} = {v}`
		end
		str = `{str}\n\}`
		print(self.Plr.Name, str)
	end
end
local function playerAdded(player)
	if module.All[player] then
		return
	end

	module.New(player)
end
function module.Get(player)
	return module.All[player]
end
function module.Start()
	for _, v in next, world["Players"]:GetPlayers() do
		playerAdded(v)
	end
	world["Players"].PlayerAdded:Connect(playerAdded)
	world["Players"].PlayerRemoved:Connect(function(player)
		print("Player Is Removing")
		local handler = module.All[player]
		if not handler then
			return
		end
		handler.DataStore:Set("Data", json.serialize(handler.Cache))
		handler.playerDied()
		module.All[player] = nil
	end)
end
return module
