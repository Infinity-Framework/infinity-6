--[[
    RenderStepped.lua
    By FriendlyBiscuit
    05/02/2022 @ 15:57:38
    
    Description:
        Infinity 6 built-in RenderStepped event connector.
--]]

local runService = game:GetService('RunService')

return {
    Aliases = { 'RenderStepped', 'OnRenderStepped' },
    ExecutionOrder = 9,
    PromiseType = 'None',
    Handle = function(jobModule: {}, callback: (self: {}) -> ())
        runService.RenderStepped:Connect(function(...)
            callback(jobModule, ...)
        end)
    end
}