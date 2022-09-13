--[[
    Stepped.lua
    By FriendlyBiscuit
    05/02/2022 @ 15:57:38
    
    Description:
        Infinity 6 built-in Stepped event connector.
--]]

local runService = game:GetService('RunService')

return {
    Aliases = { 'Stepped', 'OnStepped' },
    ExecutionOrder = 7,
    PromiseType = 'None',
    Handle = function(jobModule: {}, callback: (self: {}) -> ())
        runService.Stepped:Connect(function(...)
            callback(jobModule, ...)
        end)
    end
}