--[[
    RateLimiter.lua
    FriendlyBiscuit
    Created on 02/23/2022 @ 13:56:40
    
    Description:
        A super simple timed-based rate limiter.
    
    Documentation:
        Functions:
            <RateLimiter> .new()
            -> Creates and returns the RateLimiter object.
            
            <nil> ::Trigger(key: string)
            -> Triggers the rate limiter time for the specified key, if it is already
            registered.
            
            <nil> ::Register(key: string, timer: number)
            -> Registers the specified key with the rate limiter object with the specified
            timer.
            
            <boolean> ::IsLimited(key: string)
            -> Returns whether or not the specified rate limiter key is limited/triggered.
        
        Properties:
            boolean Enabled
            -> Enables/disables all registered rate limiters on this object. NOTE: when set to false
               all registered limiters will immediately be un-limited. Use with caution!
--]]

--= Module Loader =--
local require               = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Class Root =--
local RateLimiter           = { }
RateLimiter.__classname     = 'RateLimiter'

--= Type Export =--
export type RateLimiter     = {
    Enabled: boolean,
    Register: (limiterName: string, limitTime: number) -> (),
    Trigger: (limiterName: string) -> (),
    IsLimited: (limiterName: string) -> boolean
}

--= Other Classes =--
local Logger                = require('$classes/Logger')

--= Modules & Config =--
local classify              = require('$lib/Classify')

--= Roblox Services =--
local run_svc               = game:GetService('RunService')

--= Class Internal =--
function RateLimiter:_get_limiter(key: string): table|nil
    for _, limiter in pairs(self._limiters) do
        if limiter.key == key then
            return limiter
        end
    end
    
    return nil
end

--= Class API =--
function RateLimiter:Trigger(key: string)
    local limiter = self:_get_limiter(key)
    
    if limiter then
        limiter.last_trigger = tick()
        limiter.limited = true
    else
        self._log:Warn('Failed to trigger rate limiter %q - no limiter is registered!', key)
    end
end

function RateLimiter:Register(key: string, timer: number)
    local limiter = self:_get_limiter(key)
    
    if limiter then
        limiter = {
            key = key,
            timer = timer,
            limited = false,
            last_trigger = 0
        }
    else
        table.insert(self._limiters, {
            key = key,
            timer = timer,
            limited = false,
            last_trigger = 0
        })
    end
end

function RateLimiter:IsLimited(key: string): boolean
    local limiter = self:_get_limiter(key)
    
    if limiter then
        return limiter.limited
    else
        self._log:Warn('Failed to check if rate limiter %q is limited - no limiter is registered!', key)
    end
end

--= Class Constructor =--
function RateLimiter.new(): RateLimiter
    local self = classify(RateLimiter)
    
    self._limiters = { }
    self._iterating = false
    self._enabled = true
    self._log = Logger.new('RateLimiter')
    
    self:_mark_disposables({
        self._log,
        
        run_svc.Stepped:Connect(function()
            if not self._enabled or self._iterating then return end
            self._iterating = true
            
            for _, limiter in pairs(self._limiters) do
                if limiter.limited and (tick() >= limiter.last_trigger + limiter.timer) then
                    limiter.limited = false
                end
            end
            
            self._iterating = false
        end)
    })
    
    return self
end

--= Class Properties =--
RateLimiter.__properties = {
    Enabled = {
        get = function(self) return self._enabled end,
        set = function(self, value: boolean)
            self._enabled = value
            
            if not value then
                for _, limiter in pairs(self._limiters) do
                    limiter.last_trigger = 0
                    limiter.limited = false
                end
            end
        end
    }
}

--= Return Class =--
return RateLimiter