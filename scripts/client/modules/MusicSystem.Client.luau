-- local Framework = require(Hidden.Framework)
local module = {}
module.__index = module
module.Derives = "Component"

local UI = world["PlayerGUI"]["MusicStatus"]
local sounds = world["Music"]:GetDescendants()

function module.New(self)
	UI.Visible = false
	self.Muted = false
	self.Playing = nil
	self.Songs = {}

	UI["Mute"].Clicked:Connect(function()
		self:Mute()
	end)

	for _, v: Sound in next, sounds do
		spawn(function()
            if not v:IsA("Sound") then return end
			local author, title = v["Author"], v["Title"]
			-- if Framework.Debug.Value then print(v.Loading, title.Value) end
			v.Loaded:Wait()
			-- if Framework.Debug.Value then print(v.Loading, title.Value) end
			table.insert(self.Songs, {
				Song = v,
				Author = author.Value or "Unknown",
				Title = title.Value or "Unknown",
			})
		end)
	end
    repeat wait() until #self.Songs > 0
	UI.Visible = true
	spawn(function()
		self:PlayLoop()
	end)

	return self
end

function module:Mute()
	self.Muted = not self.Muted

	UI["Artist"].Visible = not self.Muted
	UI["Song"].Visible = not self.Muted

	UI.Mute.Off.Visible = self.Muted
	UI.Mute.On.Visible = not self.Muted

	if not self.Muted then
		return
	end
	if not self.Playing then
		return
	end
	self.Playing:Stop()
end

function module:PlayLoop()
	while true do
		local data
		if self.Muted or #self.Songs == 0 then
			wait(0.5)
			continue
		end
		data = self.Songs[math.random(1, #self.Songs)]

		self.Playing = data.Song

		UI["Artist"].Text = data.Author
		UI["Song"].Text = data.Title

		self.Playing:Play()

		wait()

		while self.Playing.Playing do
			if self.Muted then
				break
			end
			wait()
		end

		if self.Muted then
			self.Playing:Stop()
		end

		wait()
	end
end

return module
