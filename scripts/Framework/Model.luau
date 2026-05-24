local module = {}
module.__index = module

-- function module.GetDescendants(instance,list)
--     list = list or {}

--     for _,v in next, instance:GetChildren() do
--         table.insert(list,v)
        
--         if next(v:GetChildren()) then
--             module.GetDescendants(v,list)
--         end
--     end
--     return list
-- end
function module.HasAncestor(instance,ancestorName)
    local ancestor = instance
    repeat
        ancestor = ancestor.Parent
        if ancestor.Name == ancestorName then return true end
    until ancestor == world
    return false
end
return module