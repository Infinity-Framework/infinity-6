--[[
    File: SawSpring.lua
    Author(s): FriendlyBiscuit
    Created: 07/14/2022 @16:50:09
    
    Description:
        No description provided.
    
    Documentation:
        Constructor:
            <SawSpring> .new(startPosition: number?)
            -> Creates and returns a new spring with the specified start position (optional).
        
        Properties/Members:
            AutoUpdate: boolean [default=true]
            -> Specifies whether the spring should automatically call ::Update()
               when .Target is changed.
            
            Damper: number [default=1]
            -> Specifies the damper for the spring velocity.
            
            EPSILON: number [readonly]
            -> Internal constant that's basically just a really small number.
            
            Position: number [default=0]
            -> Returns or specifies the spring's current position.
            
            ReachedTarget: boolean [readonly] [default=true]
            -> Returns whether or not Position is equal to Target.
            
            Speed: number [default=1]
            -> Specifies the current speed that will be applied to the spring's velocity
               when the target is updated.
            
            Sprung: boolean [readonly]
            -> Returns whether or not the spring's position is >= EPSILON (1e-6).
            
            Target: number [default=0]
            -> Returns or specifies the spring's target. If AudoUpdate is true, the spring
               will begin updating/animating.
            
            Updating: boolean [readonly]
            -> Returns whether or not this current spring is updating its position.
            
            Velocity: number [default=0]
            -> Returns or specifies the spring's current velocity.
        
        Events:
            Updated -> (position: number)
            -> Fired when (and only when) the spring's position is updated.
               
               Example:
               spring.Updated:Connect(function(position: number)
                   print('Current position:', position)
               end)
            
            TargetReached -> (target: number)
            -> Fired when (and only when) the springs position reaches its target.
               
               Example:
               spring.TargetReached:Connect(function(target: number)
                   print('Reached spring target:', target)
               end)
        
        Methods:
               <void> ::Impulse(velocity: number)
               -> Impulses the spring with the specified velocity.
               
               <number> ::Map(min: number, max: number)
               -> Maps the spring's position to the specified min and max values.
                  Equivalent to map(spring.Position, 0, 1, 0, 100)
                
                <number> ::MapInverse(min: number, max: number)
                -> Maps the spring's position (inverse) to the specified min and max values.
                   Equivalent to map(1 - spring.Position, 0, 1, 0, 100)
                
                <boolean, number> ::Read()
                -> Returns the updating state and current position of the spring.
                
                <void> ::Skip(delta: number)
                -> Skips by the specified delta time.
                
                <void> ::Update()
                -> Forces the spring to update towards its target position. If the current
                   position is equal to the target, the spring will only fire Updated once.
--]]

--= Module Loader =--
local require           = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= Class Root =--
local SawSpring         = { }
SawSpring.__classname   = 'SawSpring'
SawSpring.EPSILON       = 1e-3

--= Type Export =--
export type SawSpring   = {
    AutoUpdate: boolean,
    Clock: () -> number,
    Damper: number,
    EPSILON: number,
    Impulse: (velocity: number) -> (),
    Map: (self: {}, min: number, max: number) -> number,
    MapInverse: (self: {}, min: number, max: number) -> number,
    Position: number,
    Read: (self: {}) -> (boolean, number),
    ReachedTarget: boolean,
    Skip: (self: {}, delta: number) -> (),
    Speed: number,
    Sprung: boolean,
    Target: number,
    TargetReached: RBXScriptSignal,
    Update: (self: {}) -> (),
    Updated: RBXScriptSignal,
    Updating: boolean,
    Velocity: number
}

--= Dependencies =--
local classify          = require('$Classify')

--= Roblox Services =--
local runService        = game:GetService('RunService')

--= Constants =--
local EULER             = 2.7182818284590452353602874713527

--= Functions =--
local function _map(input: number, min: number, max: number): number
    return (((input - 0) * (max - min)) / (1 - 0)) + min
end

--= Class Internal =--
function SawSpring:_posVelocity(now: number): (number, number)
    local startPosition = self._position0
    local startVelocity = self._velocity0
    local targetPosition = self._target
    local damper = self._damper
    local speed = self._speed
    
    local t = speed * (now - self._time0)
    local damperSquared = damper * damper
     
    local h, sin, cosine
    if damperSquared < 1 then
        h = (1 - damperSquared) ^ 0.5
        local ep = EULER ^ ((-damper * t)) / h
        cosine, sin = ep * math.cos(h * t), ep * math.sin(h * t)
    elseif damperSquared == 1 then
        h = 1
        local ep = EULER ^ ((-damper * t)) / h
        cosine, sin = ep, ep*t
    else
        h = (damperSquared - 1) ^ 0.5
        local u = EULER ^ (((-damper + h) * t)) / (2 * h)
        local v = EULER ^ (((-damper - h) * t)) / (2 * h)
        cosine, sin = u + v, u - v
    end
    
    local cosH = h * cosine
    local damperSin = damper * sin
    
    local a = cosH + damperSin
    local b = speed * sin
    
    return
        a * startPosition + (1 - a) * targetPosition + (sin / speed) * startVelocity,
        -b * startPosition + b * targetPosition + (cosH - damperSin) * startVelocity
end

--= Class API =--
function SawSpring:Impulse(velocity: number)
    self.Velocity = self.Velocity + velocity
end

function SawSpring:Skip(delta: number)
	local now = self._clock()
	local position, velocity = self:_positionVelocity(now + delta)
	self._position0 = position
	self._velocity0 = velocity
	self._time0 = now
end

function SawSpring:Map(min: number, max: number): number
    return _map(self.Position, min, max)
end

function SawSpring:MapInverse(min: number, max: number): number
    return _map(1 - self.Position, min, max)
end

function SawSpring:Read(): (boolean, number)
    local position = self.Position
    local target = self.Target
    local updating
    
    updating = math.abs(position - target) > SawSpring.EPSILON or math.abs(self.Velocity) > SawSpring.EPSILON
    
    if updating then
        return true, position
    else
        return false, target
    end
end

function SawSpring:Update()
    if self._updateConnection then return end
    
    self._updateConnection = runService.RenderStepped:Connect(function()
        local active, position = self:Read()
        
        if active then
            self._updateEvent:Fire(position, 1 - position)
        else
            self._updateEvent:Fire(self.Target, 1 - self.Target)
            self._position0 = self.Target
            self._updateConnection:Disconnect()
            self._updateConnection = nil
            self._completeEvent:Fire(self.Target)
        end
    end)
    
    self:_markTrash(self._updateConnection)
end

--= Class Constructor =--
function SawSpring.new(startPos: number?, clock: () -> ()?): SawSpring
    local self = classify(SawSpring)
    
    startPos = startPos or 0
    
    self._autoUpdate = true
    self._clock = clock or tick
    self._time0 = self._clock()
    self._position0 = startPos
    self._velocity0 = 0 * startPos
    self._target = startPos
    self._damper = 1
    self._speed = 1
    
    self._updateEvent = Instance.new('BindableEvent')
    self.Updated = self._updateEvent.Event
    
    self._completeEvent = Instance.new('BindableEvent')
    self.TargetReached = self._completeEvent.Event
    
    self:_markTrash({ self._updateEvent, self._completeEvent })
    self:Update()
    return self
end

--= Class Properties =--
SawSpring.__properties = {
    AutoUpdate = { _internal = '_autoUpdate' },
    Clock = {
        get = function(self)
            return self._clock
        end,
        set = function(self, value: () -> number)
            local position, velocity = self:_posVelocity(self._clock())
            self._position0 = position
            self._velocity0 = velocity
            self._clock = value
            self._time0 = value()
        end
    },
    Damper = {
        get = function(self)
            return self._damper
        end,
        set = function(self, value: number)
            local now = self._clock()
            local position, velocity = self:_posVelocity(now)
            self._position0 = position
            self._velocity0 = velocity
            self._damper = math.clamp(value, 0, 1)
            self._time0 = now
        end
    },
    Position = {
        get = function(self)
            local position, _ = self:_posVelocity(self._clock())
            return position
        end,
        set = function(self, value: number)
            local now = self._clock()
            local _, velocity = self:_posVelocity(now)
            self._position0 = value
            self._velocity0 = velocity
            self._time0 = now
        end
    },
    ReachedTarget = {
        get = function(self)
            return self.Position == self.Target
        end
    },
    Speed = {
        get = function(self)
            return self._speed
        end,
        set = function(self, value: number)
            local now = self._clock()
            local position, velocity = self:_posVelocity(now)
            self._position0 = position
            self._velocity0 = velocity
            self._speed = value < 0 and 0 or value
            self._time0 = now
        end
    },
    Sprung = {
        get = function(self)
            return math.abs(self.Position) >= SawSpring.EPSILON
        end
    },
    Target = {
        get = function(self)
            return self._target
        end,
        set = function(self, value: number)
            local now = self._clock()
            local position, velocity = self:_posVelocity(now)
            self._position0 = position
            self._velocity0 = velocity
            self._target = value
            self._time0 = now
            
            if self._autoUpdate then
                self:Update()
            end
        end
    },
    Updating = {
        get = function(self)
            local updating, _ = self:Read()
            return updating
        end
    },
    Velocity = {
        get = function(self)
            local _, velocity = self:_posVelocity(self._clock())
            return velocity
        end,
        set = function(self, value: number)
            local now = self._clock()
            local position, _ = self:_posVelocity(now)
            self._position0 = position
            self._velocity0 = value
            self._time0 = now
        end
    }
}

--= Return Class =--
return SawSpring