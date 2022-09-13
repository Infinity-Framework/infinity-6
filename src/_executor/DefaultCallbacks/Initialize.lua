--[[
    Initialize.lua
    By FriendlyBiscuit
    05/01/2022 @ 22:16:23
    
    Description:
        Infinity 6 built-in yielding callback.
--]]

return {
    Aliases = { 'Init', 'Initialize' },
    ExecutionOrder = 0,
    PromiseType = 'Yield',
    Handle = function(jobModule: {}, callback: (self: {}) -> ())
        callback(jobModule)
    end
}