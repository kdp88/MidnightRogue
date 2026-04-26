--[[
    Core.lua
    Addon entry point. Handles initialization, event routing, and the main
    aura refresh loop.

    Event flow:
      ADDON_LOADED           → init DB, detect spec, load tracker, build groups, build config
      PLAYER_ENTERING_WORLD  → full aura refresh
      UNIT_AURA              → targeted aura refresh for player/target/focus
      PLAYER_TARGET_CHANGED  → refresh target debuffs
      PLAYER_FOCUS_CHANGED   → refresh focus debuffs
      PLAYER_REGEN_DISABLED  → entered combat
      PLAYER_REGEN_ENABLED   → left combat
--]]

local addonName, MR = ...

-- Ace3 addon object
local addon = LibStub("AceAddon-3.0"):NewAddon("MidnightRogue", "AceConsole-3.0", "AceEvent-3.0")
MR.addon   = addon

-- Active tracker definition list (set by SpecDetection on load)
local activeTracker = nil
local inCombat      = false

-- ============================================================
-- Initialization
-- ============================================================

function addon:OnInitialize()
    -- Set up SavedVariables with AceDB
    MR.db = LibStub("AceDB-3.0"):New("MidnightRogueDB", MR.Defaults, true)

    -- Detect spec and load the correct tracker definition
    local tracker, specName = MR.SpecDetection:LoadTrackerForCurrentSpec()
    activeTracker = tracker

    -- Switch to the spec's saved profile
    if specName then
        MR.Profiles:ApplySpecProfile(specName)
    end

    -- Build bar groups from profile settings
    if activeTracker then
        local groupsCfg = MR.db.profile.groups
        for groupName, settings in pairs(groupsCfg) do
            MR.BarGroup:GetOrCreate(groupName, settings)
        end
    end

    -- Register slash commands
    self:RegisterChatCommand("mr", "OnChatCommand")

    -- Build and register Ace config
    local opts = MR.Options:Build(activeTracker)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("MidnightRogue", opts)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MidnightRogue", "MidnightRogue")

    -- Apply lock state
    MR.BarGroup:SetLocked(MR.db.profile.locked)
end

function addon:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- ============================================================
-- Event Handlers
-- ============================================================

function addon:PLAYER_ENTERING_WORLD()
    MR:RefreshDisplay()
end

function addon:UNIT_AURA(_, unitID)
    if unitID == "player" or unitID == "target" or unitID == "focus" then
        MR:RefreshDisplay()
    end
end

function addon:PLAYER_TARGET_CHANGED()
    MR:RefreshDisplay()
end

function addon:PLAYER_FOCUS_CHANGED()
    MR:RefreshDisplay()
end

function addon:PLAYER_REGEN_DISABLED()
    inCombat = true
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
        -- Skip if group is disabled
        local groupName = trackerDef.group
        if groupCfg[groupName] and not groupCfg[groupName].enabled then
            goto continue
        end

        -- Check per-tracker enabled state
        local trackerSettings = MR.db.profile.trackers[trackerDef.id]
        local enabled = trackerSettings == nil and true or (trackerSettings.enabled ~= false)
        if not enabled then goto continue end

        -- Fetch live aura data from AuraEngine
        local auraData
        if trackerDef.auraType == "player_buff" then
            auraData = MR.AuraEngine:GetPlayerBuff(trackerDef.spellID)
        elseif trackerDef.auraType == "target_debuff" then
            auraData = MR.AuraEngine:GetTargetDebuff("target", trackerDef.spellID)
        elseif trackerDef.auraType == "focus_debuff" then
            auraData = MR.AuraEngine:GetTargetDebuff("focus", trackerDef.spellID)
        end

        if auraData and auraData.isActive then
            -- Acquire and configure a bar
            local groupFrame = MR.BarGroup:GetOrCreate(groupName, groupCfg[groupName] or {})
            local bar = MR.BarRenderer:AcquireBar(groupFrame)
            MR.BarRenderer:ConfigureBar(bar, trackerDef, auraData, trackerSettings)
            MR.BarGroup:AddBar(groupName, bar, trackerDef.priority)
        end

        ::continue::
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
        -- Reset all group positions to defaults
        for groupName, defaults in pairs(MR.Defaults.profile.groups) do
            MR.db.profile.groups[groupName].x = defaults.x
            MR.db.profile.groups[groupName].y = defaults.y
        end
        MR:RefreshDisplay()
        self:Print("Bar positions reset to defaults.")
    else
        LibStub("AceConfigDialog-3.0"):Open("MidnightRogue")
    end
end
