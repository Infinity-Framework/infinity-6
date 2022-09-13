--[[
    File: MarketHelper2.lua
    Author(s): FriendlyBiscuit
    Created: 09/02/2022 @ 17:32:46
    
    Description:
        No description provided.
    
    Documentation:
        No documentation provided.
--]]

--= Module Loader =--
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local MarketHelper2 = { UpdateRate = 0.03 }

--= Classes & Jobs =--
local Promise = require('$Promise') ---@module Promise
local Logger = require('$Logger') ---@module Logger
local MemoryStoreHelper = require('MemoryStoreHelper') ---@module MemoryStoreHelper
local InsertHelper = require('InsertHelper') ---@module InsertHelper

--= Dependencies =--
local JSONCompressor = require('$JSONCompressor') ---@module JSONCompressor
local network = require('$Network')

--= Roblox Services =--
local memoryService = game:GetService('MemoryStoreService')
local marketService = game:GetService('MarketplaceService')

--= Object References =--
local marketCacheMap = memoryService:GetSortedMap('MarketHelper2_Cache')
local console = Logger.new('MarketHelper2')

--= Constants =--
local VERBOSE_OUTPUT = false
local FLUSH = false
local BUDGET_REFILL_DELAY = 1.51
local RETRY_DELAY = 3
local RETRY_MAX = 5
local MAX_CACHE_ATTEMPTS = 2
local LOCAL_FETCH_BUDGET = 40
local LOCAL_ROLLING_CACHE_MAX = 500
local GLOBAL_CACHE_EXPIRATION = 60
local STRIPPED_DATA_KEYS = {
    'AllowedSaleLocations',
    'AssetId',
    'CanBeSoldInThisGame',
    'ContentRateTypeId',
    'Created',
    'Description',
    'IsLimited',
    'IsLimitedUnique',
    'IsPublicDomain',
    'MinimumMembershipLevel',
    'ProductType',
    'TargetId',
    'Updated'
}

--= Variables =--
local localBudget = LOCAL_FETCH_BUDGET
local localCache = { }
local localQueue = { }
local rollingHistory = { }

--= Internal Functions =--
local function _addToRollingCache(productId: number, data: {})
    if table.find(rollingHistory, productId) then return end
    
    table.insert(rollingHistory, productId)
    
    if #rollingHistory > LOCAL_ROLLING_CACHE_MAX then
        local oldestEntry = rollingHistory[1]
        
        if oldestEntry then
            localCache[oldestEntry] = nil
            table.remove(rollingHistory, 1)
        end
    end
    
    localCache[productId] = data
end

local function _isInCacheOrQueueAsync(productId: number): boolean
    if localCache[productId] then return true end
    
    for _, cacheEntry in localQueue do
        if cacheEntry.ProductId == productId then
            return true
        end
    end
    
    local success, globalData = MemoryStoreHelper:GetMapAsync(marketCacheMap, tostring(productId)):await()
    
    if success and globalData then
        local decompressedData = JSONCompressor:Inflate(globalData)
        
        if decompressedData then
            _addToRollingCache(productId, decompressedData)
            return true
        end
    end
    
    return false
end

local function _getProductInfoPromise(productId: number, productType: Enum.InfoType?): Promise
    local localData = localCache[productId]
    
    if localData then
        return Promise.resolve(localData)
    end
    
    local success, globalData = MemoryStoreHelper:GetMapAsync(marketCacheMap, tostring(productId)):await()
    
    if success and globalData then
        local decompressedData = JSONCompressor:Inflate(globalData)
        
        if decompressedData then
            _addToRollingCache(productId, decompressedData)
            return Promise.resolve(globalData)
        end
    end
    
    return Promise.new(function(resolve: ({}) -> ())
        while localBudget <= 0 do task.wait() end
        
        local productData = marketService:GetProductInfo(productId, productType)
        
        if productData then
            for _, strippedKey in STRIPPED_DATA_KEYS do
                if productData[strippedKey] then
                    productData[strippedKey] = nil
                end
            end
            
            local compressedData = JSONCompressor:Deflate(productData, 9)
            
            if compressedData then
                _addToRollingCache(productId, productData)
                MemoryStoreHelper:UpdateMapAsync(marketCacheMap, tostring(productId), function()
                    return compressedData
                end, GLOBAL_CACHE_EXPIRATION)
            end
        end
        
        localBudget -= 1
        resolve(productData)
    end)
end

--= Job API =--

---Adds the product ID to the queue to be automatically cached in order of which
---it was received.
---@param productId number The ID of the product.
---@param productType Enum.InfoType? The InfoType of the product. **[default=Enum.InfoType.Asset]**
---@meta
function MarketHelper2:QueueProductCache(productId: number, productType: Enum.InfoType?)
    task.defer(function()
        productType = productType or Enum.InfoType.Asset
        
        if _isInCacheOrQueueAsync(productId) then return end
        
        table.insert(localQueue, {
            ProductId = productId,
            ProductType = productType,
            Failures = 0
        })
    end)
end

---Attempts to fetch a Roblox Product's information from the website.
---
---If it succeeds, it will return a resolved Promise where the resolved value is the returned data.
---Otherwise it will return a rejected Promise.
---@param productId number The ID of the product.
---@param productType Enum.InfoType? The InfoType of the product. **[default=Enum.InfoType.Asset]**
---@meta
function MarketHelper2:FetchProductInfoAsync(productId: number, productType: Enum.InfoType?): Promise
    productType = productType or Enum.InfoType.Asset
    return Promise.retryWithDelay(_getProductInfoPromise, RETRY_MAX, RETRY_DELAY, productId)
end

--= Job Initializers =--
function MarketHelper2:Update() ---@deprecated
    local firstEntry = localQueue[1]
    
    if firstEntry then
        local productId = firstEntry.ProductId
        
        if not FLUSH then
            local productType = firstEntry.ProductType
            local failCount = firstEntry.Failures
            
            if not (productId and productType) then
                console:Warn('Skipping malformed data in queue')
                table.remove(localQueue, 1)
                return
            end
            
            if failCount >= MAX_CACHE_ATTEMPTS then
                console:Warn('Failed to cache product %d - exceeded MAX_CACHE_ATTEMPTS (%d)', productId, MAX_CACHE_ATTEMPTS)
                table.remove(localQueue, 1)
                return
            end
            
            InsertHelper:QueueAssetCache(productId)
            
            MarketHelper2:FetchProductInfoAsync(productId, productType):andThen(function()
                table.remove(localQueue, 1)
                console:Print('Cached product %d (remaining queue: %d) (remaining budget: %d) (cache size: %d)',
                    productId, #localQueue, localBudget, #rollingHistory)
            end):catch(function(err: any)
                failCount += 1
                console:Warn('Failed to cache product %d:\n%s', productId, tostring(err))
            end):await()
        else
            MemoryStoreHelper:GetMapAsync(marketCacheMap, tostring(productId)):andThen(function(result: any)
                if result ~= nil then
                    MemoryStoreHelper:RemoveMapAsync(marketCacheMap, tostring(productId)):await()
                    console:Print('Flushed product %d from global cache', productId or '_UNKNOWN')
                    table.remove(localQueue, 1)
                end
            end):await()
        end
    end
end

function MarketHelper2:Run() ---@deprecated
    network:Fired('MarketHelper2:QueueProductCache', function(_, productId: number, productType: Enum.InfoType?)
        MarketHelper2:QueueProductCache(productId, productType)
    end)
    
    network:Invoked('MarketHelper2:FetchProductInfo', function(_, productId: number, productType: Enum.InfoType?)
        local success, result = MarketHelper2:FetchProductInfoAsync(productId, productType):await()
        
        if success and result then
            return result
        end
        
        return nil
    end)
    
    while task.wait(BUDGET_REFILL_DELAY) do
        localBudget += 1
        
        if localBudget > LOCAL_FETCH_BUDGET then
            localBudget = LOCAL_FETCH_BUDGET
        end
    end
end

function MarketHelper2:Init() ---@deprecated
    console.LoggingEnabled = VERBOSE_OUTPUT
    
    network:RegisterEvent('MarketHelper2:QueueProductCache')
    network:RegisterFunction('MarketHelper2:FetchProductInfo')
end

--= Return Job =--
return MarketHelper2