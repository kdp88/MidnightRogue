require("tests.mocks.wow_api")
require("tests.mocks.addon_env")
require("AuraEngine")
require("Defaults")
require("Core")

local lu = require("luaunit")

-- Capture the real RefreshDisplay immediately after Core.lua loads.
-- Other test files (test_options.lua) replace it with a no-op stub via
-- restoreStubs(); we restore it in setUp so test_core tests exercise real logic.
local _realRefreshDisplay = MR.RefreshDisplay

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function make_tracker(id, auraType, group)
    return {
        id       = id,
        name     = id,
        spellID  = 1,
        castID   = 1,
        duration = 10,
        group    = group or "buffs",
        auraType = auraType or "player_buff",
        priority = 90,
        color    = { r=1, g=0, b=0, a=1 },
    }
end

-- ─── TestRefreshDisplayPreview ───────────────────────────────────────────────

TestRefreshDisplayPreview = {}

function TestRefreshDisplayPreview:setUp()
    self._configureBarCalls = {}
    self._acquireBarCalls   = 0

    -- Stubs scoped to this test — saved originals restored in tearDown
    self._origRefreshDisplay = MR.RefreshDisplay
    self._origBarGroup       = MR.BarGroup
    self._origBarRenderer    = MR.BarRenderer
    self._origSettingsUI     = MR.SettingsUI
    self._origProfiles       = MR.Profiles
    self._origSpecDetect     = MR.SpecDetection

    MR.RefreshDisplay = _realRefreshDisplay

    local calls = self._configureBarCalls
    local self_ = self

    MR.BarGroup = {
        GetOrCreate = function(s, name, cfg)
            return { _groupName = name, _bars = {}, _width = (cfg and cfg.width) or 220 }
        end,
        ClearAll  = function() end,
        AddBar    = function() end,
        SetLocked = function() end,
        SetWidth  = function() end,
    }
    MR.BarRenderer = {
        AcquireBar   = function() self_._acquireBarCalls = self_._acquireBarCalls + 1; return {} end,
        ConfigureBar = function(s, bar, def, aura, settings)
            table.insert(calls, { def = def, aura = aura })
        end,
        ReleaseBar   = function() end,
    }
    MR.SettingsUI  = { Rebuild = function() end, Open = function() end }
    MR.Profiles    = { ApplySpecProfile = function() end }
end

function TestRefreshDisplayPreview:tearDown()
    MR.RefreshDisplay = self._origRefreshDisplay
    MR.BarGroup       = self._origBarGroup
    MR.BarRenderer    = self._origBarRenderer
    MR.SettingsUI     = self._origSettingsUI
    MR.Profiles       = self._origProfiles
    MR.SpecDetection  = self._origSpecDetect
end

local function boot(trackerList, locked)
    MR.SpecDetection = {
        LoadTrackerForCurrentSpec = function() return trackerList, "Subtlety" end
    }
    MR.addon:OnInitialize()
    if locked ~= nil then MR.db.profile.locked = locked end
    MR.AuraEngine:Reset()
    MR.addon:PLAYER_ENTERING_WORLD()
end

function TestRefreshDisplayPreview:test_unlocked_shows_all_enabled_trackers()
    boot({ make_tracker("symbols_of_death") }, false)
    lu.assertEquals(1, #self._configureBarCalls)
end

function TestRefreshDisplayPreview:test_unlocked_passes_preview_aura()
    boot({ make_tracker("symbols_of_death") }, false)
    local aura = self._configureBarCalls[1].aura
    lu.assertTrue(aura.isActive)
    lu.assertEquals(0, aura.stacks)
    lu.assertEquals(0, aura.duration)
    lu.assertEquals(0, aura.expirationTime)
end

function TestRefreshDisplayPreview:test_unlocked_shows_bars_even_with_no_active_aura()
    boot({ make_tracker("symbols_of_death") }, false)
    lu.assertEquals(1, self._acquireBarCalls)
end

function TestRefreshDisplayPreview:test_locked_shows_no_bars_when_no_active_aura()
    boot({ make_tracker("symbols_of_death") }, true)
    lu.assertEquals(0, self._acquireBarCalls)
end

function TestRefreshDisplayPreview:test_unlocked_respects_tracker_enabled_false()
    boot({ make_tracker("symbols_of_death") }, false)
    MR.db.profile.trackers["symbols_of_death"] = { enabled = false }
    self._configureBarCalls = {}
    self._acquireBarCalls   = 0
    MR:RefreshDisplay()
    lu.assertEquals(0, self._acquireBarCalls)
end

function TestRefreshDisplayPreview:test_unlocked_respects_group_enabled_false()
    boot({ make_tracker("symbols_of_death") }, false)
    MR.db.profile.groups["buffs"] = MR.db.profile.groups["buffs"] or {}
    MR.db.profile.groups["buffs"].enabled = false
    self._configureBarCalls = {}
    self._acquireBarCalls   = 0
    MR:RefreshDisplay()
    lu.assertEquals(0, self._acquireBarCalls)
end

function TestRefreshDisplayPreview:test_preview_aura_not_mutated_across_multiple_trackers()
    boot({ make_tracker("alpha"), make_tracker("beta") }, false)
    lu.assertEquals(2, #self._configureBarCalls)
    local a1 = self._configureBarCalls[1].aura
    local a2 = self._configureBarCalls[2].aura
    lu.assertEquals(0, a1.stacks)
    lu.assertEquals(0, a2.stacks)
    lu.assertEquals(0, a1.expirationTime)
    lu.assertEquals(0, a2.expirationTime)
    lu.assertTrue(a1.isActive)
    lu.assertTrue(a2.isActive)
end

function TestRefreshDisplayPreview:test_trigger_only_tracker_never_renders_a_bar()
    local trigger = make_tracker("find_weakness_backstab")
    trigger.triggerOnly = true
    local display = make_tracker("find_weakness")
    -- Both share spellID; only display def should produce a bar
    boot({ display, trigger }, false)
    lu.assertEquals(1, #self._configureBarCalls)
    lu.assertEquals("find_weakness", self._configureBarCalls[1].def.id)
end

-- Runner calls lu.LuaUnit.run() — do not call os.exit here
