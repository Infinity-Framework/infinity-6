--[[
    File: ClientMarketHelper.lua
    Author(s): FriendlyBiscuit
    Created: 07/22/2022 @ 14:31:55
    
    Description:
        Handles client-sided networking for waiting on cached marketplace data.
        
        Be sure to add "---@module ClientMarketHelper" after you require this module if
        you want access to inline documentation.
    
    Documentation:
        No documentation provided.
--]]

--= Module Loader =--
local require               = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local ClientMarketHelper    = { }

--= Classes & Jobs =--
local Promise               = require('$Promise') ---@module Promise

--= Dependencies =--
local network               = require('$Network')

--= Roblox Services =--
local repStorage            = game:GetService('ReplicatedStorage')

--= Object References =--
local assetFolder           = repStorage:FindFirstChild('_KLOSS_TEMP')

--= Constants =--
local INVOKE_DELAY          = 0.05
local DEFAULT_TIMEOUT       = 99999

--= Job API =--

---Waits for the server-sided MarketHelper job to cache the target product data
---then returns a resolved Promise with the product data as its sole argument.
---
---If an optional `timeout` is specified and is exceeded, this function will resolve
---with `nil` as the result.
---
---If product data isn't yet cached, MarketHelper will add the product to the cache queue.
---Note that this does _not_ guarantee that the product data will be available before the timeout.
---@param productId number The product ID you're querying.
---@param timeout? number Optional timeout. **[default=99999]**
---@meta
function ClientMarketHelper:WaitForProductDataAsync(productId: number, timeout: number?): Promise
    return Promise.new(function(resolve: (productData: {}) -> (), reject: () -> ())
        local startTime = tick()
        local result
        
        while not result and ((tick() - startTime) < (timeout or DEFAULT_TIMEOUT)) do
            result = network:Invoke('MarketHelper:get_product_info', productId)
            
            if result then break end
            
            task.wait(INVOKE_DELAY)
        end
        
        resolve(result)
    end)
end

---Attempts to fetch product data from the server-sided MarketHelper job. Will always resolve
---with the returned data, even if it is `nil` (not cached yet).
---
---If product data isn't yet cached, MarketHelper will add the product to the cache queue.
---Note that this does _not_ guarantee that the product data will be available before the timeout.
---@param productId number The product ID you're querying.
---@meta
function ClientMarketHelper:GetProductDataAsync(productId: number): Promise
    return Promise.new(function(resolve: (productData: {}) -> ())
        resolve(network:Invoke('MarketHelper:get_product_info', productId))
    end)
end

---Waits for the server-sided MarketHelper job to create the asset model of
---the target product. Resolves with a direct reference to the asset.
---_(Note: this means it isn't cloned)_
---
---If an optional `timeout` is specified and is exceeded, this function will resolve
---with `nil` as the result.
---@param productId number The product ID you're querying.
---@param timeout? number Optional timeout. **[default=99999]**
---@meta
function ClientMarketHelper:WaitForAssetReadyAsync(productId: number, timeout: number?): Promise
    return Promise.new(function(resolve: (asset: Instance|nil) -> ())
        local result = assetFolder:WaitForChild('KK_UGC_' .. productId, timeout or 99999)
        resolve(result)
    end)
end

--= Return Job =--
return ClientMarketHelper