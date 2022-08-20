--[[
    File: MemoryData.lua
    Author(s): FriendlyBiscuit
    Created: 08/15/2022 @ 23:43:07
    
    Description:
        No description provided.
    
    Documentation:
        No documentation provided.
        Eventually I'll get to this...
--]]

--= Module Loader =--
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local MemoryData = { UpdateRate = 2.5 }

--= Classes & Jobs =--
local Logger = require('$Logger') ---@Logger
local MemoryStoreHelper = require('MemoryStoreHelper') ---@module MemoryStoreHelper
local DataRateHelper = require('DataRateHelper') ---@module DataRateHelper

--= Roblox Services =--
local memoryService = game:GetService('MemoryStoreService')
local dataService = game:GetService('DataStoreService')

--= Object References =--
local console = Logger.new('MemoryData')
local mainQueue = memoryService:GetQueue('__MEMORYQUEUE', 100)
local mainMap = memoryService:GetSortedMap('__MEMORYMAP')
local activeMap = memoryService:GetSortedMap('__ACTIVEMAP')

--= Constants =--
local VERBOSE_OUTPUT = true
local ALL_OR_NOTHING = false
local QUEUE_READ_AMOUNT = 25
local QUEUE_READ_TIMEOUT = 5
local FLUSH = false

--= Variables =--
local storeCache = { }

--= Change Types =--
MemoryData.Operation = {
    Set = 'Set',
    Increment = 'Increment',
    Delete = 'Delete',
    PatchInsert = 'PatchInsert',
    PatchInsertUnique = 'PatchInsertUnique',
    PatchRemove = 'PatchRemove'
}

--= Internal Functions =--
local function _isValidRequest(request: {}): boolean
    if request == nil then return false, 'nil data' end
    if not request.Origin then return false, 'no origin GUID' end
    if not request.StoreName then return false, 'no store name' end
    if not request.StoreScope then return false, 'no store scope' end
    if not request.Keys then return false, 'no keys' end
    if type(request.Keys) ~= 'table' then return false, 'bad key data' end
    
    return true
end

local function _getDataStore(name: string, scope: string): DataStore|nil
    local cacheKey = ('%s.%s'):format(name, scope)
    
    if not storeCache[cacheKey] then
        pcall(function()
            storeCache[cacheKey] = dataService:GetDataStore(name, scope)
        end)
    end
    
    return storeCache[cacheKey]
end

local function _getSuffix(refKey: string): string
    return refKey:match('_(%d+)')
end

local function _isProcessing(refKey: string): boolean
    local parentKey = _getSuffix(refKey)
    
    if parentKey then
        return MemoryStoreHelper:GetMapAsync(activeMap, refKey):expect()
    else
        return nil
    end
end

local function _setProcessingState(refKey: string, state: boolean)
    local parentKey = _getSuffix(refKey)
    
    if parentKey then
        MemoryStoreHelper:SetMapAsync(activeMap, refKey, state, 60):await()
    end
end

local function _set(store: DataStore, data: {})
    DataRateHelper:ResolveWhenReady(store, 'SetIncrementAsync', data.Key)
        :andThen(function()
            store:SetAsync(data.Key, data.FinalValue)
        end):await()
end

local function _increment(store: DataStore, data: {})
    DataRateHelper:ResolveWhenReady(store, 'SetIncrementAsync', data.Key)
        :andThen(function()
            store:IncrementAsync(data.Key, data.FinalValue)
        end):await()
end

local function _patchInsert(store: DataStore, data: {})
    DataRateHelper:ResolveWhenReady(store, 'UpdateAsync', data.Key)
        :andThen(function()
            store:UpdateAsync(data.Key, function(old: {})
                if not old then old = { } end
                
                if type(old) ~= 'table' then
                    console:Warn('PatchInsert into %q failed - key is not a table', data.Key)
                    return nil
                end
                
                for _, value in data.Inserts do
                    table.insert(old, value)
                end
                
                return old
            end)
        end):await()
end

local function _patchInsertUnique(store: DataStore, data: {})
    DataRateHelper:ResolveWhenReady(store, 'UpdateAsync', data.Key)
        :andThen(function()
            store:UpdateAsync(data.Key, function(old: {})
                if not old then old = { } end
                
                if type(old) ~= 'table' then
                    console:Warn('PatchInsertUnique into %q failed - key is not a table', data.Key)
                    return nil
                end
                
                for _, overwrite in data.Overwrites do
                    local targetIndex = overwrite.TargetIndex
                    local targetValue = overwrite.TargetValue
                    
                    if targetIndex then
                        old[targetIndex] = targetValue
                    else
                        if not table.find(old, targetValue) then
                            table.insert(old, targetValue)
                        end
                    end
                end
                
                return old
            end)
        end):await()
end

local function _patchRemove(store: DataStore, data: {})
    DataRateHelper:ResolveWhenReady(store, 'UpdateAsync', data.Key)
        :andThen(function()
            store:UpdateAsync(data.Key, function(old: {})
                if not old then return { } end
                
                if type(old) ~= 'table' then
                    console:Warn('PatchRemove from %q failed - key is not a table', data.Key)
                    return nil
                end
                
                for _, removal in data.Removals do
                    local targetIndex = removal.TargetIndex
                    local targetValue = removal.TargetValue
                    
                    if targetValue and not targetIndex then
                        for index, value in old do
                            if value == targetValue then
                                if type(index) == 'number' then
                                    table.remove(old, index)
                                else
                                    old[index] = nil
                                end
                            end
                        end
                    elseif targetIndex and not targetValue then
                        old[targetIndex] = nil
                    elseif targetIndex and targetValue then
                        for index, value in old do
                            if index == targetIndex and value == targetValue then
                                old[targetIndex] = nil
                            end
                        end
                    end
                end
                
                return old
            end)
        end):await()
end

--= Job API =--

---Pushes changes to the mapped key store to be processed by a slave server.
---@param refKey string The parent reference key for this operation.
---@param changes table The changes to push to the corresponding key.
function MemoryData:PushSlavedWrite(refKey: string, changes: {})
    if FLUSH then return end
    
    changes.Origin = game.JobId ~= '' and game.JobId or 'STUDIO'
    
    local finalKey = ('%d_%s'):format(DateTime.now().UnixTimestampMillis, refKey)
    local valid, message = _isValidRequest(changes)
    
    if valid then
        MemoryStoreHelper:SetMapAsync(mainMap, finalKey, changes):await()
        MemoryStoreHelper:AddQueueAsync(mainQueue, finalKey, nil):await()
    else
        console:Warn('Failed to queue slaved write for %q - %s.', refKey, message)
    end
end

--= Job Initializers =--
function MemoryData:Update() ---@deprecated
    local processSuccess = false
    
    MemoryStoreHelper:ReadQueueAsync(mainQueue, QUEUE_READ_AMOUNT, ALL_OR_NOTHING, QUEUE_READ_TIMEOUT)
        :andThen(function(clearKey: string, keyMap: {})
            if clearKey and keyMap then
                console:Print('Received %d mapped keys', #keyMap)
                
                if FLUSH then
                    for _, mappedKey in keyMap do
                        MemoryStoreHelper:RemoveMapAsync(mainMap, mappedKey):await()
                        MemoryStoreHelper:RemoveMapAsync(activeMap, mappedKey):await()
                        console:Warn('Flushed %q from sorted maps', mappedKey)
                    end
                    
                    processSuccess = true
                else
                    local initialSlaveData = { }
                    local consolidatedMap = { }
                    
                    for _, mappedKey in keyMap do
                        if not _isProcessing(mappedKey) then
                            _setProcessingState(mappedKey, true)
                            
                            MemoryStoreHelper:GetMapAsync(mainMap, mappedKey):andThen(function(slaveData: any)
                                local valid, message = _isValidRequest(slaveData)
                                
                                if valid then
                                    table.insert(initialSlaveData, slaveData)
                                else
                                    console:Warn('Failed to process slaved write - %s', message)
                                end
                                
                                MemoryStoreHelper:RemoveMapAsync(mainMap, mappedKey)
                            end):await()
                        end
                    end
                    
                    for _, slaveData in initialSlaveData do
                        local storeAndScope = ('%s(%s)'):format(slaveData.StoreName, slaveData.StoreScope)
                        
                        if not consolidatedMap[storeAndScope] then
                            consolidatedMap[storeAndScope] = {
                                Origin = slaveData.Origin,
                                StoreName = slaveData.StoreName,
                                StoreScope = slaveData.StoreScope,
                                OriginalKeys = { },
                                ConsolidatedKeys = { }
                            }
                        end
                        
                        local consolidatedStore = consolidatedMap[storeAndScope]
                        
                        for key, opData in slaveData.Keys do
                            local insertResult = { Key = key }
                            
                            for index, value in opData do
                                insertResult[index] = value
                            end
                            
                            table.insert(consolidatedStore.OriginalKeys, insertResult)
                        end
                        
                        for originalIndex, keyData in consolidatedStore.OriginalKeys do
                            local keyAndOperation = ('%s.%s'):format(keyData.Key, keyData.Operation)
                            local consolidatedKey = consolidatedStore.ConsolidatedKeys[keyAndOperation]
                            
                            if not consolidatedKey then
                                consolidatedStore.ConsolidatedKeys[keyAndOperation] = { }
                                consolidatedKey = consolidatedStore.ConsolidatedKeys[keyAndOperation]
                                consolidatedKey.Operation = keyData.Operation
                                consolidatedKey.Key = keyData.Key
                            end
                            
                            local targetOp = consolidatedKey.Operation
                            
                            if targetOp == MemoryData.Operation.Set then
                                consolidatedKey.FinalValue = keyData.Value
                            elseif targetOp == MemoryData.Operation.Increment then
                                if not consolidatedKey.FinalValue then consolidatedKey.FinalValue = 0 end
                                consolidatedKey.FinalValue += keyData.Value
                            elseif targetOp == MemoryData.Operation.PatchInsert then
                                if not consolidatedKey.Inserts then consolidatedKey.Inserts = { } end
                                table.insert(consolidatedKey.Inserts, keyData.Value)
                            elseif targetOp == MemoryData.Operation.PatchRemove then
                                if not consolidatedKey.Removals then consolidatedKey.Removals = { } end
                                table.insert(consolidatedKey.Removals, {
                                    TargetIndex = keyData.TargetIndex,
                                    TargetValue = keyData.TargetValue
                                })
                            elseif targetOp == MemoryData.Operation.PatchInsertUnique then
                                if not consolidatedKey.Overwrites then consolidatedKey.Overwrites = { } end
                                table.insert(consolidatedKey.Overwrites, {
                                    TargetIndex = keyData.TargetIndex,
                                    TargetValue = keyData.TargetValue
                                })
                            else
                                consolidatedKey.FinalValue = keyData.Value
                            end
                            
                            consolidatedStore.OriginalKeys[originalIndex] = nil
                        end
                    end
                    
                    for storeIndex, consolidatedStore in consolidatedMap do
                        console:Print('Processing consolidated store %s (from: %s)', storeIndex, consolidatedStore.Origin)
                        
                        local targetStore = _getDataStore(consolidatedStore.StoreName, consolidatedStore.StoreScope)
                        
                        if targetStore then
                            for _, data in consolidatedStore.ConsolidatedKeys do
                                if data.Operation == MemoryData.Operation.Set then
                                    _set(targetStore, data)
                                elseif data.Operation == MemoryData.Operation.Increment then
                                    _increment(targetStore, data)
                                elseif data.Operation == MemoryData.Operation.PatchInsert then
                                    _patchInsert(targetStore, data)
                                elseif data.Operation == MemoryData.Operation.PatchRemove then
                                    _patchRemove(targetStore, data)
                                elseif data.Operation == MemoryData.Operation.PatchInsertUnique then
                                    _patchInsertUnique(targetStore, data)
                                end
                            end
                        end
                    end
                    
                    processSuccess = true
                end
                
                if processSuccess then
                    mainQueue:RemoveAsync(clearKey)
                    console:Print('Finished processing and cleared current batch keys from queue')
                end
            end
        end):catch(function(err)
            console:Warn('Failed to read master queue: %s', err)
        end):await()
end

function MemoryData:Immediate() ---@deprecated
    console.LoggingEnbaled = VERBOSE_OUTPUT
end

--= Return Job =--
return MemoryData