--[[
    AuraEngine.lua
    Timer-based aura tracking driven by UNIT_SPELLCAST_SUCCEEDED.
    Since Midnight blocks aura query APIs and COMBAT_LOG_EVENT_UNFILTERED,
    we detect casts and apply hardcoded durations from tracker definitions.

    State table: AuraEngine.state[spellID] = { ... }
    Keyed by buff/debuff spellID (trackerDef.spellID), not cast ID.
--]]

local addonName, MR = ...
MR.AuraEngine = {}
local AuraEngine = MR.AuraEngine

AuraEngine.state = {}

-- Built at load time by BuildCastMap() — maps castID -> trackerDef
AuraEngine._castMap = {}

-- Called by Core.lua after the active tracker is loaded
function AuraEngine:BuildCastMap(trackerList)
    self._castMap = {}
    for _, def in ipairs(trackerList) do
        local castID = def.castID or def.spellID
        self._castMap[castID] = def
    end
end

-- Called by Core.lua on UNIT_SPELLCAST_SUCCEEDED for "player"
function AuraEngine:OnSpellCast(spellID)
    local def = self._castMap[spellID]
    if not def then return end

    -- Don't reset a bar that's already actively counting down.
    -- Macro spam can fire UNIT_SPELLCAST_SUCCEEDED repeatedly even on cooldown.
    local existing = self.state[def.spellID]
    if existing and existing.expirationTime > 0 and GetTime() < existing.expirationTime then
        return
    end

    local now = GetTime()
    local duration = def.duration or 0
    local expiration = duration > 0 and (now + duration) or 0

    self.state[def.spellID] = {
        name           = def.name,
        icon           = self:GetSpellIcon(def.spellID),
        stacks         = existing and existing.stacks or 1,
        duration       = duration,
        expirationTime = expiration,
        isActive       = true,
    }
end

-- Clear all aura state (on entering world or leaving combat)
function AuraEngine:Reset()
    self.state = {}
end

-- Clear only stealth-state auras (on PLAYER_REGEN_DISABLED — entered combat)
function AuraEngine:ClearStealthOnCombat()
    for spellID, data in pairs(self.state) do
        local def = self:GetDefBySpellID(spellID)
        if def and def.group == "stealth" and (def.duration or 0) == 0 then
            self.state[spellID] = nil
        end
    end
end

function AuraEngine:GetDefBySpellID(spellID)
    for _, def in pairs(self._castMap) do
        if def.spellID == spellID then return def end
    end
    return nil
end

function AuraEngine:GetPlayerBuff(spellID)
    local data = self.state[spellID]
    if not data then return nil end
    -- Expire stale entries
    if data.expirationTime > 0 and GetTime() > data.expirationTime then
        self.state[spellID] = nil
        return nil
    end
    return data
end

function AuraEngine:GetTargetDebuff(unit, spellID)
    return AuraEngine:GetPlayerBuff(spellID)
end

function AuraEngine:GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then return info.iconID end
    end
    if GetSpellInfo then
        local _, _, icon = GetSpellInfo(spellID)
        return icon
    end
    return nil
end

function AuraEngine:GetCurrentSpec()
    if not GetSpecialization then return nil end
    return GetSpecialization()
end

function AuraEngine:Now()
    return GetTime()
end
