--[[
    Core.lua
    Addon entry point. Handles initialization, event routing, and display refresh.

    Event flow:
      ADDON_LOADED               → init DB, detect spec, load tracker, build config
      PLAYER_ENTERING_WORLD      → reset aura state, full scan, refresh
      UNIT_AURA                  → live aura add/update/remove via C_UnitAuras (primary)
      UNIT_SPELLCAST_SUCCEEDED   → fallback for spells that produce no aura
      PLAYER_TARGET_CHANGED      → full aura rescan on target, refresh display
      PLAYER_FOCUS_CHANGED       → full aura rescan on focus, refresh display
      PLAYER_REGEN_DISABLED      → entered combat, refresh display
      PLAYER_REGEN_ENABLED       → left combat, reset all aura state
--]]

local addonName, MR = ...

local addon = LibStub("AceAddon-3.0"):NewAddon("MidnightRogue", "AceConsole-3.0", "AceEvent-3.0")
MR.addon = addon

local activeTracker = nil
local inCombat      = false

-- ============================================================
-- Initialization
-- ============================================================

function addon:OnInitialize()
    MR.db = LibStub("AceDB-3.0"):New("MidnightRogueDB", MR.Defaults, true)

    self:RegisterChatCommand("mr", "OnChatCommand")
    MR.BarGroup:SetLocked(MR.db.profile.locked)
end

-- Deferred init: called in PLAYER_ENTERING_WORLD so player APIs
-- (IsPlayerSpell, UnitHaste, GetSpecialization) are available.
local function InitTracker()
    local tracker, specName = MR.SpecDetection:LoadTrackerForCurrentSpec()
    activeTracker = tracker

    if specName then
        MR.Profiles:ApplySpecProfile(specName)
    end

    if activeTracker then
        MR.AuraEngine:ResolveTalents(activeTracker)
        MR.AuraEngine:BuildCastMap(activeTracker)
        local groupsCfg = MR.db.profile.groups
        for groupName, settings in pairs(groupsCfg) do
            MR.BarGroup:GetOrCreate(groupName, settings)
        end
    end

    MR.SettingsUI:Rebuild(activeTracker)
end

function addon:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- ============================================================
-- Event Handlers
-- ============================================================

function addon:PLAYER_ENTERING_WORLD()
    InitTracker()
    MR.AuraEngine:Reset()
    MR.AuraEngine:OnUnitAura("player", nil)
    MR.AuraEngine:OnUnitAura("target", nil)
    MR.AuraEngine:OnUnitAura("focus",  nil)
    MR:RefreshDisplay()
end

function addon:UNIT_AURA(_, unit, updateInfo)
    if unit ~= "player" and unit ~= "target" and unit ~= "focus" then return end
    MR.AuraEngine:OnUnitAura(unit, updateInfo)
    MR:RefreshDisplay()
end

function addon:UNIT_SPELLCAST_SUCCEEDED(_, unitID, _, spellID)
    if unitID ~= "player" then return end
    if MR._probe2Active then
        self:Print("CAST spellID=" .. tostring(spellID))
    end
    MR.AuraEngine:OnSpellCast(spellID)
    MR:RefreshDisplay()
end

function addon:PLAYER_TARGET_CHANGED()
    MR.AuraEngine:OnUnitAura("target", nil)
    MR:RefreshDisplay()
end

function addon:PLAYER_FOCUS_CHANGED()
    MR.AuraEngine:OnUnitAura("focus", nil)
    MR:RefreshDisplay()
end

function addon:PLAYER_REGEN_DISABLED()
    inCombat = true
    MR:RefreshDisplay()
end

function addon:PLAYER_REGEN_ENABLED()
    inCombat = false
    MR:RefreshDisplay()
end

-- ============================================================
-- Display Refresh
-- ============================================================

local PREVIEW_AURA = { isActive = true, stacks = 0, duration = 0, expirationTime = 0 }

function MR:RefreshDisplay()
    if not activeTracker then return end

    MR.BarGroup:ClearAll()

    local groupCfg = MR.db.profile.groups
    local unlocked  = MR.db.profile.locked == false

    for _, trackerDef in ipairs(activeTracker) do
        if not trackerDef.triggerOnly then
        local groupName = trackerDef.group
        local groupEnabled = not groupCfg[groupName] or groupCfg[groupName].enabled
        if groupEnabled then
            local trackerSettings = MR.db.profile.trackers[trackerDef.id]
            local enabled = trackerSettings == nil and true or (trackerSettings.enabled ~= false)
            if enabled then
                local auraData
                if unlocked then
                    auraData = PREVIEW_AURA
                elseif trackerDef.auraType == "player_buff" then
                    auraData = MR.AuraEngine:GetPlayerBuff(trackerDef.spellID)
                elseif trackerDef.auraType == "target_debuff" then
                    auraData = MR.AuraEngine:GetTargetDebuff("target", trackerDef.spellID)
                elseif trackerDef.auraType == "focus_debuff" then
                    auraData = MR.AuraEngine:GetTargetDebuff("focus", trackerDef.spellID)
                end

                if auraData and auraData.isActive then
                    local groupFrame = MR.BarGroup:GetOrCreate(groupName, groupCfg[groupName] or {})
                    local bar = MR.BarRenderer:AcquireBar(groupFrame)
                    local barH = groupCfg[groupName] and groupCfg[groupName].height or 24
                    MR.BarRenderer:ConfigureBar(bar, trackerDef, auraData, trackerSettings, barH)
                    MR.BarGroup:AddBar(groupName, bar, trackerDef.priority)
                end
            end
        end
        end  -- triggerOnly guard
    end
end

-- ============================================================
-- Chat Commands
-- ============================================================

function addon:OnChatCommand(input)
    local cmd = string.lower(string.trim(input or ""))
    if cmd == "reset" then
        for groupName, defaults in pairs(MR.Defaults.profile.groups) do
            MR.db.profile.groups[groupName].x = defaults.x
            MR.db.profile.groups[groupName].y = defaults.y
        end
        MR:RefreshDisplay()
        self:Print("Bar positions reset to defaults.")
    elseif cmd == "debug" then
        self:Print("=== AuraEngine State ===")
        local count = 0
        for spellID, data in pairs(MR.AuraEngine.state) do
            local remaining = data.expirationTime > 0 and string.format("%.1fs", data.expirationTime - GetTime()) or "permanent"
            self:Print(string.format("  spellID=%d  name=%s  remaining=%s", spellID, tostring(data.name), remaining))
            count = count + 1
        end
        if count == 0 then self:Print("  (empty)") end
        self:Print("=== CastMap Keys ===")
        local mapCount = 0
        for castID, defs in pairs(MR.AuraEngine._castMap) do
            local names = {}
            for _, def in ipairs(defs) do table.insert(names, def.id) end
            self:Print(string.format("  castID=%d -> %s", castID, table.concat(names, ", ")))
            mapCount = mapCount + 1
        end
        if mapCount == 0 then self:Print("  (empty — BuildCastMap may not have run)") end
    elseif cmd == "probe" then
        self:Print("=== API Probe ===")

        local function try(label, fn)
            local ok, result = pcall(fn)
            if ok then
                local ok2 = pcall(function()
                    self:Print(string.format("  [OK] %s = %s", label, tostring(result)))
                end)
                if not ok2 then
                    self:Print("  [OK] " .. label .. " = <secret value>")
                end
            else
                self:Print("  [BLOCKED] " .. label)
            end
        end

        -- All known power types
        self:Print("-- Power types --")
        if Enum and Enum.PowerType then
            for name, id in pairs(Enum.PowerType) do
                try("PowerType." .. name .. " UnitPower", function()
                    return UnitPower("player", id)
                end)
                try("PowerType." .. name .. " UnitPowerMax", function()
                    return UnitPowerMax("player", id)
                end)
            end
        else
            self:Print("  [BLOCKED] Enum.PowerType")
        end

        -- Shadow Techniques specific queries
        self:Print("-- Shadow Techniques (196912) --")
        try("UnitBuff legacy", function()
            return UnitBuff("player", 196912) or "nil"
        end)
        try("UnitAura legacy", function()
            return UnitAura("player", 196912) or "nil"
        end)
        try("C_UnitAuras.GetPlayerAuraBySpellID", function()
            local data = C_UnitAuras.GetPlayerAuraBySpellID(196912)
            return data and "returned table" or "nil"
        end)
        try("GetSpellCount 196912", function()
            return GetSpellCount(196912)
        end)
        try("AuraUtil.ForEachAura (count)", function()
            local count = 0
            AuraUtil.ForEachAura("player", "HELPFUL", nil, function(a)
                count = count + 1
            end)
            return count
        end)

        -- Auto-attack detection
        self:Print("-- Auto-attack --")
        try("GetSpellInfo 6603 (Attack)", function()
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(6603)
                return info and info.name or "nil"
            end
            return GetSpellInfo(6603) or "nil"
        end)

        self:Print("=== End Probe (use /mr probe2 to log all spell casts) ===")

    elseif cmd == "probe2" then
        MR._probe2Active = not MR._probe2Active
        if MR._probe2Active then
            self:Print("Spell cast logging ON — cast spells and check chat. /mr probe2 to stop.")
        else
            self:Print("Spell cast logging OFF.")
        end
    else
        MR.SettingsUI:Open()
    end
end
