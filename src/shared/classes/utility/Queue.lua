--[[
    File: Queue.lua
    Author(s): FriendlyBiscuit
    Created: 08/14/2022 @ 22:20:00
    
    Description:
        A flexible Queue class that allows you to easily create manage, and distribute
        data into a timed queue.
        
        Remember to add ---@module Queue to the end of your require to gain better
        inline documentation.
    
    Constructor:
        <Queue> .new(stepDelay number?)
            Creates and returns a new Queue class with an optional stepDelay (default 0.03)
    
    Methods:
        <void> ::Start()
            Starts the Queue step routine and resets the current delay timer.
        
        <void> ::Stop()
            Stops the Queue step routine and resets the current delay timer.
        
        <void> ::ResetTime()
            Resets the current delay timer.
        
        <void> ::StepNow()
            Forces the queue to step through the next item in line and resets
            the current delay timer.
        
        <void> ::Flush()
            Flushes all queue items through the Process callback in-order, without delay.
        
        <void> ::Clear()
            Clears all items from the queue.
        
        <void> ::Push(data: any, index: number?)
            Pushes data to the queue. If no index is specified, the data is added to the
            back of the queue.
        
        <void> ::Pop(index: number?)
            Pops (removes) data from the queue. If no index is specified, the first item
            in the queue is removed.
        
        <any> ::Read(index: number?)
            Reads and returns data from the queue. If no index is specified, the first item,
            in the queue is returned.
    
    Members:
        <QueueCallback> Processed(itemData: any) -> boolean
            The callback that is invoked whenever data is processed in the queue.
            MUST return true/false as a success state of the process operation.
            
            Example:
            myQueue.Processed = function(itemData: any): boolean
                print("Processed item data:", itemData)
                return true
            end
        
        <RBXScriptSignal> ProcessFailed(failedData: any)
            This event is fired if a Process callback invocation fails due to
            erroring or returning false. This allows you to re-add failed data
            to the queue.
            
            Example:
            myQueue.ProcessFailed:Connect(function(itemData: any)
                print("Re-adding failed data to queue:", itemData)
                myQueue:Push(itemData)
            end)
        
        <number> StepDelay
            Sets the delay between each step of the queue and resets the current delay
            timer.
        
        <number> TimeRemaining [read-only]
            Returns the alpha time remaining from the last step to the next.
        
        <string> Name
            Sets the name of the queue. Strictly for sugar and verbose erroring purposes.
--]]

--= Module Loader =--
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Class Root =--
local Queue = { }
Queue.__classname = 'Queue'

--= Type Export =--
type QueueCallback = (itemData: any) -> boolean
export type Queue = {
    Start: () -> (),
    Stop: () -> (),
    StepNow: () -> (),
    ResetTimer: () -> (),
    Flush: () -> (),
    Clear: () -> (),
    Push: (self: Queue, data: any, index: number?) -> (),
    Pop: (self: Queue, index: number?) -> (),
    Read: (self: Queue, index: number?) -> (any|nil),
    Processed: QueueCallback<(itemData: any) -> boolean>,
    ProcessFailed: RBXScriptSignal<(failedData: any) -> ()>,
    TimeRemaining: number,
    Name: string,
    StepDelay: number
}

--= Classes & Jobs =--
local Promise = require('$Promise') ---@module Promise
local Logger = require('$Logger') ---@module Logger

--= Dependencies =--
local classify = require('$Classify')

--= Roblox Services =--
local runService = game:GetService('RunService')

--= Constants =--
local DEFAULT_STEP_TIME = 0.03

--= Class Internal =--
function Queue:_processEntry(data: any): Promise
    return Promise.new(function(resolve: () -> (), reject: (err: string?) -> ())
        local returnValue = self._callback(data)
        
        if returnValue then
            resolve()
        else
            reject('FALSE_RETURN')
        end
    end):catch(function(err: string|{})
        if err == 'FALSE_RETURN' then
            self._log:Warn('Failed to process queue item - process callback returned false.')
        else
            self._log:Warn('Failed to process queue item - execution error:\n%s', err.trace)
        end
        
        self._failEvent:Fire(data)
    end)
end

--= Class API =--
function Queue:StepNow()
    self._currentTimer = 0
end

function Queue:ResetTimer()
    self._currentTimer = self._stepTime
end

function Queue:Clear()
    self._currentTimer = self._stepTime
    self._mainQueue = { }
end

function Queue:Flush()
    local wasRunning = self._stepConnection
    
    self:Stop()
    
    for _, entry in self._mainQueue do
        self:_processEntry(entry)
    end
    
    self:Clear()
    
    if wasRunning then
        self:Start()
    end
end

function Queue:Pop(index: number?)
    table.remove(self._mainQueue, index or 1)
end

function Queue:Push(value: any, index: number?)
    if value == nil then
        self._log:Warn('Cannot ::Push() a nil value.')
    end
    
    if index then
        table.insert(self._mainQueue, index, value)
    else
        table.insert(self._mainQueue, value)
    end
end

function Queue:Read(index: number?): any
    return self._mainQueue[index or 1]
end

function Queue:Start()
    self:Stop()
    self._currentTimer = self._stepTime
    
    self:_markTrash(runService.Stepped:Connect(function(_, delta: number)
        if self._processing or #self._mainQueue == 0 then return end
        
        self._currentTimer -= delta
        
        if self._currentTimer <= 0 then
            self._processing = true
            self:_processEntry(self._mainQueue[1]):await()
            self:Pop()
            self._currentTimer = self._stepTime
            self._processing = false
        end
    end))
end

function Queue:Stop()
    if self._stepConnection then
        self._stepConnection:Disconnect()
    end
    
    self._stepConnection = nil
end

--= Class Constructor =--

---Creates and returns a new Queue object that can be used to
---automate stepping through a list of tasks or data in order.
---@param stepDelay number? Optional number in seconds that the Queue should wait before stepping. [default=5]
---@meta
function Queue.new(stepDelay: number?): Queue
    local self = classify(Queue)
    
    self._mainQueue = { }
    self._stepTime = stepDelay or DEFAULT_STEP_TIME
    self._currentTimer = self._stepTime
    self._processing = false
    self._callback = function() return true end
    self._log = Logger.new('Queue')
    self._failEvent = Instance.new('BindableEvent')
    self.ProcessFailed = self._failEvent.Event
    self:_markTrash(self._failEvent)
    
    return self
end

--= Class Properties =--
Queue.__properties = {
    Name = {
        bind = 'Name',
        target = function(self) return self._log end
    },
    Processed = {
        internal = '_callback',
        set = function(self, value: (any) -> boolean)
            if type(value) ~= 'function' then
                self._callback = function() return true end
                self._log:Warn('Cannot set Processed callback to non-function %q', tostring(value))
            end
        end
    },
    StepDelay = {
        internal = '_stepTime',
        set = function(self, value: number)
            self._stepTime = value
            self._currentTimer = value
        end
    },
    TimeRemaining = {
        get = function(self)
            return self._currentTimer
        end
    }
}

--= Return Class =--
return Queue