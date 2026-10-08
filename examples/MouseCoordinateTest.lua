--[[
Iris Drawing mouse coordinate diagnostic.
Run this while the UI is open. Compare the colored rings with the OS cursor.
Press P to print the sampled coordinates. Press End to remove the overlay.
This temporary overlay uses Drawing objects and does not change the library.
--]]
local UIS = game:GetService('UserInputService')
local GuiService = game:GetService('GuiService')
local RunService = game:GetService('RunService')

local colors = {
    Raw = Color3.fromRGB(255, 70, 70),
    MinusInset = Color3.fromRGB(255, 190, 40),
    PlusInset = Color3.fromRGB(60, 220, 100),
    MinusHalf = Color3.fromRGB(80, 170, 255),
    PlusHalf = Color3.fromRGB(210, 90, 255),
    InputPosition = Color3.fromRGB(255, 255, 255),
}
local rings, labels = {}, {}
local names = {'Raw', 'MinusInset', 'PlusInset', 'MinusHalf', 'PlusHalf', 'InputPosition'}
for i, name in ipairs(names) do
    local ring = Drawing.new('Circle')
    ring.Filled = false
    ring.Thickness = 2
    ring.NumSides = 48
    ring.Radius = 10
    ring.Color = colors[name]
    ring.Visible = true
    rings[name] = ring

    local label = Drawing.new('Text')
    label.Text = name
    label.Size = 14
    label.Font = 2
    label.Outline = true
    label.Color = colors[name]
    label.Position = Vector2.new(14, 14 + (i - 1) * 20)
    label.Visible = true
    labels[name] = label
end
local help = Drawing.new('Text')
help.Text = 'Rings mark candidate cursor positions | P = print values | Esc = close'
help.Size = 14
help.Font = 2
help.Outline = true
help.Color = Color3.new(1, 1, 1)
help.Position = Vector2.new(14, 14 + #names * 20)
help.Visible = true

local lastInputPosition
local function vector2(value)
    return Vector2.new(value.X, value.Y)
end
local function update()
    local raw = UIS:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    local half = inset.Y * 0.5
    local candidates = {
        Raw = vector2(raw),
        MinusInset = Vector2.new(raw.X - inset.X, raw.Y - inset.Y),
        PlusInset = Vector2.new(raw.X + inset.X, raw.Y + inset.Y),
        MinusHalf = Vector2.new(raw.X, raw.Y - half),
        PlusHalf = Vector2.new(raw.X, raw.Y + half),
        InputPosition = lastInputPosition or vector2(raw),
    }
    for _, name in ipairs(names) do
        local point = candidates[name]
        rings[name].Position = point
        labels[name].Text = string.format('%s  (%d, %d)', name, math.floor(point.X + .5), math.floor(point.Y + .5))
    end
end
local connections = {}
local function cleanup()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, ring in pairs(rings) do ring:Remove() end
    for _, label in pairs(labels) do label:Remove() end
    help:Remove()
end

update()
table.insert(connections, RunService.RenderStepped:Connect(update))
table.insert(connections, UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        lastInputPosition = Vector2.new(input.Position.X, input.Position.Y)
    end
end))
table.insert(connections, UIS.InputBegan:Connect(function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == Enum.KeyCode.End then
        cleanup()
    elseif input.KeyCode == Enum.KeyCode.P then
        local raw = UIS:GetMouseLocation()
        local inset = GuiService:GetGuiInset()
        local event = lastInputPosition or vector2(raw)
        print(string.format(
            '[Iris mouse test] raw=(%.1f, %.1f) inset=(%.1f, %.1f) event=(%.1f, %.1f) viewport=%s',
            raw.X, raw.Y, inset.X, inset.Y, event.X, event.Y,
            tostring(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize)
        ))
    end
end))

