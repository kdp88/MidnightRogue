# MidnightRogue

A configuration-heavy rogue addon for World of Warcraft: Midnight. Tracks all rogue mechanics across all specializations with ability icon bars.

## Specialization Support

Currently implemented: **Subtlety**
Planned: Assassination, Outlaw

## Important: Spec Profile Switching

**Specialization profiles are loaded on login and UI reload only.**

Changing your specialization mid-session will NOT automatically switch your bar layout. To apply your new spec's profile, type `/reload` after changing specs.

This is a deliberate design choice for stability. Future versions may support live spec switching via `PLAYER_SPECIALIZATION_CHANGED`.

## Setup

1. Copy the `MidnightRogue` folder into your `Interface\AddOns\` directory.
2. Install required libraries into `MidnightRogue\libs\`:
   - [LibStub](https://www.wowace.com/projects/libstub)
   - [AceAddon-3.0](https://www.wowace.com/projects/ace3)
   - [AceConsole-3.0](https://www.wowace.com/projects/ace3)
   - [AceEvent-3.0](https://www.wowace.com/projects/ace3)
   - [AceDB-3.0](https://www.wowace.com/projects/ace3)
   - [AceConfig-3.0](https://www.wowace.com/projects/ace3)
   - [AceConfigDialog-3.0](https://www.wowace.com/projects/ace3)
   - [LibSharedMedia-3.0](https://www.wowace.com/projects/libsharedmedia-3-0)
3. Log in and type `/mr` to open configuration.

## Commands

| Command | Action |
|---|---|
| `/mr` | Open configuration panel |
| `/mr unlock` | Unlock bar groups for dragging |
| `/mr lock` | Lock bar groups in place |
| `/mr reset` | Reset all bar positions to defaults |
| `/reload` | Reload UI (required after spec change) |

## API Verification Required (Midnight)

> **All spell IDs and API calls in this addon are based on Dragonflight (11.x) data.**
> When Midnight PTR or live access becomes available, verify the following before shipping:
>
> - `.toc` interface number (currently set to `120000` as placeholder)
> - All spell IDs in `TrackerDefinitions/Subtlety.lua`
> - `C_Spell.GetSpellInfo()` availability and return shape
> - `C_UnitAuras` API surface (function names and return values)
> - `GetSpecializationInfo()` return values for rogue specs

## Architecture

```
Core.lua              -- Addon init, event routing, combat state
SpecDetection.lua     -- Detect spec on login/reload, load correct tracker
AuraEngine.lua        -- Single point of contact for ALL C_UnitAuras calls
TrackerDefinitions/
  Subtlety.lua        -- All spell definitions, priorities, display config
Display/
  BarRenderer.lua     -- Bar frame creation, icon rendering, recycling pool
  BarGroup.lua        -- Bar group containers, anchoring, grow direction
  Animations.lua      -- Flash, fade, pulse on low duration
Config/
  Options.lua         -- Ace3 options table
  Defaults.lua        -- Default settings per spec
  Profiles.lua        -- Profile switching logic
```
