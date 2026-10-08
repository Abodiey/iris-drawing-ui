-- Iris Drawing v1 example. No game-specific behavior.
local previous = rawget(_G, 'IrisDrawingExample')
if previous then previous:Destroy() end

local UI = loadstring(game:HttpGet(
    'https://raw.githubusercontent.com/Abodiey/iris-drawing-ui/main/dist/Iris.lua?v=1.0.11'
))()
_G.IrisDrawingExample = UI

local Window = UI:CreateWindow({
    Name = 'Iris Drawing',
    Size = Vector2.new(480, 560),
    ToggleKey = 'RightShift',
})
local General = Window:AddSection('GENERAL')
local Status = General:AddLabel({Name = 'A reusable Drawing interface'})

local Enabled = General:AddToggle({
    Name = 'Enabled', Flag = 'Enabled', Default = true,
    Callback = function(value) Status:SetText('Enabled: ' .. tostring(value)) end,
})
General:AddSlider({
    Name = 'Intensity', Flag = 'Intensity', Min = 0, Max = 100, Step = 0.5, Default = 50,
    Callback = function(value) print('Intensity:', value) end,
})
local Style = General:AddDropdown({
    Name = 'Style', Flag = 'Style', Options = {'Default', 'Compact', 'Comfortable'}, Default = 'Default',
    Callback = function(value) print('Style:', value) end,
})
General:AddMultiDropdown({
    Name = 'Panels', Flag = 'Panels', Options = {'Overview', 'Details', 'History'}, Default = {'Overview'},
    Callback = function(value) print('Panels:', table.concat(value, ', ')) end,
})
General:AddTextbox({
    Name = 'Profile name', Flag = 'ProfileName', Default = 'My profile', Placeholder = 'Enter a name', MaxLength = 80,
    Callback = function(value) print('Profile:', value) end,
})
General:AddKeybind({
    Name = 'Notify key', Flag = 'NotifyKey', Default = 'F',
    OnChanged = function(keyName) print('New binding:', keyName) end,
    Callback = function(pressed)
        if pressed then UI:Notify({Title = 'Keybind', Content = 'Your action key was pressed', Duration = 2}) end
    end,
})
General:AddColorPicker({
    Name = 'Accent value', Flag = 'Accent', Default = Color3.fromRGB(10, 132, 255),
    Callback = function(value) print('Selected RGB:', value.R, value.G, value.B) end,
})
General:AddSeparator({Name = 'ACTIONS'})
General:AddButton({
    Name = 'Show notification',
    Callback = function() UI:Notify({Title = 'Iris', Content = 'Every visible pixel uses Drawing.new', Duration = 4}) end,
})

local Settings = Window:AddSection('SETTINGS')
Settings:AddLabel({Name = 'Scroll to see more. RightShift reopens a closed window.'})
local savedConfig
Settings:AddButton({
    Name = 'Save settings in memory',
    Callback = function()
        savedConfig = UI:GetConfig()
        UI:Notify({Title = 'Saved', Content = 'Settings are stored in this example script'})
    end,
})
Settings:AddButton({
    Name = 'Restore saved settings',
    Callback = function()
        if savedConfig then UI:LoadConfig(savedConfig)
        else UI:Notify({Title = 'No saved settings', Content = 'Save settings first'}) end
    end,
})
Settings:AddButton({Name = 'Set Enabled programmatically', Callback = function() UI:SetFlag('Enabled', true) end})
Settings:AddButton({Name = 'Replace dropdown options', Callback = function() Style:SetOptions({'Default', 'Minimal'}) end})
Settings:AddButton({Name = 'Minimize window', Callback = function() Window:SetMinimized(true) end})
Settings:AddButton({Name = 'Destroy UI', Callback = function() UI:Destroy() end})

-- Value controls share one update API:
-- Enabled:SetValue(false, true) -- silent
-- print(Enabled:GetValue(), UI:GetFlag('Enabled'))
-- UI.Flags is for reading. Use setters to change values.
-- External persistence (when the runtime supports file functions):
-- writefile('iris-config.json', game:GetService('HttpService'):JSONEncode(UI:GetConfig()))
-- UI:LoadConfig(game:GetService('HttpService'):JSONDecode(readfile('iris-config.json')))
UI:Notify({Title = 'Iris is ready', Content = 'Drag the title bar. Use RightShift to show or hide.'})
