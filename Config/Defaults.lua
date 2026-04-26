--[[
    Config/Defaults.lua
    Default saved variable structure. AceDB merges these with the player's
    saved profile on load, so new keys added here appear automatically
    for existing users on next login.
--]]

local addonName, MR = ...

MR.Defaults = {
    profile = {
        locked  = true,
        -- Per-group layout settings
        groups = {
            stealth = {
                enabled  = true,
                width    = 220,
                grow     = "UP",
                x        = 0,
                y        = 200,
            },
            cooldowns = {
                enabled  = true,
                width    = 220,
                grow     = "UP",
                x        = 0,
                y        = 150,
            },
            procs = {
                enabled  = true,
                width    = 220,
                grow     = "UP",
                x        = 0,
                y        = 100,
            },
            dots = {
                enabled  = true,
                width    = 220,
                grow     = "UP",
                x        = 0,
                y        = 50,
            },
            debuffs = {
                enabled  = true,
                width    = 220,
                grow     = "UP",
                x        = 0,
                y        = 0,
            },
        },
        -- Per-tracker overrides keyed by tracker id (e.g. "rupture", "shadow_dance")
        -- Anything not set here falls back to the tracker definition defaults.
        trackers = {
            -- Example entry shape (populated from tracker defaults on first load):
            -- rupture = {
            --     enabled      = true,
            --     color        = { r=0.9, g=0.1, b=0.1, a=1.0 },
            --     showName     = true,
            --     nameOverride = nil,
            --     flashBelow   = 5,
            --     texture      = nil,
            -- },
        },
    },
}
