local module = {}
module.__index = module


function module.WeightedRarity(list, luck)
    local totalWeight = 0
    local p = 1 / math.max(luck or 1, 0.001) or 1

    for _, v in next, list do
        if not v and v.Weight then continue end
        print(v.Display,v.Weight)
        totalWeight += ((v.Weight or 0) ^ (p or 1))
    end

    local randomWeight = math.random() * totalWeight

    for _, v in next, list do
        if not v and v.Weight then continue end
        local weight = (v.Weight or 0) ^ (p or 1)
        if randomWeight <= weight then return v end
        randomWeight -= weight
    end
    return
end


function module.FormatTime(time)

    local mins = math.floor(time / 60) % 60
    local secs = time % 60
    return string.format("%02d:%02d",mins, secs)
end

function module.Clamp(x,min,max)
    return math.min(math.max(x,min),max)
end

return module