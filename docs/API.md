# Iris Drawing API contract

Version 1 targets one PC window per library instance. Sections own controls;
the runtime owns input, focus, popups, notifications, and a single render loop.
The renderer pools Drawing primitives and clips them in screen coordinates.
No game dependencies or remote module fetches in the bundle.

Every control accepts an options table with Name. Value controls accept Flag,
Default, and Callback. Keybinds use OnChanged for binding changes and Callback
for pressed/released state. Construction is silent. GetValue returns a copy.
SetValue(value, silent) validates, updates flags and visuals, then invokes the
callback unless silent is true. Equal values do not invoke callbacks.
Duplicate flags are errors. Config loading validates everything before
committing, and callbacks see all the committed values.

UI: CreateWindow, GetFlag, SetFlag, GetConfig, LoadConfig, Notify, Destroy.
Window: AddSection, SetVisible, SetMinimized, SetSize, Destroy.
Section: AddButton, AddToggle, AddSlider, AddDropdown, AddMultiDropdown,
AddTextbox, AddKeybind, AddColorPicker, AddLabel, AddSeparator.
Value controls: GetValue, SetValue. Label: SetText.
Dropdowns: SetOptions(options, silent).

One retained primitive pool and centralized input/render connections.
CreateWindow paints synchronously. One cancellable watchdog supplies frames
only while RenderStepped delivery has stalled. Render errors are reported.
Use standard Drawing object properties directly, following the Synapse API. Set geometry before enabling visibility.
No redraw on idle frames. Popups close on main scrolling, dragging, resizing,
and hiding. Rectangles clip geometrically. Text draws only when full bounds
fit and is truncated horizontally. Rounded shapes use clipped square bands.

Runtime contract: Drawing.new Square/Text, TextBounds, Remove, screen pixel
coordinates, Transparency 1 = opaque / 0 = invisible, Font 2, ZIndex support;
Roblox client services and access to create an invisible CoreGui TextBox.
Drawing is a runtime extension, not a stock Roblox Studio API.

Pointer sampling uses only UserInputService:GetMouseLocation(). Invisible hitbox
Frames are positioned relative to the ScreenGui's actual AbsolutePosition so
absolute bounds match Drawing screen coordinates. GUI origin changes invalidate
layout; no fixed mouse offsets or inset-query APIs are used.
