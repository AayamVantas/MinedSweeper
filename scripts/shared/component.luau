local module = {}
module.__index = module
local Framework = require(Hidden.Framework)
function module.New(object)
    local self = setmetatable({},module)
    self.Object = object
    self.Maid = Framework.Class.New("Maid")
    return self
end

return module