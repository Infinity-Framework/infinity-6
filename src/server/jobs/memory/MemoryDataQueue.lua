--[[
    File: MemoryDataQueue.lua
    Author(s): FriendlyBiscuit
    Created: 08/16/2022 @ 19:12:36
    
    Description:
        Provides a quick and easy-to-use managed queue for adding
        slaved writes to the MemoryData sorted maps.
    
    Documentation:
        No documentation provided.
--]]

--= Module Loader =--
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local MemoryDataQueue = { UpdateRate = 0.03 }

--= Classes & Jobs =--
local MemoryData = require('MemoryData') ---@module MemoryData

--= Variables =--
local activeQueue = { }

--= Job API =--

---Pushes changes to the mapped key store to be processed by a slave server.
---@param mappedKey string The parent reference key for this operation.
---@param changes table The changes to push to the corresponding key.
function MemoryDataQueue:Push(mappedKey: string, changes: {})
    table.insert(activeQueue, { mappedKey, changes })
end

--= Job Initializers =--
function MemoryDataQueue:Update() ---@deprecated
    local firstKey = activeQueue[1]
    
    if firstKey then
        MemoryData:PushSlavedWrite(firstKey[1], firstKey[2])
        table.remove(activeQueue, 1)
    end
end

--= Return Job =--
return MemoryDataQueue