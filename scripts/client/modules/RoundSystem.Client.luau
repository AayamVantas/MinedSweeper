local module = {}
local Framework = require(Hidden.Framework)
module.__index = module
module.Derives = "Component"
local UI = PlayerGUI.RoundStatus :: GUI
local MineUI = PlayerGUI.MineStats :: GUI 


local function updateStatus()
    UI.Status.Text = Hidden.GameData.Status.Value
end
local function updateTimer()
    local text = Hidden.GameData.Timer.Value
    UI.Timer.Text = Framework.Utility.Number.FormatTime(text)
end
local function updateMineCount()
    local count = Hidden.GameData.MineCount.Value
    MineUI.Mines.Text = count
end
local function updateMineVisibility()
    local visible = Hidden.GameData.GameActive.Value
    MineUI.Visible = visible
end



function module.New(self)

    Hidden.GameData.Status.PropertyChanged:Connect(updateStatus)
    Hidden.GameData.Timer.PropertyChanged:Connect(updateTimer)
    Hidden.GameData.MineCount.PropertyChanged:Connect(updateMineCount)
    Hidden.GameData.GameActive.PropertyChanged:Connect(updateMineVisibility)


    updateStatus()
    updateTimer()
    updateMineCount()
    updateMineVisibility()

    return self
end


return module