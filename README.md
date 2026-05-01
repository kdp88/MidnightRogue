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
3. Log in and type `/mr` to open configuration.

## Configuration

### Opening the panel

Type `/mr` to open the settings panel. It has three tabs: **Buffs**, **Procs**, and **Debuffs**.

### Unlocking bars for repositioning

Click **Unlock Bars** in the top-right of the settings panel. The button turns green and reads **Lock Bars** while unlocked. Drag any bar group to reposition it. Click **Lock Bars** to save the position and re-lock. The lock state persists across sessions.

### Enable / disable a tracker

Click the **green or gray box on the left** of any tracker row to toggle it on or off. Green = enabled, gray = disabled. Takes effect immediately.

### Bar width (per group)

Each tab has a **Width** row with `[-]` and `[+]` buttons. Each click steps by 10px (range 100–400px). All bars in that group resize immediately.

### Bar height (per group)

Each tab has a **Height** row with `[-]` and `[+]` buttons. Each click steps by 4px (range 16–64px). Bar text and stack counts scale automatically with height.

### Bar color (per tracker)

Click the **small colored square on the right** of any tracker row to open the color picker.

- WoW's built-in color picker opens if available. Drag to pick a color — the bar updates live. Click OK to confirm, Cancel to revert.
- If the built-in picker is unavailable (Midnight API restriction), a 12-color preset palette appears instead. Click any swatch to apply.

The swatch always reflects the current effective color — either your saved override or the tracker's default.

### Find Weakness (Backstab)

The **Find Weakness (Backstab)** tracker (`find_weakness_backstab`) is **disabled by default**. It tracks the Find Weakness debuff applied by Backstab, which requires the Improved Backstab talent. Enable it in the Debuffs tab if you have that talent.

When enabled, Backstab casts contribute to the Find Weakness bar alongside Cheap Shot and Shadowstrike. Only one bar is shown — `find_weakness_backstab` is a state contributor only and never renders its own bar.

## Commands

| Command | Action |
|---|---|
| `/mr` | Open configuration panel |
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
Core.lua              -- Addon init, event routing, combat state, display refresh
SpecDetection.lua     -- Detect spec on login/reload, load correct tracker
AuraEngine.lua        -- All aura tracking via UNIT_SPELLCAST_SUCCEEDED
TrackerDefinitions/
  Subtlety.lua        -- Spell definitions, priorities, display config, colors
Display/
  BarRenderer.lua     -- Bar frame pool, icon rendering, height/font scaling
  BarGroup.lua        -- Bar group containers, anchoring, grow direction, drag
  Animations.lua      -- Flash on low duration
Config/
  SettingsUI.lua      -- Settings panel (raw WoW frames; no AceGUI)
  Defaults.lua        -- Default profile values for all groups and trackers
  Profiles.lua        -- Spec profile switching logic
```
