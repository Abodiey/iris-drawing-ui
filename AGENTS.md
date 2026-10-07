# Guidance for future edits

Iris Drawing is a standalone UI library. Keep game logic and game-specific
configuration out of this repository.

- The documented README/API contract is the public API. Preserve method names,
  option names, callback meanings, flags, and config schema. Update documentation
  and examples together if an intentional public API change is required.
- All visible UI must use Drawing.new. Invisible offscreen Roblox GUI objects
  may only support input. Never introduce visible GUI-based fallbacks.
- Keep input and RenderStepped centralized in Runtime. Reuse Drawing objects.
  Geometric clipping must also apply to rounded bands. Do not assume native
  Drawing clipping support or clear another script's Drawing cache.
- Reject duplicate flags and validate a full config before committing changes.
  Keep color/keybind serialization and callback behavior documented.
- Callbacks can destroy the library or change another control; preserve that
  behavior. Destroy must remain idempotent and initialization failure must
  release all allocated resources.
- Edit src, then run `python scripts/build.py`. Never edit dist/Iris.lua directly.
- Run `python scripts/build.py --check` and `python tests/run.py` after changes.
  Native Luau mocks are available via `python tests/run.py --luau PATH`.
  Do not describe mocks as a live Roblox/executor test.
