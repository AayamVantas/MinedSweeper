local Framework = require(Hidden.Framework)
local module = {}
module.__index = module

module.Pools = {}

function module.New(name: string, base: Instance, initialCount: number)
    local self = setmetatable({}, module)
    self.Maid = Framework.Class.New("Maid")
    self.Objects = {}
    self.Base = base
    self.PoolName = name

    local folder = Instance.New("Folder", Hidden.Temp)
    folder.Name = name

    self:Expand(initialCount)

    module.Pools[name] = self
    return self
end

function module.GetPool(name: string)
    return assert(module.Pools[name], `Can't find {name} in the instance pools!`)
end

function module:Expand(count: number)
    local folder = Hidden.Temp[self.PoolName]
    for i = 1, count do
        local clone = self.Base:Clone(folder)
        clone.Parent = nil
        table.insert(self.Objects, clone)
    end
end

function module:Get(count: number?)
    local folder = Hidden.Temp[self.PoolName]
    
    if not count or count == 1 then
        local instance = table.remove(self.Objects) or self.Base:Clone(folder)
        instance.Parent = nil
        return instance
    end

    local list = {}
    for i = 1, count do
        local instance = table.remove(self.Objects) or self.Base:Clone(folder)
        instance.Parent = nil
        table.insert(list, instance)
    end
    return list
end

function module:Return(instance: Instance)
    local folder = Hidden.Temp[self.PoolName]
    if not instance then return end
    
    instance.Parent = folder
    table.insert(self.Objects, instance)
end

function module:Release()
    local folder = Hidden.Temp[self.PoolName]
    for _, obj in self.Objects do
        obj.Parent = folder
    end
end


return module