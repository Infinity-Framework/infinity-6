--[[
       _ ___        _            __             ____
      (_) _ | ___  (_)_ _  ___ _/ /____  ____  |_  /
     / / __ |/ _ \/ /  ' \/ _ `/ __/ _ \/ __/ _/_ <
    /_/_/ |_/_//_/_/_/_/_/\_,_/\__/\___/_/   /____/
    Infinity Animator 3.0
    By FriendlyBiscuit
    
    EARLY-ALPHA TESTING. USE NOT RECOMMENDED!
--]]

--= Infinity Integration =--
local require   = require(game.ReplicatedStorage:WaitForChild('Infinity'))

--= External Classes =--
local Animation3 = require('$Animation3') ---@module Animation3

--= Root Table =--
local Animator3 = { }

--= Type Export =--
type Animator3  = {
    CreateAnimation: (...any) -> Animation3,
    CreateTween: ({
        Instance: Instance,
        Length: number,
        Style: string,
        Direction: string,
        Repeat: number,
        Reverse: boolean,
        Delay: number,
        Propertes: {any}
    }) -> Tween,
    Tween: ({
        Async: boolean,
        Instance: Instance,
        Length: number,
        Style: string,
        Direction: string,
        Repeat: number,
        Reverse: boolean,
        Delay: number,
        Propertes: {any}
    }) -> ()
}

--= Services & Requires =--
local tween_svc = game:GetService('TweenService')
local run_svc   = game:GetService('RunService')

--= Generic Tween API =--
function Animator3.CreateAnimation(...): Animation3
    return Animation3.new(...)
end

function Animator3.CreateTween(args: table): Tween
    return tween_svc:Create(
        args.Instance,
        TweenInfo.new(
            args.Length or 1,
            args.Style and Enum.EasingStyle[args.Style] or Enum.EasingStyle.Linear,
            args.Direction and Enum.EasingDirection[args.Direction] or Enum.EasingDirection.Out,
            args.Repeat or 0,
            args.Reverse or false,
            args.Delay or 0),
        args.Properties)
end

function Animator3:Tween(args: table)
    local tween = Animator3.CreateTween(args)
    local complete = false
    
    tween.Completed:Connect(function()
        complete = true
        tween:Destroy()
        
        if args.Callback then
            args.Callback()
        end
    end)
    
    tween:Play()
    
    if not args.Async then
        while not complete do run_svc.Heartbeat:Wait() end
        complete = nil
    end
end

return Animator3