--[[
    AuraEngine.lua
    Aura tracking driven primarily by UNIT_AURA events using C_UnitAuras APIs.
    Falls back to UNIT_SPELLCAST_SUCCEEDED for spells that do not register auras.

    State table: AuraEngine.state[spellID] = { ... }
    Keyed by buff/debuff spellID (trackerDef.spellID), not cast ID.
--]]

local addonName, MR = ...
MR.AuraEngine = {}
local AuraEngine = MR.AuraEngine

AuraEngine.state        = {}
AuraEngine._castMap     = {}   -- castID  -> { trackerDef, ... }
AuraEngine._spellIDMap  = {}   -- spellID -> trackerDef  (for UNIT_AURA lookups)
AuraEngine._instanceMap = {}   -- auraInstanceID -> { spellID, unit }

-- Called once at init. Checks IsPlayerSpell for each talent modifier and
-- overwrites duration/cooldown on the def in-place.
function AuraEngine:ResolveTalents(trackerList)
    for _, def in ipairs(trackerList) do
        if def._baseDuration == nil then def._baseDuration = def.duration end
        if def._baseCooldown == nil then def._baseCooldown = def.cooldown end
        if def._baseCastID == nil then
            if type(def.castID) == "table" then
                def._baseCastID = {}
                for _, v in ipairs(def.castID) do def._baseCastID[#def._baseCastID+1] = v end
            else
                def._baseCastID = def.castID
            end
        end
        def.duration = def._baseDuration
        def.cooldown = def._baseCooldown
        if type(def._baseCastID) == "table" then
            def.castID = {}
            for _, v in ipairs(def._baseCastID) do def.castID[#def.castID+1] = v end
        else
            def.castID = def._baseCastID
        end

        if def.talents then
            for _, mod in ipairs(def.talents) do
                if IsPlayerSpell(mod.spellID) then
                    if mod.duration     then def.duration = mod.duration end
                    if mod.durationAdd  then def.duration = def.duration + mod.durationAdd end
                    if mod.durationMult then def.duration = def.duration * mod.durationMult end
                    if mod.cooldown     then def.cooldown = mod.cooldown end
                    if mod.castIDAdd    then
                        if type(def.castID) == "table" then
                            table.insert(def.castID, mod.castIDAdd)
                        else
                            def.castID = { def.castID, mod.castIDAdd }
                        end
                    end
                end
            end
        end
        if def.hasteScales then
            local haste = (GetHaste and GetHaste()) or 0
            def.duration = def.duration / (1 + haste / 100)
        end
    end
end

-- Called by Core.lua after the active tracker is loaded.
-- Builds both _castMap (for spell cast fallback) and _spellIDMap (for UNIT_AURA).
function AuraEngine:BuildCastMap(trackerList)
    self._castMap    = {}
    self._spellIDMap = {}

    local function register(cid, def)
        if not self._castMap[cid] then self._castMap[cid] = {} end
        table.insert(self._castMap[cid], def)
    end

    for _, def in ipairs(trackerList) do
        -- _spellIDMap: skip triggerOnly entries — their spellID is covered by the
        -- non-triggerOnly sibling (e.g. find_weakness covers spellID 91021).
        if not def.triggerOnly then
            self._spellIDMap[def.spellID] = def
        end

        if type(def.castID) == "table" then
            for _, cid in ipairs(def.castID) do register(cid, def) end
        else
            register(def.castID or def.spellID, def)
        end
    end
end

-- ----------------------------------------------------------------
-- UNIT_AURA: primary detection path
-- ----------------------------------------------------------------

local UNIT_FILTER = {
    player_buff  = { unit = "player", filter = "HELPFUL" },
    target_debuff = { unit = "target", filter = "HARMFUL|PLAYER" },
    focus_debuff  = { unit = "focus",  filter = "HARMFUL|PLAYER" },
}

local UNIT_TO_AURATYPE = {
    player = "player_buff",
    target = "target_debuff",
    focus  = "focus_debuff",
}

-- Midnight restricts auraData to spellId only; all other fields throw on access.
-- Use pcall to attempt the useful ones and fall back to def/GetSpellIcon.
local function safeRead(t, k)
    local ok, v = pcall(function() return t[k] end)
    return ok and v or nil
end

function AuraEngine:_applyAura(auraData, unit)
    local spellId = safeRead(auraData, "spellId")
    if not spellId then return end
    local ok, def = pcall(function() return self._spellIDMap[spellId] end)
    if not ok or not def then return end

    local expectedUnit = UNIT_FILTER[def.auraType] and UNIT_FILTER[def.auraType].unit
    if expectedUnit ~= unit then return end

    local t = MR.db and MR.db.profile.trackers[def.id]
    if t and t.enabled == false then return end

    local stacks         = safeRead(auraData, "applications") or 0
    local duration       = safeRead(auraData, "duration") or def.duration or 0
    local expirationTime = safeRead(auraData, "expirationTime") or (duration > 0 and (GetTime() + duration) or 0)

    self.state[def.spellID] = {
        name           = def.name,
        icon           = self:GetSpellIcon(def.spellID),
        stacks         = stacks,
        duration       = duration,
        expirationTime = expirationTime,
        isActive       = true,
    }

    local instanceID = safeRead(auraData, "auraInstanceID")
    if instanceID then
        self._instanceMap[instanceID] = { spellID = def.spellID, unit = unit }
    end
end

function AuraEngine:_scanUnit(unit)
    local auraType = UNIT_TO_AURATYPE[unit]
    if not auraType then return end
    local filter = UNIT_FILTER[auraType].filter

    -- Clear existing state and instance entries for this unit
    for spellID in pairs(self.state) do
        local def = self._spellIDMap[spellID]
        if def and def.auraType == auraType then
            self.state[spellID] = nil
        end
    end
    for instanceID, info in pairs(self._instanceMap) do
        if info.unit == unit then
            self._instanceMap[instanceID] = nil
        end
    end

    if not C_UnitAuras then return end
    local i = 1
    while true do
        local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not auraData then break end
        self:_applyAura(auraData, unit)
        i = i + 1
    end
end

-- Called by Core.lua on UNIT_AURA events.
function AuraEngine:OnUnitAura(unit, updateInfo)
    if not UNIT_TO_AURATYPE[unit] then return end

    if not updateInfo or updateInfo.isFullUpdate then
        self:_scanUnit(unit)
        return
    end

    if updateInfo.addedAuras then
        for _, auraData in ipairs(updateInfo.addedAuras) do
            self:_applyAura(auraData, unit)
        end
    end

    if updateInfo.updatedAuraInstanceIDs and C_UnitAuras then
        for _, instanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
            local ok, auraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, instanceID)
            if ok and auraData then
                self:_applyAura(auraData, unit)
            end
        end
    end

    if updateInfo.removedAuraInstanceIDs then
        for _, instanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
            local info = self._instanceMap[instanceID]
            if info then
                self.state[info.spellID] = nil
                self._instanceMap[instanceID] = nil
            end
        end
    end
end

-- ----------------------------------------------------------------
-- UNIT_SPELLCAST_SUCCEEDED: fallback for spells with no aura
-- ----------------------------------------------------------------

function AuraEngine:OnSpellCast(spellID)
    local defs = self._castMap[spellID]
    if not defs then return end

    local now = GetTime()
    for _, def in ipairs(defs) do
        local t = MR.db and MR.db.profile.trackers[def.id]
        if not (t and t.enabled == false) then
            local existing = self.state[def.spellID]
            local duration = def.duration or 0
            self.state[def.spellID] = {
                name           = def.name,
                icon           = self:GetSpellIcon(def.spellID),
                stacks         = existing and existing.stacks or 1,
                duration       = duration,
                expirationTime = duration > 0 and (now + duration) or 0,
                isActive       = true,
            }
        end
    end
end

-- ----------------------------------------------------------------
-- State accessors
-- ----------------------------------------------------------------

function AuraEngine:Reset()
    self.state        = {}
    self._instanceMap = {}
end

function AuraEngine:ClearUnitDebuffs(auraType)
    for spellID in pairs(self.state) do
        local def = self._spellIDMap[spellID]
        if def and def.auraType == auraType then
            self.state[spellID] = nil
        end
    end
    -- Also purge instance map entries for this aura type
    local unit = UNIT_FILTER[auraType] and UNIT_FILTER[auraType].unit
    if unit then
        for instanceID, info in pairs(self._instanceMap) do
            if info.unit == unit then
                self._instanceMap[instanceID] = nil
            end
        end
    end
end

function AuraEngine:GetDefBySpellID(spellID)
    return self._spellIDMap[spellID]
end

function AuraEngine:GetPlayerBuff(spellID)
    local data = self.state[spellID]
    if not data then return nil end
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
