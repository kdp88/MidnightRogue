# MidnightRogue — Claude Code Guidelines

## Project overview
A WoW addon (Midnight expansion) that shows rogue mechanic tracker bars for all specializations.

**Key constraint:** Midnight blocks `COMBAT_LOG_EVENT_UNFILTERED` and most aura query APIs. Detection is driven by `UNIT_AURA` events (primary) and `UNIT_SPELLCAST_SUCCEEDED` (fallback). `auraData` objects from Midnight are restricted — only `spellId` is directly readable; all other fields (`name`, `icon`, `applications`, `duration`, `expirationTime`, `auraInstanceID`) must be accessed via `pcall`.

## Test-driven development

**Always write tests before code.** For every change:

1. Write a failing test in `tests/` that describes the expected behavior
2. Run the suite to confirm it fails for the right reason
3. Implement the minimum code to make it pass
4. Run the suite again to confirm green

Run tests with:
```
lua tests/runner.lua
```

Tests use LuaUnit (`tests/luaunit.lua`). Mock infrastructure lives in `tests/mocks/`:
- `wow_api.lua` — stubs every Blizzard global the addon touches
- `addon_env.lua` — sets up the `addonName, MR` vararg environment

Override individual mock functions inside a test to simulate specific API states. Do not add permanent state to the mocks for one-off scenarios.

## Code conventions

- No comments unless the WHY is non-obvious (a hidden constraint, a Midnight API quirk, a workaround for a specific bug)
- No docstrings or multi-line comment blocks
- No error handling for impossible scenarios — trust internal guarantees
- No features beyond what the task requires

## Adding a new tracker

1. Add the tracker definition to `TrackerDefinitions/Subtlety.lua` (or the relevant spec file)
2. Add a test to `tests/test_subtlety_defs.lua` covering the new entry's required fields and any spec-specific behavior
3. If new AuraEngine behavior is needed, add tests to `tests/test_aura_engine.lua` first

## Architecture

| File | Role |
|---|---|
| `AuraEngine.lua` | State machine: `UNIT_AURA` (primary) + `UNIT_SPELLCAST_SUCCEEDED` (fallback) |
| `Core.lua` | Event registration, wires engine to display |
| `TrackerDefinitions/Subtlety.lua` | All Subtlety tracker definitions |
| `Display/BarRenderer.lua` | Renders individual bars |
| `Display/BarGroup.lua` | Manages groups of bars |
| `Config/` | AceDB defaults, options table, profile logic, settings UI |
