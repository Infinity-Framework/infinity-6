--[[
    QuickDebug.lua
    FriendlyBiscuit
    Created on 05/26/2021 @ 16:52:44
    
    Description:
        Allows developers to quickly attach input to callbacks via a rough testing buttons.
    
    Documentation:
        <TextButton> ::AddDebugButton(text: string, callback: Function)
        -> Creates and returns a quick and basic TextButton that will automatically appear
           on your screen. Useful for adding input to testing operations.
--]]

--= Root =--
local QuickDebug        = { Priority = 1 }

--= Object References =--
local local_player      = game.Players.LocalPlayer
local player_gui        = local_player:WaitForChild('PlayerGui')

--= Variables =--
local list, labels
local cache = { }

--= Job API =--
function QuickDebug:AddDebugButton(text: string, callback: Function): TextButton
    if not self.FLAGS.DEVELOPER_MODE then return end
    while not list do task.wait() end
    
    local button = Instance.new('TextButton', list)
    button.BackgroundColor3 = Color3.new(1, 1, 1)
    button.Size = UDim2.new(0, 150, 1, 0)
    button.Text = text
    button.Activated:Connect(callback)
    
    cache[text] = button

    return button
end

function QuickDebug:SetDebugButtonState(button: string, state: boolean)
    local btn = cache[button]
    if not btn then return end
    btn.Visible = state
end

function QuickDebug:AddDebugLabel(text: string): TextLabel
    if not self.FLAGS.DEVELOPER_MODE then return end
    while not labels do task.wait() end
    
    local label = Instance.new('TextLabel', labels)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Right
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.7
    label.Size = UDim2.fromOffset(1, 12)
    label.Font = 'Code'
    label.TextSize = 14
    label.RichText = true
    
    if text then
        label.Text = text
    else
        label.Text = ''
    end
    
    return label
end

function QuickDebug:Init(): nil
    local screen_gui = Instance.new('ScreenGui', player_gui)
    screen_gui.IgnoreGuiInset = true
    screen_gui.ZIndexBehavior = 'Global'
    screen_gui.ResetOnSpawn = false
    screen_gui.DisplayOrder = 9999
    
    local frame = Instance.new('Frame', screen_gui)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.Position = UDim2.fromOffset(0, 80)
    
    local l_frame = Instance.new('Frame', screen_gui)
    l_frame.BackgroundTransparency = 1
    l_frame.Size = UDim2.fromScale(1, 1)
    l_frame.Position = UDim2.fromOffset(-5, -6)
    
    local layout = Instance.new('UIListLayout', frame)
    layout.HorizontalAlignment = 'Center'
    layout.FillDirection = 'Horizontal'
    
    local l_layout = Instance.new('UIListLayout', l_frame)
    l_layout.HorizontalAlignment = 'Right'
    l_layout.VerticalAlignment = 'Bottom'
    l_layout.Padding = UDim.new(0, 6)
    
    list = frame
    labels = l_frame
end

--= Return Job =--
return QuickDebug