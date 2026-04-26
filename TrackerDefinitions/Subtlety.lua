--[[
    TrackerDefinitions/Subtlety.lua
    All tracked auras, debuffs, and cooldown buffs for Subtlety Rogue.

    IMPORTANT: Every spell ID here is from Dragonflight (11.x).
    VERIFY ALL IDs against Midnight live/PTR before shipping.
    Use: /script print(C_Spell.GetSpellInfo(SPELL_ID).name) in-game to verify.

    auraType:
      "player_buff"   -- buff on the player (C_UnitAuras.GetPlayerAuraBySpellID)
      "target_debuff" -- debuff on target cast by player
      "focus_debuff"  -- debuff on focus cast by player

    group:
      Which bar group this tracker belongs to. Groups are defined in Config/Defaults.lua.
      "stealth"   -- stealth-state indicators
      "cooldowns" -- major cooldowns
      "procs"     -- short-window procs that need immediate attention
      "dots"      -- damage over time on target
      "debuffs"   -- non-dot debuffs on target
--]]

MR = MR or {}
MR.Trackers = MR.Trackers or {}

MR.Trackers["Subtlety"] = {

    -- =========================================================
    -- STEALTH STATES
    -- =========================================================
    {
        id       = "stealth",
        name     = "Stealth",
        spellID  = 1784,       -- VERIFY for Midnight
        auraType = "player_buff",
        group    = "stealth",
        priority = 100,
        color    = { r = 0.4, g = 0.4, b = 0.8, a = 1.0 },
        showDuration = false,
        showStacks   = false,
    },
    {
        id       = "vanish",
        name     = "Vanish",
        spellID  = 11327,      -- VERIFY: this is the Vanish *buff* ID, not the ability (1856)
        auraType = "player_buff",
        group    = "stealth",
        priority = 99,
        color    = { r = 0.2, g = 0.2, b = 1.0, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "shadow_dance",
        name     = "Shadow Dance",
        spellID  = 185422,     -- VERIFY for Midnight
        auraType = "player_buff",
        group    = "stealth",
        priority = 98,
        color    = { r = 0.5, g = 0.0, b = 0.8, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "subterfuge",
        name     = "Subterfuge",
        spellID  = 115192,     -- VERIFY: talent proc, may not exist in Midnight
        auraType = "player_buff",
        group    = "stealth",
        priority = 97,
        color    = { r = 0.6, g = 0.2, b = 0.9, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        optional     = true,   -- talent-gated, hidden by default if not talented
    },

    -- =========================================================
    -- MAJOR COOLDOWNS
    -- =========================================================
    {
        id       = "symbols_of_death",
        name     = "Symbols of Death",
        spellID  = 212283,     -- VERIFY for Midnight
        auraType = "player_buff",
        group    = "cooldowns",
        priority = 90,
        color    = { r = 1.0, g = 0.2, b = 0.2, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "shadow_blades",
        name     = "Shadow Blades",
        spellID  = 121471,     -- VERIFY for Midnight
        auraType = "player_buff",
        group    = "cooldowns",
        priority = 89,
        color    = { r = 0.1, g = 0.1, b = 0.1, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "flagellation_buff",
        name     = "Flagellation",
        spellID  = 384631,     -- VERIFY: this is the player haste buff from Flagellation in Dragonflight
        auraType = "player_buff",
        group    = "cooldowns",
        priority = 88,
        color    = { r = 0.9, g = 0.5, b = 0.1, a = 1.0 },
        showDuration = true,
        showStacks   = true,   -- stacks up to 30
        optional     = true,   -- talent-gated
    },

    -- =========================================================
    -- PROCS (short window, high priority)
    -- =========================================================
    {
        id       = "premeditation",
        name     = "Premeditation",
        spellID  = 343160,     -- VERIFY for Midnight
        auraType = "player_buff",
        group    = "procs",
        priority = 80,
        color    = { r = 1.0, g = 0.85, b = 0.0, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        flashBelow   = 4,
        optional     = true,
    },
    {
        id       = "the_rotten",
        name     = "The Rotten",
        spellID  = 376888,     -- VERIFY for Midnight
        auraType = "player_buff",
        group    = "procs",
        priority = 79,
        color    = { r = 0.8, g = 0.0, b = 0.3, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        flashBelow   = 4,
        optional     = true,
    },
    {
        id       = "danse_macabre",
        name     = "Danse Macabre",
        spellID  = 382105,     -- VERIFY for Midnight
        auraType = "player_buff",
        group    = "procs",
        priority = 78,
        color    = { r = 0.7, g = 0.0, b = 0.9, a = 1.0 },
        showDuration = true,
        showStacks   = true,   -- stacks with each unique ability used in Shadow Dance
        flashBelow   = 3,
        optional     = true,
    },
    {
        id       = "secret_technique_buff",
        name     = "Secret Technique",
        spellID  = 280719,     -- VERIFY for Midnight — this may be the ability not the buff
        auraType = "player_buff",
        group    = "procs",
        priority = 77,
        color    = { r = 0.3, g = 0.8, b = 0.8, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        optional     = true,
    },

    -- =========================================================
    -- DOTS ON TARGET
    -- =========================================================
    {
        id       = "rupture",
        name     = "Rupture",
        spellID  = 1943,       -- VERIFY for Midnight
        auraType = "target_debuff",
        group    = "dots",
        priority = 70,
        color    = { r = 0.9, g = 0.1, b = 0.1, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        flashBelow   = 5,
    },

    -- =========================================================
    -- DEBUFFS ON TARGET
    -- =========================================================
    {
        id       = "find_weakness",
        name     = "Find Weakness",
        spellID  = 91021,      -- VERIFY for Midnight — applied by Cheap Shot / Ambush from stealth
        auraType = "target_debuff",
        group    = "debuffs",
        priority = 60,
        color    = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "echoing_reprimand",
        name     = "Echoing Reprimand",
        spellID  = 323547,     -- VERIFY for Midnight — debuff on target that procs combo points
        auraType = "target_debuff",
        group    = "debuffs",
        priority = 59,
        color    = { r = 0.2, g = 0.9, b = 0.4, a = 1.0 },
        showDuration = true,
        showStacks   = true,
        optional     = true,
    },
    {
        id       = "flagellation_debuff",
        name     = "Flagellation (Debuff)",
        spellID  = 323654,     -- VERIFY for Midnight — the debuff on target
        auraType = "target_debuff",
        group    = "debuffs",
        priority = 58,
        color    = { r = 0.8, g = 0.3, b = 0.0, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        optional     = true,
    },
}
