local Framework = require(Hidden.Framework)
Framework.Init()

Framework.IsClient = false
Framework.Class.LoadDirectory(script.Main,true)
Framework.Class.Start()


ScriptService.Events.Ready.InvokedServer:Connect(function(sender) 
    sender:AddTag("Ready")
end)