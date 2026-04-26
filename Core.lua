--[[
    Core.lua
    Addon entry point. Handles initialization, event routing, and display refresh.

    Event flow:
      ADDON_LOADED               → init DB, detect spec, load tracker, build config
      PLAYER_ENTERING_WORLD      → reset aura state, full refresh
      UNIT_SPELLCAST_SUCCEEDED   → player cast detected, update aura state
      PLAYER_TARGET_CHANGED      → refresh display
      PLAYER_FOCUS_CHANGED       → refresh display
      PLAYER_REGEN_DISABLED      → entered combat, clear permanent stealth bars
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

    self:RegisterChatCommand("mr", "OnChatCommand")

    local opts = MR.Options:Build(activeTracker)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("MidnightRogue", opts)

    MR.BarGroup:SetLocked(MR.db.profile.locked)
end

function addon:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
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
    MR.AuraEngine:Reset()
    MR:RefreshDisplay()
end

function addon:UNIT_SPELLCAST_SUCCEEDED(_, unitID, _, spellID)
    if unitID ~= "player" then return end
    MR.AuraEngine:OnSpellCast(spellID)
    MR:RefreshDisplay()
end

function addon:PLAYER_TARGET_CHANGED()
    MR:RefreshDisplay()
end

function addon:PLAYER_FOCUS_CHANGED()
    MR:RefreshDisplay()
end

function addon:PLAYER_REGEN_DISABLED()
    inCombat = true
    MR.AuraEngine:ClearStealthOnCombat()
    MR:RefreshDisplay()
end

function addon:PLAYER_REGEN_ENABLED()
    inCombat = false
    MR:RefreshDisplay()
end

-- ============================================================
-- Display Refresh
-- ============================================================

function MR:RefreshDisplay()
    if not activeTracker then return end

    MR.BarGroup:ClearAll()

    local groupCfg = MR.db.profile.groups

    for _, trackerDef in ipairs(activeTracker) do
        local groupName = trackerDef.group
        local groupEnabled = not groupCfg[groupName] or groupCfg[groupName].enabled
        if groupEnabled then
            local trackerSettings = MR.db.profile.trackers[trackerDef.id]
            local enabled = trackerSettings == nil and true or (trackerSettings.enabled ~= false)
            if enabled then
                local auraData
                if trackerDef.auraType == "player_buff" then
                    auraData = MR.AuraEngine:GetPlayerBuff(trackerDef.spellID)
                elseif trackerDef.auraType == "target_debuff" then
                    auraData = MR.AuraEngine:GetTargetDebuff("target", trackerDef.spellID)
                elseif trackerDef.auraType == "focus_debuff" then
                    auraData = MR.AuraEngine:GetTargetDebuff("focus", trackerDef.spellID)
                end

                if auraData and auraData.isActive then
                    local groupFrame = MR.BarGroup:GetOrCreate(groupName, groupCfg[groupName] or {})
                    local bar = MR.BarRenderer:AcquireBar(groupFrame)
                    MR.BarRenderer:ConfigureBar(bar, trackerDef, auraData, trackerSettings)
                    MR.BarGroup:AddBar(groupName, bar, trackerDef.priority)
                end
            end
        end
    end
end

-- ============================================================
-- Chat Commands
-- ============================================================

function addon:OnChatCommand(input)
    local cmd = string.lower(string.trim(input or ""))
    if cmd == "unlock" then
        MR.db.profile.locked = false
        MR.BarGroup:SetLocked(false)
        self:Print("Bar groups unlocked. Drag to reposition.")
    elseif cmd == "lock" then
        MR.db.profile.locked = true
        MR.BarGroup:SetLocked(true)
        self:Print("Bar groups locked.")
    elseif cmd == "reset" then
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
    else
        LibStub("AceConfigDialog-3.0"):Open("MidnightRogue")
    end
end
