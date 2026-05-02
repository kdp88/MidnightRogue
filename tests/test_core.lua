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

-- ─── OnChatCommand: probe ────────────────────────────────────────────────────

TestChatCommandProbe = {}

function TestChatCommandProbe:setUp()
    self._printed = {}
    MR.addon.Print = function(_, msg) table.insert(self._printed, msg) end
    MR.SettingsUI  = MR.SettingsUI or { Open = function() end }

    -- Minimal API surface the probe exercises
    _G.UnitPower    = function(unit, powerType) return 3 end
    _G.UnitPowerMax = function(unit, powerType) return 5 end
    _G.Enum         = { PowerType = { ComboPoints = 4, Energy = 3 } }
    _G.UnitBuff     = function() return nil end
end

function TestChatCommandProbe:tearDown()
    _G.UnitPower    = nil
    _G.UnitPowerMax = nil
    _G.Enum         = nil
    _G.UnitBuff     = nil
end

function TestChatCommandProbe:test_probe_does_not_error()
    local ok, err = pcall(function() MR.addon:OnChatCommand("probe") end)
    lu.assertTrue(ok, "probe command should not throw: " .. tostring(err))
end

function TestChatCommandProbe:test_probe_prints_output()
    MR.addon:OnChatCommand("probe")
    lu.assertTrue(#self._printed > 0, "probe should print at least one line")
end

function TestChatCommandProbe:test_probe_survives_missing_apis()
    _G.UnitPower    = nil
    _G.UnitPowerMax = nil
    _G.Enum         = nil
    _G.UnitBuff     = nil
    local ok, err = pcall(function() MR.addon:OnChatCommand("probe") end)
    lu.assertTrue(ok, "probe should handle missing APIs gracefully: " .. tostring(err))
end

function TestChatCommandProbe:test_probe_survives_secret_return_value()
    -- Simulate a Midnight "secret" value that errors on tostring
    _G.UnitPower = function() return setmetatable({}, {
        __tostring = function() error("invalid value (secret)") end
    }) end
    local ok, err = pcall(function() MR.addon:OnChatCommand("probe") end)
    lu.assertTrue(ok, "probe should handle secret tostring: " .. tostring(err))
end

function TestChatCommandProbe:test_probe_survives_secret_string_in_format()
    -- Simulate tostring succeeding but returning a secret string that errors in string.format
    local secretStr = setmetatable({}, {
        __tostring = function() return setmetatable({}, {
            __concat = function() error("invalid value (secret) at index 2 in table for 'concat'") end,
        }) end
    })
    _G.UnitPower = function() return secretStr end
    local ok, err = pcall(function() MR.addon:OnChatCommand("probe") end)
    lu.assertTrue(ok, "probe should handle secret string in format: " .. tostring(err))
end

function TestChatCommandProbe:test_probe_reports_unit_power()
    MR.addon:OnChatCommand("probe")
    local found = false
    for _, line in ipairs(self._printed) do
        if line:find("ComboPoints") or line:find("combo") or line:find("power") then
            found = true; break
        end
    end
    lu.assertTrue(found, "probe should report combo point / power info")
end

function TestChatCommandProbe:test_probe_covers_all_power_types()
    _G.Enum = { PowerType = { ComboPoints = 4, Energy = 3, Mana = 0, Rage = 1, Focus = 2 } }
    MR.addon:OnChatCommand("probe")
    local found = false
    for _, line in ipairs(self._printed) do
        if line:find("PowerType") then found = true; break end
    end
    lu.assertTrue(found, "probe should iterate power types")
end

function TestChatCommandProbe:test_probe_tests_get_spell_count()
    _G.GetSpellCount = function(id) return 0 end
    MR.addon:OnChatCommand("probe")
    local found = false
    for _, line in ipairs(self._printed) do
        if line:find("SpellCount") or line:find("196912") then found = true; break end
    end
    lu.assertTrue(found, "probe should test GetSpellCount for Shadow Techniques")
end

function TestChatCommandProbe:test_probe_tests_unit_aura_legacy()
    _G.UnitAura = function() return nil end
    MR.addon:OnChatCommand("probe")
    local found = false
    for _, line in ipairs(self._printed) do
        if line:find("UnitAura") then found = true; break end
    end
    lu.assertTrue(found, "probe should test UnitAura legacy API")
end

-- ─── /mr probe2 ──────────────────────────────────────────────────────────────

TestChatCommandProbe2 = {}

function TestChatCommandProbe2:setUp()
    self._printed = {}
    MR.addon.Print = function(_, msg) table.insert(self._printed, msg) end
    MR.SettingsUI  = MR.SettingsUI or { Open = function() end }
    MR._probe2Active = false
end

function TestChatCommandProbe2:tearDown()
    MR._probe2Active = false
end

function TestChatCommandProbe2:test_probe2_does_not_error()
    local ok, err = pcall(function() MR.addon:OnChatCommand("probe2") end)
    lu.assertTrue(ok, "probe2 should not throw: " .. tostring(err))
end

function TestChatCommandProbe2:test_probe2_enables_logging()
    MR.addon:OnChatCommand("probe2")
    lu.assertTrue(MR._probe2Active)
end

function TestChatCommandProbe2:test_probe2_toggles_off()
    MR._probe2Active = true
    MR.addon:OnChatCommand("probe2")
    lu.assertFalse(MR._probe2Active)
end

function TestChatCommandProbe2:test_probe2_prints_status_on()
    MR.addon:OnChatCommand("probe2")
    local found = false
    for _, line in ipairs(self._printed) do
        if line:find("ON") or line:find("on") or line:find("enabled") then found = true; break end
    end
    lu.assertTrue(found, "probe2 should print enabled status")
end

function TestChatCommandProbe2:test_probe2_prints_status_off()
    MR._probe2Active = true
    MR.addon:OnChatCommand("probe2")
    local found = false
    for _, line in ipairs(self._printed) do
        if line:find("OFF") or line:find("off") or line:find("disabled") then found = true; break end
    end
    lu.assertTrue(found, "probe2 should print disabled status")
end

function TestChatCommandProbe2:test_spell_cast_logs_when_probe2_active()
    MR._probe2Active = true
    MR.AuraEngine:BuildCastMap({})
    MR.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", nil, 6603)
    local found = false
    for _, line in ipairs(self._printed) do
        if line:find("6603") then found = true; break end
    end
    lu.assertTrue(found, "active probe2 should log spell ID to chat")
end

function TestChatCommandProbe2:test_spell_cast_does_not_log_when_probe2_inactive()
    MR._probe2Active = false
    MR.AuraEngine:BuildCastMap({})
    MR.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", nil, 6603)
    local found = false
    for _, line in ipairs(self._printed) do
        if line:find("6603") then found = true; break end
    end
    lu.assertFalse(found, "inactive probe2 should not log spell IDs")
end

-- Runner calls lu.LuaUnit.run() — do not call os.exit here
