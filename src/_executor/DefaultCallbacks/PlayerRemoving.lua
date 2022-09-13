--[[
    PlayerRemoving.lua
    By FriendlyBiscuit
    05/01/2022 @ 22:20:44
    
    Description:
        Infinity 6 built-in PlayerRemoving event connector.
--]]

local playerService = game:GetService('Players')

return {
    Aliases = { 'PlayerRemoved', 'PlayerRemoving', 'PlayerLeft', 'PlayerLeave' },
    ExecutionOrder = 6,
    Handle = function(jobModule: {}, callback: (self: {}, client: Player) -> ())
        playerService.PlayerRemoving:Connect(function(client: Player)
            callback(jobModule, client)
        end)
    end
}