--[[
    File: DataRateHelper.lua
    Author(s): FriendlyBiscuit
    Created: 07/20/2022 @ 14:00:59
    
    Description:
        Provides a set of promisified methods to wait for data budgets and rate limits.
        
        Be sure to add "---@module DataRateHelper" after you require this module if
        you want access to inline documentation.
    
    Documentation:
        No documentation provided.
--]]

--= Module Loader =--
local require               = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local DataRateHelper        = { TickRate = 1 }

--= Classes & Jobs =--
local Promise               = require('$Promise') ---@Promise
local Logger                = require('$Logger') ---@Logger

--= Roblox Services =--
local dataService           = game:GetService('DataStoreService')
local playerService         = game:GetService('Players')

--= Object References =--
local console               = Logger.new('DataRateHelper')

--= Constants =--
local VERBOSE_OUTPUT        = true
local SAME_KEY_DELAY_WRITE  = 6.1
local WRITE_TYPES           = { 'SetIncrementedSortedAsync', 'UpdateAsync', 'SetIncrementAsync' }
local READ_TYPES            = { 'GetAsync', 'GetSortedAsync' }

--= Variables =--
local rateCache             = { }
local yieldQueue            = { }

--= Internal Functions =--
local function _hasRequestBudget(requestType: Enum.DataStoreRequestType): boolean
    return dataService:GetRequestBudgetForRequestType(requestType) > 0
end

--= Job API =--

---Returns a Promise that will resolve when the specified `key` is ready to be
---modified with the specified `requestType` to respect Roblox rate limits.
---@param datastore DataStore The DataStore object that you're querying.
---@param requestType Enum.DataStoreRequestType The request type to check rate limits for.
---@param key string The key to check rate limits for.
---@meta
function DataRateHelper:ResolveWhenReady(datastore: DataStore, requestType: Enum.DataStoreRequestType, key: string): Promise
    local queueData = {
        OID = #yieldQueue + 1,
        DataStore = datastore,
        RequestType = requestType,
        Key = key,
        Event = Instance.new('BindableEvent')
    }
    
    table.insert(yieldQueue, queueData)
    
    return Promise.new(function(resolve: () -> ())
        local finishEvent = queueData.Event
        
        finishEvent.Event:Once(function()
            finishEvent:Destroy()
            resolve()
        end)
    end)
end

---Yields the current thread until the specified `key` is ready to be
---modified with the specified `requestType` to respect Roblox rate limits.
---@param datastore DataStore The DataStore object that you're querying.
---@param requestType Enum.DataStoreRequestType The request type to check rate limits for.
---@param key string The key to check rate limits for.
---@meta
function DataRateHelper:WaitUntilReady(datastore: DataStore, requestType: Enum.DataStoreRequestType, key: string)
    local queueData = {
        OID = #yieldQueue + 1,
        DataStore = datastore,
        RequestType = requestType,
        Key = key,
        Event = Instance.new('BindableEvent')
    }
    
    table.insert(yieldQueue, queueData)
    
    queueData.Event.Event:Wait()
    queueData.Event:Destroy()
end

--= Job Initializers =--
function DataRateHelper:Tick() ---@deprecated
    for cacheKey, lastTick in rateCache do
        if (tick() - lastTick) > 300 then
            rateCache[cacheKey] = nil
            console:Print('Cleaned up 5 minute-old rate cache for %q', cacheKey)
        end
    end
    
    for index, queueItem in yieldQueue do
        local targetStore = queueItem.DataStore
        local requestType = queueItem.RequestType
        local event = queueItem.Event
        local cacheKey = targetStore.Name .. requestType.Name .. queueItem.Key
        
        if not rateCache[cacheKey] then
            rateCache[cacheKey] = 0
        end
        
        if _hasRequestBudget(requestType) then
            if table.find(READ_TYPES, requestType.Name) then
                local numPlayers = #playerService:GetPlayers()
                local trueDelay = 60 / (60 + (numPlayers * 10))
                
                if (tick() - rateCache[cacheKey]) >= trueDelay then
                    rateCache[cacheKey] = tick()
                    event:Fire()
                    console:Print('Read-wait success (OID: %d, remaining queue: %d)', queueItem.OID, #yieldQueue - 1)
                    table.remove(yieldQueue, index)
                    break
                end
            elseif table.find(WRITE_TYPES, requestType.Name) then
                if (tick() - rateCache[cacheKey]) >= SAME_KEY_DELAY_WRITE then
                    rateCache[cacheKey] = tick()
                    event:Fire()
                    console:Print('Write-wait success (OID: %d, remaining queue: %d)', queueItem.OID, #yieldQueue - 1)
                    table.remove(yieldQueue, index)
                    break
                end
            end
        end
    end
end

function DataRateHelper:Init() ---@deprecated
    console.LoggingEnabled = VERBOSE_OUTPUT
end

--= Return Job =--
return DataRateHelper