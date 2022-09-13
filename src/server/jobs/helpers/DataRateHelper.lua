--[[
    File: DataRateHelper.lua
    Author(s): FriendlyBiscuit
    Created: 08/18/2022 @ 15:48:37
    
    Description:
        Provides a set of promisified methods to wait for data budgets and rate limits.
        
        Now tracks key rate limits experience-wide with MemoryStore!
        
        Be sure to add "---@module DataRateHelper" after you require this module if
        you want access to inline documentation.
    
    Documentation:
        No documentation provided.
--]]

--= Module Loader =--
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local DataRateHelper = { TickRate = 1 }

--= Classes & Jobs =--
local Promise = require('$Promise') ---@module Promise
local Logger = require('$Logger') ---@module Logger
local MemoryStoreHelper = require('MemoryStoreHelper') ---@module MemoryStoreHelper

--= Roblox Services =--
local dataService = game:GetService('DataStoreService')
local memoryService = game:GetService('MemoryStoreService')
local playerService = game:GetService('Players')

--= Object References =--
local writeKeyMap = memoryService:GetSortedMap('DataRateHelper_Writes')
local console = Logger.new('DataRateHelper')

--= Constants =--
local VERBOSE_OUTPUT = false
local SAME_KEY_DELAY = 6.2
local CACHE_KEY_FORMAT = '%s.%s.%s'
local WRITE_TYPES = { 'SetIncrementedSortedAsync', 'UpdateAsync', 'SetIncrementAsync' }
local READ_TYPES = { 'GetAsync', 'GetSortedAsync' }

--= Variables =--
local rateCache = { }
local mainQueue = { }
local tempBlockedKeys = { }

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
function DataRateHelper:ResolveWhenReady(datastore: DataStore, requestType: string|Enum.DataStoreRequestType, key: string): Promise
    local queueData = {
        OID = #mainQueue + 1,
        DataStore = datastore,
        RequestType = requestType,
        Key = key,
        Event = Instance.new('BindableEvent')
    }
    
    table.insert(mainQueue, queueData)
    
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
function DataRateHelper:WaitUntilReady(datastore: DataStore, requestType: string|Enum.DataStoreRequestType, key: string)
    local queueData = {
        OID = #mainQueue + 1,
        DataStore = datastore,
        RequestType = requestType,
        Key = key,
        Event = Instance.new('BindableEvent')
    }
    
    table.insert(mainQueue, queueData)
    
    queueData.Event.Event:Wait()
    queueData.Event:Destroy()
end

--= Job Initializers =--
function DataRateHelper:Tick() ---@deprecated
    tempBlockedKeys = { }
    
    for key, lastTick in rateCache do
        if (tick() - lastTick) > 15 then
            console:Print('Cleaned up unused rate cache key %s', key)
            rateCache[key] = nil
        end
    end
    
    for index, queueItem in mainQueue do
        local targetStore = queueItem.DataStore
        local requestType = queueItem.RequestType
        local event = queueItem.Event
        
        if requestType == 'List' then
            local cacheKey = targetStore.Name .. '.LIST'
            
            if not rateCache[cacheKey] then
                rateCache[cacheKey] = 0
            end
            
            local numPlayers = #playerService:GetPlayers()
            local trueDelay = 60 / (5 + (numPlayers * 2))
            
            if (tick() - rateCache[cacheKey]) >= trueDelay then
                rateCache[cacheKey] = tick()
                event:Fire()
                console:Print('List-wait success for %s (OID: %d, remaining queue: %d)', targetStore.Name, queueItem.OID, #mainQueue - 1)
                table.remove(mainQueue, index)
                break
            end
        else
            if type(requestType) == 'string' then
                requestType = Enum.DataStoreRequestType[requestType]
            end
            
            if _hasRequestBudget(requestType) then
                local cacheKey = CACHE_KEY_FORMAT:format(targetStore.Name, requestType.Name, (queueItem.Key or '_DEFAULT'))
                
                if not rateCache[cacheKey] then rateCache[cacheKey] = 0 end
                
                if table.find(READ_TYPES, requestType.Name) then
                    local numPlayers = #playerService:GetPlayers()
                    local trueDelay = 60 / (60 + (numPlayers * 10))
                    
                    if (tick() - rateCache[cacheKey]) >= trueDelay and not tempBlockedKeys[cacheKey] then
                        rateCache[cacheKey] = tick()
                        event:Fire()
                        console:Print('Read-wait success for %s (OID: %d, remaining queue: %d)', cacheKey, queueItem.OID, #mainQueue - 1)
                        table.remove(mainQueue, index)
                    else
                        tempBlockedKeys[cacheKey] = true
                    end
                elseif table.find(WRITE_TYPES, requestType.Name) then
                    if (tick() - rateCache[cacheKey]) >= SAME_KEY_DELAY and not tempBlockedKeys[cacheKey]  then
                        local success, blocked = MemoryStoreHelper:GetMapAsync(writeKeyMap, cacheKey):await()
                        
                        if success and not blocked then
                            MemoryStoreHelper:SetMapAsync(writeKeyMap, cacheKey, true, 6.25)
                            rateCache[cacheKey] = tick()
                            event:Fire()
                            console:Print('Write-wait success for %s (OID: %d, remaining queue: %d)', cacheKey, queueItem.OID, #mainQueue - 1)
                            table.remove(mainQueue, index)
                        else
                            tempBlockedKeys[cacheKey] = true
                        end
                    else
                        tempBlockedKeys[cacheKey] = true
                    end
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