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

-- Called once at init. Checks IsPlayerSpell for each talent modifier and
-- overwrites duration/cooldown on the def in-place.
function AuraEngine:ResolveTalents(trackerList)
    for _, def in ipairs(trackerList) do
        -- snapshot base values on first call so re-runs don't compound
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
        -- restore castID as a fresh copy so castIDAdd doesn't compound
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

-- Called by Core.lua after the active tracker is loaded
function AuraEngine:BuildCastMap(trackerList)
    self._castMap = {}
    local function register(cid, def)
        if not self._castMap[cid] then
            self._castMap[cid] = {}
        end
        table.insert(self._castMap[cid], def)
    end
    for _, def in ipairs(trackerList) do
        if type(def.castID) == "table" then
            for _, cid in ipairs(def.castID) do
                register(cid, def)
            end
        else
            register(def.castID or def.spellID, def)
        end
    end
end

-- Called by Core.lua on UNIT_SPELLCAST_SUCCEEDED for "player"
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

-- Clear all aura state (on entering world or leaving combat)
function AuraEngine:Reset()
    self.state = {}
end

-- Clear debuffs of a given auraType (on target/focus change)
function AuraEngine:ClearUnitDebuffs(auraType)
    for spellID in pairs(self.state) do
        local def = self:GetDefBySpellID(spellID)
        if def and def.auraType == auraType then
            self.state[spellID] = nil
        end
    end
end


function AuraEngine:GetDefBySpellID(spellID)
    for _, defs in pairs(self._castMap) do
        for _, def in ipairs(defs) do
            if def.spellID == spellID then return def end
        end
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
