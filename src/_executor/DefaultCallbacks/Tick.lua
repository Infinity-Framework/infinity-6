--[[
    Tick.lua
    By FriendlyBiscuit
    05/01/2022 @ 22:36:00
    
    Description:
        No description provided.
--]]

local runService = game:GetService('RunService')
local ticks   = { }
local ticking = false

return {
    Aliases = { 'Tick' },
    ExecutionOrder = 3,
    Preload = function()
        if runService:IsClient() then
            runService.RenderStepped:Connect(function()
                if ticking then return end
                ticking = true
                
                for _, tickData in pairs(ticks) do
                    tickData.Frame += 1
                    
                    if tickData.Frame >= tickData.TickRate then
                        tickData.Callback(tickData)
                        tickData.Frame = 0
                    end
                end
                
                ticking = false
            end)
        else
            runService.Stepped:Connect(function()
                if ticking then return end
                ticking = true
                
                for _, tickData in pairs(ticks) do
                    tickData.Frame += 1
                    
                    if tickData.Frame >= tickData.TickRate then
                        tickData.Callback(tickData)
                        tickData.Frame = 0
                    end
                end
                
                ticking = false
            end)
        end
    end,
    Handle = function(jobModule: {}, callback: (self: {}) -> ())
        local targetPriority = jobModule.TickPriority or 1
        
        while ticks[targetPriority] do targetPriority += 1 end
        
        table.insert(ticks, targetPriority, {
            Callback = callback,
            TickRate = jobModule.TickRate or 1,
            Frame = 0
        })
    end
}