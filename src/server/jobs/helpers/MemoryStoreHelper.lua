--[[
    File: MemoryStoreHelper.lua
    Author(s): FriendlyBiscuit
    Created: 08/15/2022 @ 23:19:00
    
    Description:
        No description provided.
    
    Documentation:
        No documentation provided.
--]]

--= Module Loader =--
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local MemoryStoreHelper = { }

--= Classes & Jobs =--
local Promise = require('$Promise') ---@module Promise
local Logger = require('$Logger') ---@module Logger

--= Object References =--
local console = Logger.new('MemoryStoreHelper')

--= Constants =--
local VERBOSE_OUTPUT = true
local RETRY_COUNT = 5
local RETRY_DELAY = 0.5
local DEFAULT_EXPIRE_TIME = 3888000

--= Internal Functions =--
local function _addQueueAsyncPromise(queue: MemoryStoreQueue, value: any, priority: number, expiration: number): Promise
    return Promise.new(function(resolve: () -> ())
        queue:AddAsync(value, expiration, priority)
        resolve()
    end)
end

local function _readQueueAsyncPromise(queue: MemoryStoreQueue, count: number, allOrNothing: boolean, timeout: number): Promise
    return Promise.new(function(resolve: ({}, string) -> ())
        local data, clearKey = queue:ReadAsync(count, allOrNothing, timeout)
        resolve(clearKey, data)
    end)
end

local function _getMapAsyncPromise(map: MemoryStoreSortedMap, key: string): Promise
    return Promise.new(function(resolve: (any) -> ())
        local data = map:GetAsync(key)
        resolve(data)
    end)
end

local function _setMapAsyncPromise(map: MemoryStoreSortedMap, key: string, value: any, expiration: number): Promise
    return Promise.new(function(resolve: (any) -> ())
        map:SetAsync(key, value, expiration)
        resolve()
    end)
end

local function _updateMapAsyncPromise(map: MemoryStoreSortedMap, key: string, callback: (any) -> any, expiration: number): Promise
    return Promise.new(function(resolve: (any) -> ())
        local latest = map:UpdateAsync(key, callback, expiration)
        resolve(latest)
    end)
end

local function _removeMapAsyncPromise(map: MemoryStoreSortedMap, key: string): Promise
    return Promise.new(function(resolve: () -> ())
        map:RemoveAsync(key)
        resolve()
    end)
end

--= Job API =--

---Returns a Promise that will resolve with the specified value of the key if it exists.
---@param map MemoryStoreSortedMap The MemoryStoreSortedMap you're querying.
---@param key string The key to fetch from the sorted map.
---@meta
function MemoryStoreHelper:GetMapAsync(map: MemoryStoreSortedMap, key: string): Promise
    return Promise.retryWithDelay(_getMapAsyncPromise, RETRY_COUNT, RETRY_DELAY, map, key)
end

---Returns a Promise that will resolve when the specified key is written to.
---@param map MemoryStoreSortedMap The MemoryStoreSortedMap you're querying.
---@param key string The key to write to.
---@param value any The value to write.
---@param expiration number? Optional expiration time in seconds. ***[default=3888000]*
---@meta
function MemoryStoreHelper:SetMapAsync(map: MemoryStoreSortedMap, key: string, value: any, expiration: number?): Promise
    expiration = expiration or DEFAULT_EXPIRE_TIME
    return Promise.retryWithDelay(_setMapAsyncPromise, RETRY_COUNT, RETRY_DELAY, map, key, value, expiration)
end

---Returns a Promise that will resolve when the specified key is written to.
---@param map MemoryStoreSortedMap The MemoryStoreSortedMap you're querying.
---@param key string The key to update.
---@param callback function The transformation function to run on the old data. Must return new data.
---@param expiration number number? Optional expiration time in seconds. ***[default=3888000]*
---@meta
function MemoryStoreHelper:UpdateMapAsync(map: MemoryStoreSortedMap, key: string, callback: (any) -> any, expiration: number?): Promise
    expiration = expiration or DEFAULT_EXPIRE_TIME
    return Promise.retryWithDelay(_updateMapAsyncPromise, RETRY_COUNT, RETRY_DELAY, map, key, callback, expiration)
end

---Returns a Promise that will resolve when the specified key is removed.
---@param map MemoryStoreSortedMap The MemoryStoreSortedMap you're querying.
---@param key string The key to remove.
---@meta
function MemoryStoreHelper:RemoveMapAsync(map: MemoryStoreSortedMap, key: string): Promise
    return Promise.retryWithDelay(_removeMapAsyncPromise, RETRY_COUNT, RETRY_DELAY, map, key)
end

---Returns a Promise that will resolve when the specified key is added to the queue.
---@param queue MemoryStoreQueue The MemoryStoreQueue you're querying.
---@param value any The data to add to the queue.
---@param priority number? Optional priority. **[default=0]**
---@param expiration number? Optional expiration time in seconds. **[default=3888000]**
---@meta
function MemoryStoreHelper:AddQueueAsync(queue: MemoryStoreQueue, value: any, priority: number?, expiration: number?): Promise
    priority = priority or 0
    expiration = expiration or DEFAULT_EXPIRE_TIME
    return Promise.retryWithDelay(_addQueueAsyncPromise, RETRY_COUNT, RETRY_DELAY, queue, value, priority, expiration)
end

---Returns a Promise that will resolve with the RemoveAsync clear key as well as the resulting queue items.
---@param queue MemoryStoreQueue The MemoryStoreQueue you're querying.
---@param count number? Optional number of items to fetch. **[default=1]**
---@param allOrNothing boolean? Optional all-or-nothing specifier. **[default=false]**
---@param timeout number? Optional expiration time in seconds. **[default=3888000]**
---@meta
function MemoryStoreHelper:ReadQueueAsync(queue: MemoryStoreQueue, count: number?, allOrNothing: boolean?, timeout: number?): Promise
    count = count or 1
    allOrNothing = allOrNothing or false
    timeout = timeout or -1
    return Promise.retryWithDelay(_readQueueAsyncPromise, RETRY_COUNT, RETRY_DELAY, queue, count, allOrNothing, timeout)
end

--= Job Initializers =--
function MemoryStoreHelper:Init() ---@deprecated
    console.LoggingEnbaled = VERBOSE_OUTPUT
end

--= Return Job =--
return MemoryStoreHelper