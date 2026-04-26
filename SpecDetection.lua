--[[
    SpecDetection.lua
    Detects the player's rogue specialization on login/reload and loads the
    correct tracker definition. Spec switching mid-session is NOT supported —
    a /reload is required. This is documented in README.md.
--]]

local addonName, MR = ...
MR.SpecDetection = {}
local SpecDetection = MR.SpecDetection

-- VERIFY: Spec indices for Rogue in Midnight. In Dragonflight:
--   1 = Assassination, 2 = Outlaw, 3 = Subtlety
local SPEC_INDEX = {
    ASSASSINATION = 1,
    OUTLAW        = 2,
    SUBTLETY      = 3,
}

local SPEC_NAMES = {
    [1] = "Assassination",
    [2] = "Outlaw",
    [3] = "Subtlety",
}

-- Returns the loaded tracker table for the current spec, or nil with error.
function SpecDetection:LoadTrackerForCurrentSpec()
    local specIndex = MR.AuraEngine:GetCurrentSpec()
    if not specIndex then
        print("|cFFFF4444[MidnightRogue] Could not detect specialization. Did Blizzard change GetSpecialization()?|r")
        return nil, nil
    end

    local specName = SPEC_NAMES[specIndex]
    if not specName then
        print("|cFFFF4444[MidnightRogue] Unknown spec index: " .. tostring(specIndex) .. ". Check SpecDetection.lua.|r")
        return nil, nil
    end

    -- Only Subtlety is implemented. Others will fail gracefully with a clear message.
    local tracker = MR.Trackers and MR.Trackers[specName]
    if not tracker then
        print("|cFFFFAA00[MidnightRogue] No tracker defined for " .. specName .. ". Only Subtlety is currently implemented.|r")
        return nil, specName
    end

    return tracker, specName
end

function SpecDetection:GetSpecName()
    local specIndex = MR.AuraEngine:GetCurrentSpec()
    return SPEC_NAMES[specIndex] or "Unknown"
end
