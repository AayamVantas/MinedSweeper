local module = {}

module.__index = module
module.Derives = "Component"

function module.New(self)
    self.Object.CanCollide = false
    self.Object.Color -= Color.New(0,0,0,1)

    return self
end

return module