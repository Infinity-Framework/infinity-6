--[[
    File: MessagingHelper.lua
    Author(s): FriendlyBiscuit
    Created: 08/24/2022 @ 14:05:33
    
    Description:
        Provides a set of promisified methods to publish and subscribe to MessageingService topics.
        
        Be sure to add "---@module MessagingHelper" after you require this module if
        you want access to inline documentation.
    
    Documentation:
        No documentation provided.
--]]

--= Module Loader =--
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Root =--
local MessagingHelper = { UpdateRate = 0.03 }

--= Classes & Jobs =--
local Promise = require('$Promise') ---@module Promise

--= Roblox Services =--
local messagingService = game:GetService('MessagingService')
local playerService = game:GetService('Players')

--= Constants =--
local DEFAULT_DELAY = 1
local DEFAULT_RETRIES = 5

--= Variables =--
local messageQueue = { }
local lastCall = 0

--= Internal Functions =--
local function _publishAsyncPromise(topic: string, message: any): Promise
    return Promise.new(function(resolve: () -> ())
        messagingService:PublishAsync(topic, message)
        print(os.time(), DateTime.now(), tick())
        resolve()
    end)
end

local function _subscribeAsyncPromise(topic: string, callback: (any) -> ()): Promise
    return Promise.new(function(resolve: (RBXScriptConnection) -> ())
        local connection = messagingService:SubscribeAsync(topic, callback)
        resolve(connection)
    end)
end

--= Job API =--

---Pushes the message to a server-sided queue to be published in a first-in-first-out order.
---@param topic string The topic you want to publish to.
---@param message any The message content to publish.
---@meta
function MessagingHelper:QueuePublishAsync(topic: string, message: any)
    table.insert(messageQueue, { Topic = topic, Message = message })
end

---Immediately tries to publish the message to the specified topic and returns a Promise
---that resolves when the message is published successfully.
---@param topic string The topic you want to publish to.
---@param message any The message content to publish.
---@meta
function MessagingHelper:PublishAsync(topic: string, message: any): Promise
    return Promise.retryWithDelay(_publishAsyncPromise, DEFAULT_RETRIES, DEFAULT_DELAY, topic, message)
end

---Immediately tries to subscribe to the specified topic and returns a Promise that resolves
---when the subcscription is successful.
---@param topic string The topic you want to subscribe to.
---@param callback function The function to call when message is received through this topic.
---@meta
function MessagingHelper:SubscribeAsync(topic: string, callback: (any) -> ()): Promise
    return Promise.retryWithDelay(_subscribeAsyncPromise, DEFAULT_RETRIES, DEFAULT_DELAY, topic, callback)
end

--= Job Initializers =--
function MessagingHelper:Update() ---@deprecated
    local firstMessage = messageQueue[1]
    
    if firstMessage then
        local trueDelay = 60 / (150 + (50 * #playerService:GetPlayers()))
        
        if (tick() - lastCall) > trueDelay then
            lastCall = tick()
            MessagingHelper:PublishAsync(firstMessage.Topic, firstMessage.Message)
            table.remove(messageQueue, 1)
        end
    end
end

--= Return Job =--
return MessagingHelper