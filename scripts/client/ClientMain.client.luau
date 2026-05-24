--[[
    EULA
    
    This Software is provided subject to the following terms:
    
    Permission is hereby granted to use and modify this Framework, 
    provided that the original watermark, or branding notice remains 
    intact and visible in the source code and any resulting output. 
    
    This license is supplemental to the Polytoria Terms 
    of Service. Users must also abide by all platform-specific 
    agreements regarding asset distribution.
    
    Removal or modification of the watermark constitutes a 
    breach of this license and terminates your right to use this Framework.
    
    
    
    Copyright (c) 2026 Dr.AV
]]

print(
	string.format(
	"This World Utilizes Dr.AV's Framework version %s, which can be found at https://polytoria.com/places/21175",
		Hidden.Framework.Version.Value
	)
)
local Framework = require(Hidden.Framework)
Framework.Init()

Framework.IsClient = true
Framework.Class.LoadDirectory(script.Main,true)
Framework.Class.Start()
ScriptService.Events.Ready:InvokeServer(NetMessage.New())