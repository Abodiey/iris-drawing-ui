# Iris Drawing

A standalone PC Roblox UI library with a Windows 10-era Fluent light design.
Every visible element uses `Drawing.new`. One completely transparent, offscreen
CoreGui TextBox supplies native keyboard editing, selection, and clipboard input.
There is no gameplay code and no dependency on JJS or any other project.

## Load

```lua
local UI = loadstring(game:HttpGet(
    'https://raw.githubusercontent.com/Abodiey/iris-drawing-ui/main/dist/Iris.lua?v=1.0.20'
))()
local Window = UI:CreateWindow({Name = 'Example'})
local Section = Window:AddSection('General')
```

`dist/Iris.lua` bundles all modules; loading it performs no further HTTP requests.
Use a commit SHA in place of `main` to pin a specific revision.
The renderer converts hitbox coordinates through the invisible ScreenGuiأ¢â‚¬â„¢s
actual `AbsolutePosition`, including when its origin changes. Input uses raw
`UserInputService:GetMouseLocation()` and absolute GUI hitbox bounds.
Version 1.0.10 adds the light appearance, smooth native circle knobs, and scoped
wheel capture so scrolling over the interface does not also zoom the camera.
The complete [example](examples/Example.lua) demonstrates every control and config handling.

**Runtime:** PC keyboard/mouse, Roblox client services, CoreGui input access,
and a [Synapse-compatible Drawing API](https://synapsexdocs.github.io/libraries/drawing/)
supporting Square/Text/Circle/Line, `TextBounds`, `ZIndex`, numeric `Font` IDs, `NumSides`,
`Remove()`, and `Transparency` where 1 is opaque and 0 is fully transparent.
Pointer positions come only from `UserInputService:GetMouseLocation()`.
Widget hit regions are invisible Frames under a ScreenGui. Their local positions
subtract the ScreenGui's actual `AbsolutePosition` so their absolute screen bounds
match the Drawing geometry. Origin changes invalidate layout automatically.
Hit tests use each frame's `AbsolutePosition` and `AbsoluteSize`.
All visible pixels remain Drawing objects. The hidden TextBox only handles input.
Madium is the current target; native Luau mock tests cover interactions and cleanup.
Live Madium hitbox coordinates have been checked against Drawing geometry.
Native focus and camera input consumption still need verification in the executor. This is not a stock Roblox Studio UI module.

## Visual design

Version 1.0.19 uses the Windows 10 Settings shell: a transparent caption over the
page surface, a back button, minimize/maximize/close controls, a neutral
navigation material, a blue active marker, Home, and a working Find a setting
field. The first section is the 28-pixel page heading; later sections use plain
20-pixel headings without decorative rules. Fields are 280 x 32 pixels, switches
44 x 20 pixels, body text and informational labels
14 pixels, and title-bar captions 12 pixels. The fallback Drawing font is scaled to bring
its metrics closer to Segoe UI.

The navigation pane is a full-height `SystemControlPageBackgroundChromeLowBrush`
surface (`#F2F2F2`): it runs behind the caption bar, so the title and the back
button sit over it exactly as they do in the Settings app. Home is the first
48-pixel row, the
search box is 288 x 32 pixels with a 2-pixel border and the magnifier on the
right, and the window name acts as the single group header above the category
list. Selecting a section paints the row with `SystemListLowColor` (`#E6E6E6`)
and a 4 x 24-pixel accent marker at the pane's left edge.

Wide windows (900 pixels or more) have a 320-pixel navigation pane.
Widths of 720-899 use 256 pixels, and 600-719 use 200 pixels. Narrower windows
keep the single content column. Section shortcuts scroll the existing page;
they do not hide controls or change flags. Search matches section and control
names, and clicking a result scrolls to the matching setting. Home returns to
the top; Back restores prior scroll positions and only exists while there is a
recorded position. Navigation scrolls independently.

Click and hover targets match visible controls in both X and Y; blank row
space and labels do not open dropdowns, toggle switches, or capture input.
Sliders accept initial clicks only on their track/thumb area; dragging continues
outside it until release. The slider value is editable in place: clicking the
number opens the native text field with the accent focus border, input is
filtered to digits, and a commit runs through the same clamping and snapping as
`SetValue`. All existing methods, configs and callback semantics
remain unchanged.

Colors, typography, spacing and motion are centralized in
`src/Internal/Theme.lua`; `src/Internal/Shell.lua` draws navigation. Segoe UI is used only when the backend exposes it. Madium exposes UI, System,
Plex and Monospace, so its current release uses the closest fallback. Drawing
has no native backdrop blur or ClearType text rasterizer: the navigation
material is the documented acrylic fallback tone rather than a live blur. This
is a faithful layout and control adaptation,
not a pixel-identical native Windows compositor.

Design references: Microsoft's [Windows 10 UWP guidelines](https://download.microsoft.com/download/2/4/A/24A81A29-77CF-4AA5-967E-64E42554F21B/UWP%20app%20design%20guidelines%20v1509.pdf)
and [compact control sizing](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/compact-sizing).
Palette and control values follow the Windows 10 in-box
[XAML theme resources](https://learn.microsoft.com/en-us/windows/apps/design/style/xaml-theme-resources)
and were checked against the stock Settings app on Windows 10 22H2 at 100% scaling.

## Window and sections

```lua
local Window = UI:CreateWindow({
    Name = 'Example',
    Size = Vector2.new(960, 720),      -- optional; minimum requested size 320 x 180
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
or drag the scrollbar. Maximize toggles viewport size and restores the original
size and position. The title-bar minimize button minimizes/restores; the close button
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
| Slider | Finite number. Required `Min` and `Max` with `Max > Min`; positive `Step` defaults to 1. Values clamp and snap relative to Min. Default Min. The number beside the track is click-to-edit: click it, type a value, press Enter to commit or Escape to cancel, and use Up/Down to step by `Step`. |
| Dropdown | Exact option string. Unique nonempty strings in a dense `Options` array, up to 500. Defaults to the first option; an empty list uses `''` and renders as a disabled combo box that does not accept clicks. |
| MultiDropdown | Array of option strings, default `{}`. Rejects unknown/duplicate selections and stores them in Options order. |
| Textbox | Single-line UTF-8 string, default `''`. MaxLength is 1أ¢â‚¬â€œ4096 codepoints, default 256. Control characters become spaces. Enter, outside click, scrolling, hiding, or native focus loss commits; Escape cancels. Mouse and keyboard selection are supported. |
| Keybind | KeyCode name string or `'None'`, default `'None'`. `OnChanged(keyName)` reports binding changes. `Callback(true/false)` reports press/release, never binding changes. Click to capture; Escape cancels; Backspace/Delete clears. The window ToggleKey is reserved. Typing in any native TextBox suppresses actions. |
| ColorPicker | Color3, default Windows 10 accent blue (`#0078D7`). Callback/GetValue return Color3. The popup uses saturation/value and hue strips; config uses RGB arrays. No alpha channel. |
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

### Drawing origin correction

Mouse input uses only raw `UserInputService:GetMouseLocation()`; hit regions keep their unshifted GUI coordinates. The renderer adds a Y translation to every Drawing position using the common-monitor-ratio heuristic: choose the closest candidate `viewportWidth / ratio` at or above the current viewport height (gap under 80 pixels), then subtract the viewport height. If no ratio matches, use the greatest viewport height observed by that renderer. The calculation refreshes on viewport changes; no native cursor replacement, GUI-inset queries, or secondary mouse sources are used.

On the tested 1280ط£â€”1024 monitor this produces +23 for a 1280ط£â€”1001 windowed viewport and 0 for fullscreen. This is an inference for the affected Drawing backend, not a measured OS title-bar size. Other monitor ratios, freely resized windows, and backends already using client coordinates can produce incorrect corrections. The fallback requires having observed a taller viewport; it cannot discover an unknown height by itself. X is not adjusted.

## Windows 10 light appearance

The internal theme in `src/Internal/Theme.lua` defines the palette, font choices, and brief motion timings. The window has square corners, a flat caption bar and Windows-style caption buttons; content uses plain Settings-style rows with rectangular bordered fields. Multi-select options use square 20-pixel checkboxes. Toggle tracks and slider thumbs retain native rounded geometry. Popups and notifications use the transient flyout surface and a thin border; the standard Drawing API cannot reproduce desktop backdrop blur.

The accent is the Windows 10 default `#0078D7`. Windows 11 uses `#0078D4`; that value and the Fluent 2 brushes (`ControlFillColor*`, `TextFillColor*`, `SubtleFillColor*`) are deliberately not used here. Translucent in-box brushes are composited over white: text `#000000`, secondary text `#666666`, disabled text `#999999`, control borders `#999999`, hover borders `#666666`, list low `#E6E6E6`, list medium `#CCCCCC`, button fill `#CCCCCC` (pressed `#999999`), toggle stroke `#333333`, slider rail `#999999`, and the flyout border `#DBDBDB`.

Interaction states follow the same resources: buttons keep their fill on hover and gain a `#999999` border, toggles blend toward the accent-high `#4DA1E3` on hover and `#666666` when pressed, slider thumbs darken to `#171717` on hover, combo fields take the `#CCCCCC` list-medium hover fill, and the close caption button uses `#E81123`. The content scrollbar is an overlay sliver that fades in while scrolling, thickens under the pointer, and hides again; the back button exists only while a scroll position has been recorded.

Text uses a named Segoe UI / Segoe UI Semibold Drawing font if the backend exposes it through `Drawing.Fonts`; otherwise it uses the available proportional Plex font (ID 2 fallback). The standard Drawing API exposes neither arbitrary system font names nor font weights, so unsupported semibold falls back to regular weight with size hierarchy. No duplicate-text fake bold is used.

Hover transitions take 100 ms, control transitions 150 ms, popup fades 160 ms, and the scrollbar fade 200 ms. They share the central update system and stop when settled. Retiring popups fade visually without retaining input ownership. Input, flags/configs, the public API and viewport-origin correction are unchanged. Disabled theme tokens are available internally; no disabled-control API or separate checkbox control is added.

Design references: Microsoft's [Windows 10 UWP design guidelines](https://download.microsoft.com/download/2/4/A/24A81A29-77CF-4AA5-967E-64E42554F21B/UWP%20app%20design%20guidelines%20v1509.pdf) and [Windows title-bar guidance](https://learn.microsoft.com/en-us/windows/apps/design/basics/titlebar-design). This styling deliberately uses the requested square Windows 10 geometry rather than the later rounded Windows 11 defaults.
