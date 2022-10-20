--[[
       _ __
      (_) /  ___  ___ ____ ____ ____
     / / /__/ _ \/ _ `/ _ `/ -_) __/
    /_/____/\___/\_, /\_, /\__/_/
                /___//___/
    Infinity Logger Class
    By FriendlyBiscuit
    11/30/2021 @ 23:32:30
    
    Description:
        Provides a basic logger utility object that allows you to quickly output data as well
        as bind to existing Roblox instances.
    
    Documentation:
        <Logger> Logger.new()
        -> Creates a new Logger object.
        
        Members:
            <string> Name (default: '')
                -> Sets the name (and by extension the output prefix) of the Logger.
                   If set to '' (empty string), the Logger will not append a prefix to printed messages.
            
            <boolean> ListenersEnabled (default: true)
                -> Enables or disables property and attribute listening on the Logger.
            
            <boolean> LoggingEnabled (default: true)
                -> Enables/disables all logging capabilities for the current Logger.
            
            <number> LoggingLevel (default: 3)
                -> Sets the maximum level of logged events.
                   1 = Errors only
                   2 = Errors and warnings only
                   3 = Everything
        
        Functions:
            <void> ::Print(message: string[, ...])
                   ::print(message: string[, ...]) (alternate)
                -> Prints a formattable message with optional tuple-supplied values.
                
                Example:
                Logger:Print('Hello, world! Here is a message: %s', 'hi there :)')
            
            <void> ::Warn(message: string[, ...])
                   ::warn(message: string[, ...]) (alternate)
                -> Outputs a formattable warning message with optional tuple-supplied values.
            
            <void> ::Error(message: string[, ...])
                   ::error(message: string[, ...]) (alternate)
                -> Outputs a formattable error message with optional tuple-supplied values.
            
            <void> ::PauseListeners()
                   ::pause() (alternate)
                -> Disables property and attribute listening on the Logger.
            
            <void> ::ResumeListeners()
                   ::resume() (alternate)
                -> Enables property and attribute listening on the Logger.
            
            <RBXScriptSignal> ::ListenToProperty(target: Instance, property: string)
                              ::listenToProperty(target: Instance, property: string) (alternate)
                -> Monitors and outputs changes made to the specified target's property.
            
            <RBXScriptSignal> ::ListenToAttribute(target: Instance, attribute: string)
                              ::listenToAttribute(target: Instance, attribute: string) (alternate)
                -> Monitors and outputs changes made to the specified target's attribute.
            
            <void> ::Destroy()
            -> Disconnects all listeners and cleans up the Logger object's leftover data.
--]]

--= Module Loader =--
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Roblox Services =--
local http_svc = game:GetService('HttpService')

--= Class Root =--
local Logger = { }
Logger.__classname = 'Logger'

--= Type Export =--
export type Logger      = {
    Destroy: () -> (),
    Name: string,
    ListenersEnabled: boolean,
    LoggingEnabled: boolean,
    LoggingLevel: number,
    Print: (message: string, ...any) -> (),
    Warn: (message: string, ...any) -> (),
    Error: (message: string, ...any) -> (),
    ListenToProperty: (targetInstance: Instance, propertyName: string) -> RBXScriptSignal,
    ListenToAttribute: (targetInstance: Instance, attributeName: string) -> RBXScriptSignal
}

--= Modules & Config =--
local classify = require('$Classify')

--= Class API =--
function Logger:toJSON(table: {})
    if type(table) ~= 'table' then
        return table
    end

    return http_svc:JSONEncode(table)
end

function Logger:Print(message: string, ...)
    if not self.LoggingEnabled or self.LoggingLevel < 3 then return end
    
    local final_str
    
    if self.Name ~= '' then
        final_str = ('[%s] '):format(self.Name) .. message
    else
        final_str = message
    end
    
    if #{...} > 0 then
        final_str = final_str:format(...)
    end
    
    print(final_str)
end

function Logger:Warn(message: string, ...)
    if not self.LoggingEnabled or self.LoggingLevel < 2 then return end
    
    local final_str
    
    if self.Name ~= '' then
        final_str = ('[%s] '):format(self.Name) .. message
    else
        final_str = message
    end
    
    if #{...} > 0 then
        final_str = final_str:format(...)
    end
    
    warn(final_str)
end

function Logger:Error(message: string, ...)
    if not self.LoggingEnabled or self.LoggingLevel < 1 then return end
    
    local final_str
    
    if self.Name ~= '' then
        final_str = ('[%s] '):format(self.Name) .. message
    else
        final_str = message
    end
    
    if #{...} > 0 then
        final_str = final_str:format(...)
    end
    
    error(final_str, 2)
end

function Logger:PauseListeners()
    self._listen = false
end

function Logger:ResumeListeners()
    self._listen = true
end

function Logger:ListenToProperty(target: Instance, property: string): RBXScriptSignal
    local last = target[property]
    local connection = target:GetPropertyChangedSignal(property):Connect(function()
        if not self.ListenersEnabled or not self.LoggingEnabled then return end
        self:Print('Property %q changed on %s: %q -> %q', property, target.Name, last, target[property])
        last = target[property]
    end)
    
    self:_mark_disposable(connection)
    return connection
end

function Logger:ListenToAttribute(target: Instance, attribute: string): RBXScriptSignal
    local last = target[attribute]
    local connection = target:GetAttributeChangedSignal(attribute):Connect(function()
        if not self.ListenersEnabled or not self.LoggingEnabled then return end
        self:Print('Attribute %q changed on %s: %q -> %q', attribute, target.Name, last, target[attribute])
        last = target[attribute]
    end)
    
    self:_mark_disposable(connection)
    return connection
end

Logger.print = Logger.Print
Logger.warn = Logger.Warn
Logger.error = Logger.Error
Logger.pause = Logger.Pause
Logger.resume = Logger.Resume
Logger.listenToProperty = Logger.ListenToProperty
Logger.listenToAttribute = Logger.ListenToAttribute

--= Class Constructor =--
function Logger.new(name: string): Logger
    local self = classify(Logger)
    
    self._name = name and name or ''
    self._timestamps = false
    self._listen = true
    self._enabled = true
    self._logLevel = 3
    
    return self
end

--= Class Properties =--
Logger.__properties = {
    LoggingEnabled = { internal = '_enabled' },
    LoggingLevel = { internal = '_logLevel' },
    ListenersEnabled = { internal = '_listen' },
    Name = { internal = '_name' }
}

--= Return Class =--
return Logger