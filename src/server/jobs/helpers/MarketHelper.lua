--[[
    File: MarketHelper.lua
    Author(s): FriendlyBiscuit
    Created: 07/18/2022 @ 14:47:33
    
    Description:
        Provides a set of promisified MarketplaceService wrappers for commonly-used
        and frequently failing methods.
        
        Be sure to add "---@module MarketHelper" after you require this module if
        you want access to inline documentation.
    
    Documentation:
        No documentation provided.
--]]

--= Module Loader =--
local require               = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local MarketHelper          = { UpdateRate = 0.03 }

--= Classes & Jobs =--
local Promise               = require('$Promise') ---@module Promise
local Logger                = require('$Logger') ---@module Logger
local Network               = require('$Network') ---@module Network

--= Roblox Services =--
local marketService         = game:GetService('MarketplaceService')
local repStorage            = game:GetService('ReplicatedStorage')
local insertService         = game:GetService('InsertService')

--= Object References =--
local console               = Logger.new('MarketHelper')
local assetFolder           = repStorage:FindFirstChild('_KLOSS_TEMP')

--= Constants =--
local VERBOSE_OUTPUT        = true
local DEFAULT_DELAY         = 1.5
local DEFAULT_RETRIES       = 2
local MAX_CACHE_ATTEMPTS    = 2
local FETCH_BUDGET          = 40

--= Variables =--
local productCache          = { }
local cacheQueue            = { }
local currentBudget         = FETCH_BUDGET

--= Internal Functions =--
local function _getProductInfoPromise(productId: number, productType: Enum.InfoType): Promise
    return Promise.new(function(resolve: (Dictionary) -> ())
        local data = marketService:GetProductInfo(productId, productType)
        resolve(data)
    end)
end

local function _isInCacheOrQueue(productId: number): boolean
    if productCache[productId] ~= nil then
        return true
    end
    
    for _, cacheEntry in cacheQueue do
        if cacheEntry[1] == productId then
            return true
        end
    end
    
    return false
end

--= Job API =--

---Adds the product ID to the queue to be automatically cached.
---@param productId number The ID of the product.
---@param productType Enum.InfoType? The InfoType of the product. **[default=Asset]**
---@meta
function MarketHelper:CacheProductInfo(productId: number, productType: Enum.InfoType?, skipCache: boolean?)
    if _isInCacheOrQueue(productId) then return end
    table.insert(cacheQueue, { productId, productType or Enum.InfoType.Asset, 0, skipCache })
end

---Attempts to fetch a Roblox Product's information from the website.
---
---If it succeeds, it will return a resolved Promise where the resolved value is the returned data.
---Otherwise it will return a rejected Promise.
---@param productId number The ID of the product.
---@param productType Enum.InfoType? The InfoType of the product. **[default=Asset]**
---@param skipCache boolean? Whether or not you want to ignore any cached product info. **[default=false]**
---@param retryCount number? Optional number of retries. **[default = 5]**
---@meta
function MarketHelper:GetProductInfoAsync(productId: number, productType: Enum.InfoType?, skipCache: boolean?, retryCount: number?): Promise
    if not skipCache then
        local cacheKey = tostring(productId) .. productType.Name
        local cachedData = productCache[cacheKey]
        
        if cachedData then
            return Promise.resolve(cachedData)
        end
    end
    
    while currentBudget <= 0 do task.wait() end
    
    return Promise.retryWithDelay(_getProductInfoPromise, retryCount or DEFAULT_RETRIES, DEFAULT_DELAY, productId, productType or Enum.InfoType.Asset)
end

---Attempts to fetch and return a cached UGC asset model.
---
---The product must be cached with `::CacheProductInfo()` beforehand.
---@param itemId number The ID of the product.
---@meta
function MarketHelper:GetProductAssetModel(itemId: number): Instance|nil
    local result = assetFolder:FindFirstChild('KK_UGC_' .. itemId)
    
    if result then
        return result:Clone()
    end
    
    return result
end

--= Job Initializers =--
function MarketHelper:Update() ---@deprecated
    local first = cacheQueue[1]
    
    if first then
        local productId = first[1]
        local productType = first[2]
        
        if productCache[productId] ~= nil then
            console:Warn('Skipping recache of previously cached product %d.', productId)
            table.remove(cacheQueue, 1)
            return
        end
        
        if first[3] >= MAX_CACHE_ATTEMPTS then
            console:Warn('Abandoning cache of product %d - failed %d times.', productId, MAX_CACHE_ATTEMPTS)
            table.remove(cacheQueue, 1)
            return
        end
        
        local productInfo = MarketHelper:GetProductInfoAsync(productId, productType):catch(function()
            console:Warn('Failed to cache product %d - ::GetProductInfoAsync() returned nil.', productId)
        end):expect()
        
        if productInfo then
            console:Print('Cached product %d (remaining queue: %d, remaining budget: %d)', productId, #cacheQueue - 1, currentBudget - 1)
            productCache[productId] = productInfo
            table.remove(cacheQueue, 1)
            currentBudget -= 1
            
            task.defer(function()
                local assetTemplate = insertService:LoadAsset(productId)
                
                if not assetTemplate then
                    console:Warn('Failed to ::LoadAsset() for product %d', productId)
                else
                    for _, descendant in (assetTemplate:GetDescendants()) do
                        if descendant:IsA('Part') then
                            descendant.Anchored = false
                            descendant.CanCollide = false
                            descendant.CanQuery = false
                        end
                    end
                    
                    assetTemplate.Name = 'KK_UGC_' .. tostring(productId)
                    assetTemplate.Archivable = true
                    assetTemplate.Parent = assetFolder
                end
            end)
        else
            first[3] += 1
        end
    end
end

function MarketHelper:Run() ---@deprecated
    Network:Fired('MarketHelper:request_cache', function(_, itemId: number)
        MarketHelper:CacheProductInfo(itemId)
    end)
    
    Network:Invoked('MarketHelper:get_product_info', function(_, itemId: number)
        if not _isInCacheOrQueue(itemId) then
            MarketHelper:CacheProductInfo(itemId)
        end
        
        return productCache[itemId]
    end)
    
    while task.wait(DEFAULT_DELAY) do
        currentBudget += 1
        
        if currentBudget > FETCH_BUDGET then
            currentBudget = FETCH_BUDGET
        end
    end
end

function MarketHelper:Init() ---@deprecated
    Network:RegisterEvent('MarketHelper:request_cache')
    Network:RegisterFunction('MarketHelper:get_product_info')
    
    console.LoggingEnabled = VERBOSE_OUTPUT
    
    if not assetFolder then
        assetFolder = Instance.new('Folder', repStorage)
        assetFolder.Name = '_KLOSS_TEMP'
    end
end

--= Return Job =--
return MarketHelper