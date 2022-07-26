--[[
    File: InfinityServer.server.lua
    Author(s): FriendlyBiscuit
    Created: 07/21/2022 @ 15:56:56
    
    Description:
        Executes the default server jobs folder.
--]]

--= Dependencies =--
local InfinityLoader = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Object References =--
local contextRoot = game.ServerScriptService:WaitForChild('InfinityServer')
local sharedRoot = game.ReplicatedStorage:WaitForChild('InfinityShared')

--= Constants =--
local ALLOWED_MEMBERS = {
    'Stepped',
    'Heartbeat',
    'Initialize',
    'PlayerAdded',
    'PlayerRemoving',
    'Run',
    'Tick',
    'Update'
}

--= Prepare Global Require =--
setmetatable(shared, {
    __call = function(_, target: ModuleScript|string)
        return InfinityLoader(target)
    end
})

--= Start Server Jobs =--
local InfinityExecutor = require(game.ReplicatedStorage:WaitForChild('InfinityExecutor'))
InfinityExecutor:ExecuteFolder(contextRoot:WaitForChild('jobs'), ALLOWED_MEMBERS)
InfinityExecutor:ExecuteFolder(sharedRoot:WaitForChild('jobs'), ALLOWED_MEMBERS)