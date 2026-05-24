local module = {}

function module.Init()
    module.Class = require(script.Class)
    module.Utility = require(script.Utility)
    module._Version = script.Version.Value
    module.Debug = script.Debug
    module.Config = Hidden.GameData.Config
    module.Class.LoadDirectory(Hidden.Shared,true)
end


return module