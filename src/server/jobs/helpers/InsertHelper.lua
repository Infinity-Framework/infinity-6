--[[
    File: InsertHelper.lua
    Author(s): FriendlyBiscuit
    Created: 09/02/2022 @ 21:43:57
    
    Description:
        No description provided.
    
    Documentation:
        No documentation provided.
--]]

--= Module Loader =--
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local InsertHelper = { UpdateRate = 0.03 }

--= Classes & Jobs =--
local Promise = require('$Promise') ---@module Promise
local Logger = require('$Logger') ---@module Logger

--= Roblox Services =--
local repStorage = game:GetService('ReplicatedStorage')
local insertService = game:GetService('InsertService')

--= Object References =--
local console = Logger.new('InsertHelper')
local assetFolder
local cacheFolder

--= Constants =--
local VERBOSE_OUTPUT = true
local BUDGET_REFILL_DELAY = 1
local RETRY_DELAY = 3
local RETRY_MAX = 5
local INSERT_BUDGET = 1000
local ROLLING_CACHE_MAX = 200
local ASSET_FOLDER_NAME = 'InfinityAssets'

--= Variables =--
local currentBudget = INSERT_BUDGET
local rollingCache = { }
local queue = { }

--= Internal Functions =--
local function _isInCacheOrQueue(assetId: number): boolean
    for _, cachedItem in rollingCache do
        if cachedItem.AssetId == assetId then
            return true
        end
    end
    
    return table.find(queue, assetId)
end

local function _loadAssetPromise(assetId: number): Promise
    return Promise.new(function(resolve: (Model) -> (), reject: () -> ())
        while currentBudget <= 0 do task.wait() end
        
        for _, cachedItem in rollingCache do
            if cachedItem.AssetId == assetId then
                return resolve(cachedItem.Model:Clone())
            end
        end
        
        local assetModel = insertService:LoadAsset(assetId)
        
        if assetModel then
            assetModel.Parent = cacheFolder
            assetModel.Name = assetId
            
            table.insert(rollingCache, {
                AssetId = assetId,
                Model = assetModel
            })
            
            if #rollingCache > ROLLING_CACHE_MAX then
                local oldestItem = rollingCache[1]
                oldestItem.Model:Destroy()
                currentBudget -= 1
                table.remove(rollingCache, 1)
            end
            
            console:Print('Cached asset model %d (remaining queue: %d) (remaining budget: %d) (cache size: %d)',
                assetId, #queue, currentBudget, #rollingCache)
            
            resolve(assetModel:Clone())
        else
            reject()
        end
    end)
end

--= Job API =--

---Adds an asset ID to the queue to be cached to the assets folder
---in ReplicatedStorage.
---@param assetId number The asset ID to add to the cache.
---@meta
function InsertHelper:QueueAssetCache(assetId: number)
    if _isInCacheOrQueue(assetId) then return end
    table.insert(queue, assetId)
end

---Attempts to insert an asset if it has not already been cached. Otherwise
---the cached asset will be returned.
---@param assetId number The ID of the asset model you wish to wait for.
---@meta
function InsertHelper:LoadAssetAsync(assetId: number): Promise
    return Promise.retryWithDelay(_loadAssetPromise, RETRY_MAX, RETRY_DELAY, assetId)
end

--= Job Initializers =--
function InsertHelper:Update() ---@deprecated
    local firstId = queue[1]
    
    if firstId then
        InsertHelper:LoadAssetAsync(firstId):await()
        table.remove(queue, 1)
    end
end

function InsertHelper:Run() ---@deprecated
    assetFolder = repStorage:WaitForChild(ASSET_FOLDER_NAME, 5)
    
    if assetFolder then
        cacheFolder = assetFolder:FindFirstChild('cache')
        
        if not cacheFolder then
            cacheFolder = Instance.new('Folder', assetFolder)
            cacheFolder.Name = 'cache'
        end
    else
        console:Warn('Failed to start InsertHelper - no asset folder named %q found', ASSET_FOLDER_NAME)
    end
    
    while task.wait(BUDGET_REFILL_DELAY) do
        currentBudget += 1
        
        if currentBudget > INSERT_BUDGET then
            currentBudget = INSERT_BUDGET
        end
    end
end

function InsertHelper:Init() ---@deprecated
    console.LoggingEnabled = VERBOSE_OUTPUT
end

--= Return Job =--
return InsertHelper