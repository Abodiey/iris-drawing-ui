# Iris Drawing

A standalone PC Roblox UI library with a restrained iOS-inspired light design.
Every visible element uses `Drawing.new`. One completely transparent, offscreen
CoreGui TextBox supplies native keyboard editing, selection, and clipboard input.
There is no gameplay code and no dependency on JJS or any other project.

## Load

```lua
local UI = loadstring(game:HttpGet(
    'https://raw.githubusercontent.com/Abodiey/iris-drawing-ui/main/dist/Iris.lua?v=1.0.4'
))()
local Window = UI:CreateWindow({Name = 'Example'})
local Section = Window:AddSection('General')
```

`dist/Iris.lua` bundles all modules; loading it performs no further HTTP requests.
Use a commit SHA in place of `main` to pin a specific revision.
Version 1.0.4 adds the light appearance, smooth native circle knobs, and scoped
wheel capture so scrolling over the interface does not also zoom the camera.
The complete [example](examples/Example.lua) demonstrates every control and config handling.

**Runtime:** PC keyboard/mouse, Roblox client services, CoreGui input access,
and a [Synapse-compatible Drawing API](https://synapsexdocs.github.io/libraries/drawing/)
supporting Square/Text/Circle, `TextBounds`, `ZIndex`, `Font = 2`, `NumSides`,
`Remove()`, and `Transparency` where 1 is opaque and 0 is fully transparent.
Layout and pointer coordinates use viewport pixels; the current Roblox GUI
inset is removed from mouse polling for hit testing, dragging, and scrolling.
All visible pixels remain Drawing objects. The hidden TextBox only handles input.
Madium is the current target; native Luau mock tests cover interactions and cleanup.
Live Madium focus, camera input consumption, and coordinate alignment still need
verification in the executor. This is not a stock Roblox Studio UI module.

## Window and sections

```lua
local Window = UI:CreateWindow({
    Name = 'Example',
    Size = Vector2.new(480, 560),      -- optional; minimum requested size 320 x 180
    Position = Vector2.new(100, 80),  -- optional; otherwise centered
    ToggleKey = 'RightShift',        -- KeyCode name, or 'None' to disable
})
local Section = Window:AddSection('General')
Window:SetMinimized(true)
Window:SetVisible(false)
Window:SetSize(Vector2.new(520, 620))
```

Version 1 supports one window per UI instance and any number of sections.
Sections lay out controls vertically. Drag the title bar, scroll over content,
or drag the scrollbar. The yellow button minimizes/restores; the red button
hides. RightShift or `SetVisible(true)` reopens the window. Size and position
are clamped to the viewport; a smaller viewport can override the minimum
requested size. Controls stop accepting pointer input during hide/minimize.
Keybind actions remain available when the window is hidden or minimized.
Tabs are outside the v1 API. Sections and control models are separated from
window layout so another page layout can be added later without changing them.

## Controls

Every `Add...` method takes **one options table** with `Name`. Value controls
share `Flag`, `Default`, `Callback`, `GetValue()`, and `SetValue(value, silent)`.
Construction is silent. Setters return the control, update its flag, redraw,
and invoke the callback once if the normalized value changed. Pass `true` as
the second argument to suppress change callbacks. Unknown option names and
duplicate flags raise errors rather than silently accepting typos.

```lua
local Toggle = Section:AddToggle({
    Name = 'Enabled', Flag = 'Enabled', Default = false,
    Callback = function(value) print(value) end,
})
Toggle:SetValue(true)
print(Toggle:GetValue())
```

The following snippets are a compact reference for every control:

```lua
Section:AddButton({Name = 'Apply', Callback = function() print('clicked') end})
Section:AddToggle({Name = 'Enabled', Flag = 'Enabled', Default = false, Callback = function(v) end})
Section:AddSlider({Name = 'Speed', Flag = 'Speed', Min = 1, Max = 100, Step = 1, Default = 50, Callback = function(v) end})
Section:AddDropdown({Name = 'Mode', Flag = 'Mode', Options = {'A', 'B'}, Default = 'A', Callback = function(v) end})
Section:AddMultiDropdown({Name = 'Items', Flag = 'Items', Options = {'A', 'B'}, Default = {'A'}, Callback = function(v) end})
Section:AddTextbox({Name = 'Profile', Flag = 'Profile', Default = '', Placeholder = 'Name', MaxLength = 256, Callback = function(v) end})
Section:AddKeybind({Name = 'Action', Flag = 'ActionKey', Default = 'F', OnChanged = function(keyName) end, Callback = function(pressed) end})
Section:AddColorPicker({Name = 'Color', Flag = 'Color', Default = Color3.fromRGB(10, 132, 255), Callback = function(v) end})
local Label = Section:AddLabel({Name = 'Status: Ready'})
Label:SetText('Status: Updated')
Section:AddSeparator({Name = 'Advanced'})  -- Name may be omitted for a plain line
```

| Control | Value and behavior |
| --- | --- |
| Button | No value or flag. Callback receives no arguments. Fires on mouse-down. |
| Toggle | Boolean. Default `false`. |
| Slider | Finite number. Required `Min` and `Max` with `Max > Min`; positive `Step` defaults to 1. Values clamp and snap relative to Min. Default Min. |
| Dropdown | Exact option string. Unique nonempty strings in a dense `Options` array, up to 500. Defaults to the first option; an empty list uses `''`. |
| MultiDropdown | Array of option strings, default `{}`. Rejects unknown/duplicate selections and stores them in Options order. |
| Textbox | Single-line UTF-8 string, default `''`. MaxLength is 1–4096 codepoints, default 256. Control characters become spaces. Enter, outside click, scrolling, hiding, or native focus loss commits; Escape cancels. Mouse and keyboard selection are supported. |
| Keybind | KeyCode name string or `'None'`, default `'None'`. `OnChanged(keyName)` reports binding changes. `Callback(true/false)` reports press/release, never binding changes. Click to capture; Escape cancels; Backspace/Delete clears. The window ToggleKey is reserved. Typing in any native TextBox suppresses actions. |
| ColorPicker | Color3, default iOS blue. Callback/GetValue return Color3. The popup uses saturation/value and hue strips; config uses RGB arrays. No alpha channel. |
| Label | Display only; `SetText(string)`. No Flag, Default, or Callback. |
| Separator | Display only; optional Name. No Flag, Default, or Callback. |

`Dropdown:SetOptions(options, silent)` and `MultiDropdown:SetOptions(options, silent)`
replace options with a defensive copy. A removed dropdown selection falls back
to the first option (or `''`); multi selections retain only valid items. A changed
selection invokes its callback unless silent. Any open popup closes.

Callbacks run synchronously and should return quickly. Errors are caught and
reported with `warn`; they do not stop the UI. A held key releases with
`Callback(false)` on rebinding, hiding/minimizing, focus loss, or destruction,
including silent binding changes. Capture does not also trigger the new key.
Pointer handling does not block underlying game input; the calling script
can decide how its own actions should behave while the UI is open.

## Flags and configs

Flags are optional stable strings and must be unique across the entire instance.
Similar names are independent; an exact duplicate is an error. Treat `UI.Flags`
as a read-only snapshot; assigning to it does not call callbacks or update controls.
Use setters. Returned arrays/configs are defensive copies.

```lua
print(UI.Flags.Enabled)
UI:SetFlag('Enabled', true)          -- same behavior as the control setter
UI:SetFlag('Enabled', false, true)   -- silent
print(UI:GetFlag('Enabled'))
local config = UI:GetConfig()       -- {Version = 1, Flags = {...}}
UI:LoadConfig(config)               -- callbacks for changed values
UI:LoadConfig(config, true)         -- silent
```

Only flagged controls are serialized. Config values are JSON-safe; colors are
`{r, g, b}` arrays in [0, 1], keybinds are strings, and multi selections are arrays.
A partial config leaves missing flags alone. Unknown flags, extra config fields,
invalid values, and unsupported versions raise errors **before changing anything**.
After validation, values/flags commit together; callbacks run in control creation
order and see the committed state. Active text drafts and popups close on load.
The library does not read/write files or contain game-specific persistence.

External scripts may encode/decode using Roblox HttpService:

```lua
local HttpService = game:GetService('HttpService')
local json = HttpService:JSONEncode(UI:GetConfig())
UI:LoadConfig(HttpService:JSONDecode(json))
-- A caller may store json using its own persistence system.
```

## Notifications

```lua
UI:Notify({Title = 'Saved', Content = 'Settings updated', Duration = 4})
```

Title defaults to `Iris`, Content to `''`, Duration to 4 seconds (positive, up to
120). Notifications fade in/out and stack from the bottom-right. At most five
are retained, fewer for short viewports; the oldest is discarded when full.
Long text truncates to one line. Notifications can also be shown without a window.

## Cleanup

```lua
UI:Destroy()      -- idempotent; permanently unloads this instance
-- Window:Destroy() does the same thing.
```

Destroy disconnects every owned connection, removes owned Drawing objects,
destroys the hidden ScreenGui/TextBox, clears flags, control lists, popups,
notifications, and interaction state. Other scripts' Drawing objects are untouched.
Load the bundled entry point again to create a fresh instance. Setters on a
destroyed instance raise errors. The example cleans up its previous instance
when rerun; the library itself does not install a global singleton.

## Development

```text
src/Library.lua              Public API and window/section/config models
src/Controls/Model.lua       Validation and shared control setters
src/Controls/Views.lua       Drawing-only controls and popups
src/Internal/Runtime.lua     Central input, layout, animation, lifecycle
src/Internal/Renderer.lua    Retained Drawing pool, text fitting, clipping
src/Internal/Util.lua        Geometry and small validation helpers
examples/Example.lua         Full standalone example
scripts/build.py             Deterministic single-file bundler
tests/                       Roblox/Drawing mocks and interaction regressions
```

```sh
python scripts/build.py
python scripts/build.py --check
python -m pip install -r tests/requirements.txt
python tests/run.py
# Or exercise the mocks under native Luau without Lupa:
python tests/run.py --luau /path/to/luau
```

The first window paints synchronously so startup does not depend on a deferred
engine callback. Render failures report an explicit Iris Drawing error. The renderer uses direct
Drawing object properties as documented by Synapse. Geometry is set before visibility.

There is one RenderStepped connection and centralized input connections, no
per-control listeners. One cancellable task monitors frame delivery at 4 Hz;
it only drives updates at 60 Hz while RenderStepped has stalled, then yields
back to the engine signal. Idle frames do not redraw. Drawing objects are pooled
and reused. Popup lists virtualize visible rows. Clipping is geometric for
shapes; text is horizontally shortened and hidden if its full vertical bounds
cross the clip edge, since Drawing provides no container clipping. Rounded
shapes use non-overlapping square bands; color gradients use a cached grid.
The pool retains its high-water size until Destroy.

See [validation notes](docs/TESTING.md) for what is verified and the live-runtime
smoke test. [API contract](docs/API.md) is the short reference for future edits.

MIT licensed. Original implementation; API familiarity does not imply copying
Rayfield, Linoria, or Apple's assets.
