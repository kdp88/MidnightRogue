# MidnightRogue Dev Log

## Current Status
Subtlety Rogue spec — bars are showing, persisting correctly, and counting down.
Core bar loop is working. Next session: verify all spell IDs are correct in Midnight and test each tracker.

## Architecture: How Aura Tracking Works
Midnight blocks all aura query APIs (`C_UnitAuras`, `UnitAura`) and `COMBAT_LOG_EVENT_UNFILTERED`
cannot be registered by addons. We track auras via `UNIT_SPELLCAST_SUCCEEDED` + hardcoded durations.

- Player casts a spell → `UNIT_SPELLCAST_SUCCEEDED` fires → `AuraEngine:OnSpellCast(spellID)`
- AuraEngine looks up the cast in `_castMap` (built from tracker definitions at load time)
- Sets `state[spellID] = { expirationTime = GetTime() + duration, ... }`
- `RefreshDisplay` reads from `AuraEngine.state` to build bars
- Bars that expire via OnUpdate are released to pool; pool reuse is now safe (expired flag cleared)

Each tracker definition has:
- `spellID` — the buff/debuff ID (used as state key and for display)
- `castID` — the ability spell ID fired in UNIT_SPELLCAST_SUCCEEDED (omit if same as spellID)
- `duration` — hardcoded aura duration in seconds (0 = no expiry, cleared by game state)

## Known Limitations
- Auras active on login/reload won't show until recast
- Stack counts not tracked (no aura event to increment them)
- Rupture duration is hardcoded at 24s (6 CP max) — shorter applications will outlast their bar

## Slash Commands
- `/mr` — open config panel
- `/mr unlock` / `/mr lock` — toggle bar drag mode
- `/mr reset` — reset bar positions to defaults
- `/mr debug` — dump AuraEngine state and castMap to chat

## Pending Testing
Verify each bar works in-game and spell IDs are correct for Midnight:
- [ ] Vanish — 3s countdown
- [ ] Shadow Dance — 8s countdown
- [ ] Subterfuge — 3s countdown (talent)
- [ ] Symbols of Death — 35s countdown
- [ ] Shadow Blades — 20s countdown
- [ ] Flagellation — 12s countdown (talent)
- [ ] Premeditation — 15s proc (talent)
- [ ] The Rotten — 8s proc (talent)
- [ ] Danse Macabre — 8s proc (talent)
- [ ] Rupture — 24s countdown on target
- [ ] Find Weakness — 10s debuff on target
- [ ] Echoing Reprimand — 15s debuff (talent)
- [ ] Flagellation debuff — 12s on target (talent)

## Spell IDs To Verify in Midnight
All IDs are from Dragonflight (11.x). Verify with `/script print(C_Spell.GetSpellInfo(ID).name)` in-game.

| Ability | castID | spellID (buff) |
|---|---|---|
| Vanish | 1856 | 11327 |
| Shadow Dance | 185313 | 185422 |
| Subterfuge | 115192 | 115192 |
| Symbols of Death | 212283 | 212283 |
| Shadow Blades | 121471 | 121471 |
| Flagellation | 323654 | 384631 (buff) / 323654 (debuff) |
| Premeditation | 343160 | 343160 |
| The Rotten | 376888 | 376888 |
| Danse Macabre | 382105 | 382105 |
| Rupture | 1943 | 1943 |
| Find Weakness | 91021 | 91021 |
| Echoing Reprimand | 323547 | 323547 |

## Next Up
1. Verify all spell IDs above are correct in Midnight
2. **Cooldown recharge bars** — new tracker type `cooldown_recharge` using `GetSpellCooldown`
   - First candidate: Secret Technique (45s CD)
   - Shows remaining cooldown time (inverse of aura bars)
   - Needs its own display group or reuse existing "cooldowns" group
3. Assassination spec
4. Outlaw spec
5. Live spec switching via `PLAYER_SPECIALIZATION_CHANGED`

## Bugs Fixed
- `goto continue` in Core.lua — WoW uses Lua 5.1, no goto. Replaced with nested ifs.
- `TrackerDefinitions/Subtlety.lua` used global `MR` instead of vararg `local addonName, MR = ...`
- `Options.lua` description widget used `get` instead of `name` as a function
- `.toc` interface number was `120000` placeholder — corrected to `120005`
- Library load order wrong — AceGUI must load before AceConfigDialog; AceConfigRegistry before AceConfig
- `AddToBlizOptions` crashes in Midnight — removed, `/mr` opens config directly
- `COMBAT_LOG_EVENT_UNFILTERED` is fully blocked for addon registration in Midnight
- `UnitAura` and `C_UnitAuras` are unavailable in Midnight
- `expirationTime = 0` (no-expiry bars) treated as expired by BarRenderer — fixed to use nil endTime
- Macro spam caused bars to flash — guard added to OnSpellCast to not reset active auras
- `PLAYER_REGEN_ENABLED` was calling `Reset()` wiping all active aura state on leaving combat — removed
- **Bar pool reuse bug** — `ReleaseBar` was not clearing `bar.expired` or `bar._flashing`, causing recycled bars to be immediately released again on first OnUpdate tick. This was the root cause of bars flashing and disappearing.
- Stealth removed from tracker (user preference)
- Secret Technique removed from aura tracker (no associated buff; will return as cooldown recharge bar)
