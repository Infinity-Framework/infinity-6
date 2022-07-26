--[[
    File: InfinityClient.client.lua
    Author(s): FriendlyBiscuit
    Created: 07/21/2022 @ 15:29:02
    
    Description:
        Executes the default client jobs folder.
--]]

--= Dependencies =--
local InfinityLoader = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Object References =--
local contextRoot = game.Players.LocalPlayer:WaitForChild('PlayerScripts'):WaitForChild('InfinityClient')
local sharedRoot = game.ReplicatedStorage:WaitForChild('InfinityShared')

--= Prepare Global Require =--
setmetatable(shared, {
    __call = function(_, target: ModuleScript|string)
        return InfinityLoader(target)
    end
})

--= Start Client Jobs =--
local InfinityExecutor = require(game.ReplicatedStorage:WaitForChild('InfinityExecutor'))
InfinityExecutor:ExecuteFolder(contextRoot:WaitForChild('jobs'))
InfinityExecutor:ExecuteFolder(sharedRoot:WaitForChild('jobs'))