--[[
    File: BadgeHelper.lua
    Author(s): FriendlyBiscuit
    Created: 07/15/2022 @ 22:41:59
    
    Description:
        Lightweight BadgeService helper job that promisifies the three methods
        that can fail and/or be rate limited.
        
        Each function will make up to 5 (five) attempts to succeed.
    
    Documentation:
        <Promise<void>> ::AwardBadge(target: Player|number, badgeId: number)
        -> Attempts to award the target badge to the target player (or user ID).
            
            -> EXAMPLE 1 - Promise Chain
            -> Uses promise functionality to handle your badge awarding in an async manner.
            
            BadgeHelper:AwardBadge(12345, 67890):andThen(function()
                print("Successfully awarded the badge!")
            end):catch(function()
                print("Failed to award badge.")
            end):await() -- use :await() if you want this promise to yield the current scope
            
            -> EXAMPLE 2 - "Fire and Forget"
            -> Attempt to award the badge and not care if it succeeds or not.
            
            BadgeHelper:AwardBadge(12345, 67890) -- no :await() = will attempt to award async
        
        <Promise<boolean>> ::HasBadge(target: Player|number, badgeId: number)
        -> Attempts to fetch whether or not the target player (or user ID) owns the target badge.
            
            -> EXAMPLE 1 - Promise Chain
            -> Uses promise functionality to handle your badge check in an async manner.
            
            BadgeHelper:HasBadge(12345, 67890):andThen(function(hasBadge: boolean)
                print("User has badge?", hasBadge)
            end):await() -- use :await() if you want this promise to yield the current scope
            
            -> EXAMPLE 2 - Vanilla-like
            -> Similar to how you would normally do it with Roblox's API.
            
            local hasBadge = BadgeHelper:HasBadge(12345, 67890):expect()
            print("User has badge?", hasBadge)
            
        <Promise<table|nil>> ::GetBadgeInfo(badgeId: number)
        -> Attempts to fetch a badge's information.
            
            -> EXAMPLE 1 - Promise Chain
            -> Uses promise functionality to handle your badge information fetch in an async manner.
            
            BadgeHelper:GetBadgeInfo(67890):andThen(function(badgeInfo: {})
                print("Badge Info:", badgeInfo)
            end):await() -- use :await() if you want this promise to yield the current scope
            
            -> EXAMPLE 2 - Vanilla-like
            -> Similar to how you would normally do it with Roblox's API.
            
            local badgeInfo = BadgeHelper:GetBadgeInfo(67890):expect()
            print("Badge Info:", badgeInfo)
--]]

--= Module Loader =--
local require           = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local BadgeHelper       = { }

--= Classes & Jobs =--
local Promise           = require('$Promise') ---@module Promise
local Logger            = require('$Logger') ---@module Logger

--= Roblox Services =--
local badgeService      = game:GetService('BadgeService')
local runService        = game:GetService('RunService')

--= Object References =--
local console           = Logger.new('BadgeHelper')

--= Constants =--
local DEFAULT_RETRIES   = 5
local MESSAGES          = {
    STUDIO_MODE         = 'Running in Studio Environment Mode. Badge awarding will be faked.';
    FAKE_AWARD          = 'Fake-awarding badge %d to user %d (studio testing mode).';
    AWARD_FAIL          = 'Failed to award badge %d - supplied target user/ID is not valid.';
    CHECK_FAIL          = 'Failed to check if user owns badge %d - supplied target user/ID is not valid.';
}

--= Internal Functions =--
local function _resolveToId(query: Player|number): number|nil
    if type(query) == 'number' then
        return query
    elseif type(query) == 'userdata' and query:IsA('Player') then
        return query.UserId
    end
    
    return nil
end

local function _ownsBadgePromise(userId: number, badgeId: number): Promise
    return Promise.new(function(resolve: (boolean) -> ())
        local result = badgeService:UserHasBadgeAsync(userId, badgeId)
        resolve(result)
    end)
end

local function _awardBadgePromise(userId: number, badgeId: number): Promise
    return Promise.new(function(resolve: (boolean) -> (), reject: () -> ())
        if runService:IsStudio() then
            console:Print(MESSAGES.FAKE_AWARD, badgeId, userId)
            return resolve()
        end
        
        local result = badgeService:AwardBadge(userId, badgeId)
        
        if result then
            resolve()
        end
        
        reject()
    end)
end

local function _getBadgeInfoPromise(badgeId: number): Promise
    return Promise.new(function(resolve: ({}) -> ())
        local result = badgeService:GetBadgeInfoAsync(badgeId)
        resolve(result)
    end)
end

--= Job API =--

---Attempts to award a badge to the specified player.
---
---Will attempt up to 5 times before returning a rejected Promise.
---@param target Player|number The target player object **or** user ID you want to award the badge to.
---@param badgeId number The badge ID to reward.
---@meta
function BadgeHelper:AwardBadge(target: Player|number, badgeId: number): Promise
    target = _resolveToId(target)
    
    if not target then
        console:Warn(MESSAGES.AWARD_FAIL, badgeId)
        return Promise.reject()
    end
    
    local hasBadge = BadgeHelper:HasBadge(target, badgeId):expect()
    
    if not hasBadge then
        return Promise.retryWithDelay(_awardBadgePromise, DEFAULT_RETRIES, 1, target, badgeId)
    else
        return Promise.resolve()
    end
end

---Attempts to fetch whether or not the specified player owns a badge.
---
---Will attempt up to 5 times before returning a rejected Promise.
---
---If it succeeds, it will return a resolved Promise where the resolved value is `true` or `false`.
---@param target Player|number The target player object **or** user ID you want to check.
---@param badgeId number The badge ID to check for.
---@meta
function BadgeHelper:HasBadge(target: Player|number, badgeId: number): Promise
    target = _resolveToId(target)
    
    if not target then
        console:Warn(MESSAGES.CHECK_FAIL, badgeId)
        return Promise.reject()
    end
    
    return Promise.retryWithDelay(_ownsBadgePromise, DEFAULT_RETRIES, 1, target, badgeId)
end

---Attempts to fetch the specified badge's information from the Roblox website.
---
---Will attempt up to 5 times before returning a rejected Promise.
---
---If it succeeds, it will return a resolved Promise where the resolved value is the table of information.
---@param badgeId number The badge ID you wish to fetch information from.
---@meta
function BadgeHelper:GetBadgeInfo(badgeId: number): Promise
    return Promise.retryWithDelay(_getBadgeInfoPromise, DEFAULT_RETRIES, 1, badgeId)
end

--= Job Initializers =--
function BadgeHelper:Immediate() ---@deprecated
    if runService:IsStudio() then
        console:Warn(MESSAGES.STUDIO_MODE)
    end
end

--= Return Job =--
return BadgeHelper