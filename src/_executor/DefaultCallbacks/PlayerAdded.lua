--[[
    PlayerAdded.lua
    By FriendlyBiscuit
    05/01/2022 @ 22:17:08
    
    Description:
        Infinity 6 built-in PlayerAdded event connector.
--]]

local playerService = game:GetService('Players')
local runService = game:GetService('RunService')

return {
    Aliases = { 'PlayerAdded', 'PlayerJoined', 'PlayerJoin' },
    ExecutionOrder = 5,
    Handle = function(jobModule: {}, callback: (self: {}, client: Player) -> ())
        playerService.PlayerAdded:Connect(function(client: Player)
            callback(jobModule, client)
        end)
        
        if runService:IsStudio() then
            for _, player in pairs(playerService:GetPlayers()) do
                callback(jobModule, player)
            end
        end
    end
}