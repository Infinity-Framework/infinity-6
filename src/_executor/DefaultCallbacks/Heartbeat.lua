--[[
    Heartbeat.lua
    By FriendlyBiscuit
    05/02/2022 @ 15:57:38
    
    Description:
        Infinity 6 built-in Heartbeat event connector.
--]]

local runService = game:GetService('RunService')

return {
    Aliases = { 'Heartbeat', 'OnHeartbeat' },
    ExecutionOrder = 8,
    PromiseType = 'None',
    Handle = function(jobModule: {}, callback: (self: {}) -> ())
        runService.Heartbeat:Connect(function(...)
            callback(jobModule, ...)
        end)
    end
}