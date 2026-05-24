local class = {}
class.__index = class
class._classes = {}
class._components = {}
class._activeComponents = {}

class._ready = nil


local Framework = require(script.Parent)
local function debugPrint(...)
    if not Framework.Debug.Value then return end
    print(...)
end
function class.New(name : string, ...)
    debugPrint(`[ClassSystem] Creating new instance of: {name}`)
    local module = class.GetClass(name)
    
    if not module then
        error(`[ClassSystem] Failed to find class: {name}`)
        return nil
    end

    local derives = rawget(module, "Derives") :: string

    if not derives then
        return module.New(...)
    end

    if not getmetatable(module) then
        debugPrint(`[ClassSystem] Setting up inheritance: {name} -> {derives}`)
        local baseModule = class.GetClass(derives)
        setmetatable(module, {__index = baseModule})
        module.__index = module
    end

    local base = class.New(derives, ...)
    if not base then
        error(`could not find super class {derives}`)
    end
    setmetatable(base, module)
    
    local self = module.New(base)
    return self or base
end

function class.GetClass(name : string)
    return class._classes[name]
end

function class.AddComponent(part : Instance, componentName : string)
    local id = guid.new() :: string

    debugPrint(`[ClassSystem] Adding component {componentName} to {part.Name} (ID: {id})`)

    
    local component = class.New(componentName, part)
    if not component then
        debugPrint(`[color=orange][ClassSystem] Failed to initialize component {componentName} for {part.Name}[/color]`)
        return nil
    end
    
    component.ID = id
    
    class._activeComponents[part] = class._activeComponents[part] or {}
    class._activeComponents[part][componentName] = component
    
    return component
end

function class.GetComponent(part : Instance, componentName : string)
    local partComponents = class._activeComponents[part]
    if not partComponents then return nil end
    
    return partComponents[componentName]
end

function class.LoadDirectory(dir : Instance, hasDescendants : boolean)
    debugPrint(`[ClassSystem] Loading directory: {dir.Name}`)
    local descendants = hasDescendants and dir:GetDescendants() or dir:GetChildren()
    
    for _, child in descendants do
        local childName = child.Name

        if not child:IsA("ModuleScript") then continue end
        if Framework.Utility.Model.HasAncestor(child,"Prefab") then return end
        local module = require(child)
        
        if class._classes[childName] then
            debugPrint(`[color=orange][ClassSystem] Class {childName} already exists! skipping...[/color]`)
            continue
        end
        
        debugPrint(`[ClassSystem] Registered class: {childName}`)
        class._classes[childName] = module
        
        if child:HasTag("Component") then
            debugPrint(`[ClassSystem] Registered component tag: {childName}`)
            class._components[childName] = module
        end

        local init = rawget(module, "Init")
        if not init then continue end
        
        debugPrint(`[ClassSystem] Running Init for: {childName}`)
        coroutine.wrap(init)()
    end
end

function class.Start()
    debugPrint("[ClassSystem] Starting all classes...")
    for name, module in class._classes do
        local start = rawget(module, "Start")
        if not start then continue end
        
        debugPrint(`[ClassSystem] Running Start for: {name}`)
        coroutine.wrap(start)()
    end

    debugPrint("[ClassSystem] Initializing tagged components in world...")
    for componentName in class._components do
        local taggedObjects = world:GetDescendantsWithTag(componentName)
        
        for _, object in taggedObjects do
            coroutine.wrap(class.AddComponent)(object, componentName)
        end
    end
end

class.new = class.New

return class