--[[
    Tick.lua
    By FriendlyBiscuit
    05/01/2022 @ 22:36:00
    
    Description:
        No description provided.
--]]

local runService = game:GetService('RunService')
local updates = { }

return {
    Aliases = { 'Update' },
    ExecutionOrder = 4,
    Preload = function()
        if runService:IsClient() then
            runService.RenderStepped:Connect(function()
                for _, update in pairs(updates) do
                    if tick() - update.LastUpdate >= update.UpdateRate and not update.Updating then
                        update.Updating = true
                        update.Callback(update)
                        update.LastUpdate = tick()
                        update.Updating = false
                    end
                end
            end)
        else
            runService.Stepped:Connect(function()
                for _, update in pairs(updates) do
                    if tick() - update.LastUpdate >= update.UpdateRate and not update.Updating then
                        update.Updating = true
                        update.Callback(update)
                        update.LastUpdate = tick()
                        update.Updating = false
                    end
                end
        end)
        end
    end,
    Handle = function(jobModule: {}, callback: (self: {}) -> ())
        table.insert(updates, {
            Callback = callback,
            UpdateRate = jobModule.UpdateRate or 1,
            LastUpdate = 0,
            Updating = false
        })
    end
}