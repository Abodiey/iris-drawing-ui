--[[
Iris Drawing mouse coordinate diagnostic.
Run while the UI is open. Compare the colored rings to the OS cursor.
Press P to print all coordinate samples. Press End to remove the overlay.
This temporary overlay uses Drawing objects and does not change the library.
]]
local UIS = game:GetService('UserInputService')
local GuiService = game:GetService('GuiService')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local mouse = Players.LocalPlayer:GetMouse()

local baseColors = {
    Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 190, 40),
    Color3.fromRGB(60, 220, 100), Color3.fromRGB(80, 170, 255),
    Color3.fromRGB(210, 90, 255), Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(0, 210, 220), Color3.fromRGB(255, 100, 200),
    Color3.fromRGB(255, 245, 80), Color3.fromRGB(150, 255, 100),
    Color3.fromRGB(255, 130, 50), Color3.fromRGB(130, 150, 255),
    Color3.fromRGB(80, 255, 210), Color3.fromRGB(245, 120, 255),
    Color3.fromRGB(180, 255, 50), Color3.fromRGB(255, 80, 120),
}
local names = {
    'Raw', 'MouseXY', 'InputPosition',
    'MinusGuiInset', 'PlusGuiInset', 'MinusTopbar', 'PlusTopbar',
    'RawY-12', 'RawY-24', 'RawY-36', 'RawY-48', 'RawY-60',
    'RawY+12', 'RawY+24', 'RawY+36', 'RawY+48', 'RawY+60',
}
local rings, labels = {}, {}
for i, name in ipairs(names) do
    local ring = Drawing.new('Circle')
    ring.Filled = false
    ring.Thickness = 2
    ring.NumSides = 48
    ring.Radius = 9
    ring.Color = baseColors[(i - 1) % #baseColors + 1]
    ring.Visible = true
    rings[name] = ring

    local label = Drawing.new('Text')
    label.Text = name
    label.Size = 13
    label.Font = 2
    label.Outline = true
    label.Color = ring.Color
    label.Position = Vector2.new(12, 12 + (i - 1) * 17)
    label.Visible = true
    labels[name] = label
end
local help = Drawing.new('Text')
help.Text = 'P = print samples | End = remove overlay. Find the ring centered on cursor.'
help.Size = 13
help.Font = 2
help.Outline = true
help.Color = Color3.new(1, 1, 1)
help.Position = Vector2.new(12, 12 + #names * 17)
help.Visible = true

local lastInputPosition
local function v2(value)
    return Vector2.new(value.X, value.Y)
end
local function readTopbar()
    local ok, rect = pcall(function() return GuiService.TopbarInset end)
    if ok and rect then return rect.Min end
    return Vector2.new(0, 0)
end
local function sample()
    local raw = UIS:GetMouseLocation()
    local guiInset = GuiService:GetGuiInset()
    local topbar = readTopbar()
    local event = lastInputPosition or v2(raw)
    local points = {
        Raw = v2(raw),
        MouseXY = Vector2.new(mouse.X, mouse.Y),
        InputPosition = event,
        MinusGuiInset = Vector2.new(raw.X - guiInset.X, raw.Y - guiInset.Y),
        PlusGuiInset = Vector2.new(raw.X + guiInset.X, raw.Y + guiInset.Y),
        MinusTopbar = Vector2.new(raw.X - topbar.X, raw.Y - topbar.Y),
        PlusTopbar = Vector2.new(raw.X + topbar.X, raw.Y + topbar.Y),
    }
    for offset = 12, 60, 12 do
        points['RawY-' .. offset] = Vector2.new(raw.X, raw.Y - offset)
        points['RawY+' .. offset] = Vector2.new(raw.X, raw.Y + offset)
    end
    for i, name in ipairs(names) do
        local point = points[name]
        rings[name].Position = point
        labels[name].Text = string.format('%s (%d,%d)', name, math.floor(point.X + .5), math.floor(point.Y + .5))
    end
    return raw, guiInset, topbar, event
end

local connections = {}
local function cleanup()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, ring in pairs(rings) do ring:Remove() end
    for _, label in pairs(labels) do label:Remove() end
    help:Remove()
end
sample()
table.insert(connections, RunService.RenderStepped:Connect(sample))
table.insert(connections, UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        lastInputPosition = Vector2.new(input.Position.X, input.Position.Y)
    end
end))
table.insert(connections, UIS.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == Enum.KeyCode.End then
        cleanup()
    elseif input.KeyCode == Enum.KeyCode.P then
        local raw, guiInset, topbar, event = sample()
        print(string.format(
            '[Iris mouse test] GetMouseLocation=(%.1f,%.1f) Mouse.XY=(%.1f,%.1f) Input.Position=(%.1f,%.1f) GuiInset=(%.1f,%.1f) TopbarInset.Min=(%.1f,%.1f) ViewportSize=%s',
            raw.X, raw.Y, mouse.X, mouse.Y, event.X, event.Y,
            guiInset.X, guiInset.Y, topbar.X, topbar.Y,
            tostring(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize)
        ))
    end
end))
