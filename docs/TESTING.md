# Validation and live runtime smoke test

Verified locally on 2026-10-08:

- All six source modules and the bundled release parse under native Luau 0.741.
- 39 interaction groups pass under native Luau and Lupa 2.8 (Lua 5.5).
- The complete example executes, reruns, and cleans up under both mock runtimes.
- The bundle reproduces exactly from source with `scripts/build.py --check`.
- Drawing-only layout was visually reviewed using mock-rendered previews.

The mocks exercise the actual release, not a separate implementation. Coverage:

- Construction, strict option validation, duplicate flags, defensive copies,
  normalization, setters, silence/no-op behavior, and callback ordering.
- Mouse toggle/button/slider, drag clamping, scrollbars, scrolling/clipping,
  dropdown modal ownership, popup positioning above/below anchors, option
  replacement, multiple selections, and virtualization for long option lists.
- Text commit/cancel, maximum length, UTF-8 boundaries, caret and selection,
  keybind capture/cancel/clear, repeat suppression, and held-key release.
- HSV color interactions, hue retention at black, programmatic picker updates,
  JSON-safe configs, partial loads, atomic rejection, and callback consistency.
- Hide/minimize transitions, viewport changes, notification stacking/caps/expiry,
  idle primitive reuse, centralized connections, callback errors, reentrant
  destroy, failed initialization cleanup, and fresh reload.

The user confirmed the previous invisible-interface issue came from Real and
provided a visible Madium screenshot. Version 1.0.4's light theme, mouse inset
normalization, wheel capture, and native circles have mock coverage; these new
changes have not yet been verified through live Madium interactions. The mocks
cannot certify native focus/clipboard, actual font metrics, or executor rendering.

Before treating a particular executor build as certified, run
`examples/Example.lua` in it and check these behaviors:

1. Every visible UI element is Drawing-rendered; the offscreen TextBox never
   paints text, a caret, background, selection, or border on screen.
2. Drag to every viewport edge. Change the Roblox window size. Resize through
   `Window:SetSize`. The full-size window stays inside the viewport.
3. Add enough controls for scrolling. Use the wheel and scrollbar. Text and
   rounded shapes do not spill past the content boundaries.
4. Open dropdowns at the bottom/right edges; long lists scroll independently.
   Click outside to dismiss. Multi selections remain open until dismissed.
5. Type, paste, select by keyboard/mouse, move the caret, use non-ASCII text,
   and verify Enter/outside-click commits while Escape cancels. Roblox chat
   focus suppresses keybind actions.
6. Capture, cancel and clear a keybind. Rebind while held. Focus loss, hide,
   minimize, and destroy release a held action exactly once.
7. Drag both HSV areas, including black/gray, and change a color externally
   while the picker is open. The hue indicator stays consistent.
8. Minimize/restore and close/reopen during animations. Hidden controls do not
   accept pointer input. RightShift reopens a hidden window.
9. Save/load a JSON config; test silent setters and similar/duplicate flags.
   Invalid config entries leave every control untouched.
10. Destroy twice and rerun the example. No duplicate interface, connections,
    hidden GUI objects, or Drawing objects should remain from the old instance.

The library does not call `cleardrawcache`; cleanup is restricted to its own
Drawing objects. The renderer uses direct object properties, including when
unrelated render-property helper functions exist in the script environment.

Regressions cover synchronous first paint without engine frame delivery,
property ordering, missing/recovered RenderStepped delivery, watchdog
cancellation, startup failure cleanup, and asynchronous error reporting.

Version 1.0.3 follows the requested Synapse Drawing contract: Transparency is
opacity (1 = opaque, 0 = invisible). Settled text must have Transparency = 1,
the window background = 0.97, and hiding must decrease opacity. Notification
text must remain opaque after fade-in. The mock visibility count follows this
same contract. These checks do not establish live executor rendering.

Contract reference: https://synapsexdocs.github.io/libraries/drawing/

Version 1.0.4 regressions cover changing GUI insets during pointer input,
wheel sink/pass over windows and popups, hidden/minimized bounds, independent
wheel action cleanup, Circle pooling/64 sides, and partially clipped circle bands.
Also check camera zoom stays unchanged while wheeling over the window and works
normally outside it; verify clicks line up with the cursor in Madium.

Version 1.0.5 corrects pointer translation direction for Madium: add the current
GUI inset rather than subtract it. Regression clicks use raw mouse coordinates
above the corresponding Drawing hit rectangle, including a changing inset.
Live executor alignment still requires user confirmation.
