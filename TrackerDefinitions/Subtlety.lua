--[[
    TrackerDefinitions/Subtlety.lua

    castID: the spell ID that appears in UNIT_SPELLCAST_SUCCEEDED (the ability you press).
            Omit if the same as spellID.
    duration: aura duration in seconds. 0 = no expiry (e.g. Stealth — cleared by other means).
              For combo-point-scaled abilities (Rupture) this is the max duration at 6 CP.

    IMPORTANT: All spell IDs and durations are from Dragonflight (11.x).
    VERIFY ALL against Midnight live/PTR before shipping.
--]]

local addonName, MR = ...
MR.Trackers = MR.Trackers or {}

MR.Trackers["Subtlety"] = {

    -- =========================================================
    -- BUFFS (stealth states + cooldowns)
    -- =========================================================
    {
        id       = "vanish",
        name     = "Vanish",
        spellID  = 11327,
        castID   = 1856,       -- 1856 = Vanish ability; 11327 = the buff it applies
        duration = 3,
        auraType = "player_buff",
        group    = "buffs",
        priority = 99,
        color    = { r = 0.2, g = 0.2, b = 1.0, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "shadow_dance",
        name     = "Shadow Dance",
        spellID  = 185422,
        castID   = 185313,     -- 185313 = Shadow Dance ability; 185422 = the buff
        duration = 8,
        auraType = "player_buff",
        group    = "buffs",
        priority = 98,
        color    = { r = 0.5, g = 0.0, b = 0.8, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "subterfuge",
        name     = "Subterfuge",
        spellID  = 115192,
        castID   = 115192,
        duration = 3,
        auraType = "player_buff",
        group    = "buffs",
        priority = 97,
        color    = { r = 0.6, g = 0.2, b = 0.9, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        optional     = true,
    },

    -- =========================================================
    -- COOLDOWNS (part of buffs group)
    -- =========================================================
    {
        id          = "secret_technique",
        name        = "Secret Technique",
        spellID     = 280719,
        castID      = 280719,
        duration    = 25,      -- base cooldown; haste-scaled at load time
        hasteScales = true,
        talents     = {
            { spellID = 441274, durationMult = 0.90 },  -- Disorienting Strikes: -10% CD
        },
        auraType     = "player_buff",
        group        = "buffs",
        priority     = 91,
        color        = { r = 0.4, g = 0.0, b = 0.9, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        flashBelow   = 3,
    },
    {
        id       = "sprint",
        name     = "Sprint",
        spellID  = 2983,
        castID   = 2983,
        duration = 12,
        cooldown = 120,
        talents  = {
            { spellID = 231691, cooldown = 60 },  -- Improved Sprint
        },
        auraType = "player_buff",
        group    = "buffs",
        priority = 85,
        color    = { r = 0.8, g = 0.8, b = 0.0, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "crimson_vial",
        name     = "Crimson Vial",
        spellID  = 185311,
        castID   = 185311,
        duration = 30,         -- cooldown window; bar visible while on CD
        auraType = "player_buff",
        group    = "buffs",
        priority = 86,
        color    = { r = 0.9, g = 0.1, b = 0.1, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        flashBelow   = 5,
    },
    {
        id       = "slice_and_dice",
        name     = "Slice and Dice",
        spellID  = 315496,
        castID   = { 315496, 196819, 441776 },  -- direct cast, Eviscerate, Coup de Grace
        duration = 42,         -- base: 5 CP max = 12 + (5 * 6)
        talents  = {
            { spellID = 193531, durationAdd = 6 },  -- Deeper Stratagem: +1 CP
            { spellID = 394320, durationAdd = 6 },  -- Secret Stratagem: +1 CP
        },
        auraType = "player_buff",
        group    = "buffs",
        priority = 87,
        color    = { r = 0.0, g = 0.8, b = 0.3, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        flashBelow   = 5,
    },
    {
        id       = "symbols_of_death",
        name     = "Symbols of Death",
        spellID  = 212283,
        castID   = 212283,
        duration = 35,
        auraType = "player_buff",
        group    = "buffs",
        priority = 90,
        color    = { r = 1.0, g = 0.2, b = 0.2, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "shadow_blades",
        name     = "Shadow Blades",
        spellID  = 121471,
        castID   = 121471,
        duration = 20,
        auraType = "player_buff",
        group    = "buffs",
        priority = 89,
        color    = { r = 0.1, g = 0.1, b = 0.1, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "flagellation_buff",
        name     = "Flagellation",
        spellID  = 384631,
        castID   = 323654,     -- cast ID is the Flagellation ability
        duration = 12,
        auraType = "player_buff",
        group    = "buffs",
        priority = 88,
        color    = { r = 0.9, g = 0.5, b = 0.1, a = 1.0 },
        showDuration = true,
        showStacks   = true,
        optional     = true,
    },

    -- =========================================================
    -- PROCS
    -- =========================================================
    {
        id       = "premeditation",
        name     = "Premeditation",
        spellID  = 343160,
        castID   = 343160,
        duration = 15,
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
        spellID  = 376888,
        castID   = 376888,
        duration = 8,
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
        spellID  = 382105,
        castID   = 382105,
        duration = 8,
        auraType = "player_buff",
        group    = "procs",
        priority = 78,
        color    = { r = 0.7, g = 0.0, b = 0.9, a = 1.0 },
        showDuration = true,
        showStacks   = true,
        flashBelow   = 3,
        optional     = true,
    },
    -- =========================================================
    -- DOTS ON TARGET
    -- =========================================================
    {
        id       = "rupture",
        name     = "Rupture",
        spellID  = 1943,
        castID   = 1943,
        duration = 24,         -- max duration at 6 combo points
        auraType = "target_debuff",
        group    = "debuffs",
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
        id       = "cheap_shot",
        name     = "Cheap Shot",
        spellID  = 1833,
        castID   = 1833,
        duration = 4,
        auraType = "target_debuff",
        group    = "debuffs",
        priority = 62,
        color    = { r = 1.0, g = 0.6, b = 0.0, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        flashBelow   = 2,
    },
    {
        id       = "kidney_shot",
        name     = "Kidney Shot",
        spellID  = 408,
        castID   = 408,
        duration = 8,          -- max at 5 CP
        auraType = "target_debuff",
        group    = "debuffs",
        priority = 61,
        color    = { r = 1.0, g = 0.4, b = 0.0, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        flashBelow   = 2,
    },
    {
        id       = "find_weakness",
        name     = "Find Weakness",
        spellID  = 91021,
        castID   = { 1833, 185438 },  -- Cheap Shot, Shadowstrike
        duration = 10,
        auraType = "target_debuff",
        group    = "debuffs",
        priority = 60,
        color    = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },
        showDuration = true,
        showStacks   = false,
    },
    {
        id       = "find_weakness_backstab",
        name     = "Find Weakness (Backstab)",
        spellID  = 91021,
        castID   = 53,
        duration = 10,
        auraType = "target_debuff",
        group    = "debuffs",
        priority = 59,
        color    = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        optional     = true,  -- requires Improved Backstab (319949); off by default
    },
    {
        id       = "echoing_reprimand",
        name     = "Echoing Reprimand",
        spellID  = 323547,
        castID   = 323547,
        duration = 15,
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
        spellID  = 323654,
        castID   = 323654,
        duration = 12,
        auraType = "target_debuff",
        group    = "debuffs",
        priority = 58,
        color    = { r = 0.8, g = 0.3, b = 0.0, a = 1.0 },
        showDuration = true,
        showStacks   = false,
        optional     = true,
    },
}
