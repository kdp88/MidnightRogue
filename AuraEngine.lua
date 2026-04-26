--[[
    AuraEngine.lua
    Single point of contact for ALL Blizzard aura/spell API calls.
    If Blizzard changes C_UnitAuras or C_Spell in a Midnight patch, fix it here only.
    Every function returns nil + logs an error on API failure rather than hard crashing.
--]]

local addonName, MR = ...
MR.AuraEngine = {}
local AuraEngine = MR.AuraEngine

local function APIError(fnName, reason)
    print("|cFFFF4444[MidnightRogue] API ERROR:|r " .. fnName .. " — " .. (reason or "function unavailable"))
    print("|cFFFFAA00[MidnightRogue] Check AuraEngine.lua — Blizzard may have changed this API in Midnight.|r")
end

-- Returns aura data table or nil. Checks player's own buffs.
-- VERIFY: C_UnitAuras.GetPlayerAuraBySpellID exists in Midnight
function AuraEngine:GetPlayerBuff(spellID)
    if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then
        APIError("C_UnitAuras.GetPlayerAuraBySpellID")
        return nil
    end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    if not aura then return nil end
    return {
        name           = aura.name,
        icon           = aura.icon,
        stacks         = aura.applications or 0,
        duration       = aura.duration or 0,
        expirationTime = aura.expirationTime or 0,
        isActive       = true,
    }
end

-- Scans a unit for a specific debuff by spellID cast by the player.
-- VERIFY: C_UnitAuras.GetAuraDataBySpellID exists in Midnight
function AuraEngine:GetTargetDebuff(unit, spellID)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataBySpellID then
        APIError("C_UnitAuras.GetAuraDataBySpellID")
        return nil
    end
    -- false = debuff filter, true = cast by player only
    local aura = C_UnitAuras.GetAuraDataBySpellID(unit, spellID, false)
    if not aura then return nil end
    -- Filter to player-cast only
    if aura.sourceUnit ~= "player" then return nil end
    return {
        name           = aura.name,
        icon           = aura.icon,
        stacks         = aura.applications or 0,
        duration       = aura.duration or 0,
        expirationTime = aura.expirationTime or 0,
        isActive       = true,
    }
end

-- Returns spell icon texture ID. Used at bar creation time.
-- VERIFY: C_Spell.GetSpellInfo exists and returns .iconID in Midnight
function AuraEngine:GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then return info.iconID end
    end
    -- Fallback to old API if Midnight still exposes it
    if GetSpellInfo then
        local _, _, icon = GetSpellInfo(spellID)
        return icon
    end
    APIError("C_Spell.GetSpellInfo / GetSpellInfo", "no spell icon API found")
    return nil
end

-- Returns the player's current specialization index (1, 2, 3) or nil.
-- Rogue: 1 = Assassination, 2 = Outlaw, 3 = Subtlety
-- VERIFY: GetSpecializationInfo still works in Midnight and spec order is unchanged
function AuraEngine:GetCurrentSpec()
    if not GetSpecialization then
        APIError("GetSpecialization")
        return nil
    end
    return GetSpecialization()
end

-- Returns current game time in seconds (float). Safe — has existed forever.
function AuraEngine:Now()
    return GetTime()
end
