require("tests.mocks.wow_api")
require("tests.mocks.addon_env")
require("Defaults")
require("Options")

local lu = require("luaunit")

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function make_db(trackers, groups)
    return {
        profile = {
            locked   = true,
            trackers = trackers or {},
            groups   = groups or {
                buffs   = { enabled = true, width = 220, grow = "UP" },
                procs   = { enabled = true, width = 220, grow = "UP" },
                debuffs = { enabled = true, width = 220, grow = "UP" },
            },
        },
    }
end

local function make_tracker(id, name, group, priority)
    return {
        id = id, name = name, group = group, priority = priority,
        spellID = 1, castID = 1, duration = 10,
        auraType = "player_buff", color = { r=1, g=0, b=0, a=1 },
    }
end

-- Stub MR.Profiles and MR:RefreshDisplay for options tests.
-- Re-applied in each setUp because test_core.lua loads Core.lua which overwrites these.
MR.Profiles = { GetCurrentProfileName = function() return "Subtlety" end }
MR.RefreshDisplay = function() end
MR.BarGroup = { SetLocked = function() end, SetWidth = function() end, ClearAll = function() end }

local function restoreStubs()
    MR.RefreshDisplay = function() end
    MR.BarGroup = { SetLocked = function() end, SetWidth = function() end, ClearAll = function() end }
end

-- ─── TestOptionsBuild ────────────────────────────────────────────────────────

TestOptionsBuild = {}

function TestOptionsBuild:setUp()
    restoreStubs()
    MR.db = make_db()
end

function TestOptionsBuild:test_build_returns_group_type()
    local opts = MR.Options:Build({})
    lu.assertEquals("group", opts.type)
end

function TestOptionsBuild:test_build_with_nil_does_not_crash()
    local opts = MR.Options:Build(nil)
    lu.assertNotNil(opts)
    lu.assertEquals("group", opts.type)
end

function TestOptionsBuild:test_build_with_nil_still_has_all_panels()
    local opts = MR.Options:Build(nil)
    lu.assertNotNil(opts.args.general)
    lu.assertNotNil(opts.args.buffs)
    lu.assertNotNil(opts.args.procs)
    lu.assertNotNil(opts.args.debuffs)
end

function TestOptionsBuild:test_build_creates_buffs_procs_debuffs_panels()
    local opts = MR.Options:Build({})
    lu.assertNotNil(opts.args.buffs)
    lu.assertNotNil(opts.args.procs)
    lu.assertNotNil(opts.args.debuffs)
end

function TestOptionsBuild:test_build_creates_general_panel()
    local opts = MR.Options:Build({})
    lu.assertNotNil(opts.args.general)
end

function TestOptionsBuild:test_tracker_appears_in_correct_group_panel()
    local list = {
        make_tracker("rupture", "Rupture", "debuffs", 70),
        make_tracker("symbols", "Symbols of Death", "buffs", 90),
    }
    local opts = MR.Options:Build(list)
    lu.assertNotNil(opts.args.debuffs.args.tracker_rupture)
    lu.assertNotNil(opts.args.buffs.args.tracker_symbols)
    lu.assertNil(opts.args.buffs.args.tracker_rupture)
end

function TestOptionsBuild:test_tracker_not_in_wrong_group()
    local list = { make_tracker("rupture", "Rupture", "debuffs", 70) }
    local opts = MR.Options:Build(list)
    lu.assertNil(opts.args.procs.args.tracker_rupture)
end

-- ─── TestTrackerToggle ───────────────────────────────────────────────────────

TestTrackerToggle = {}

function TestTrackerToggle:setUp()
    restoreStubs()
    MR.db = make_db()
end

function TestTrackerToggle:test_tracker_defaults_to_enabled_when_not_in_db()
    local list = { make_tracker("rupture", "Rupture", "debuffs", 70) }
    local opts = MR.Options:Build(list)
    local getter = opts.args.debuffs.args.tracker_rupture.get
    lu.assertTrue(getter())
end

function TestTrackerToggle:test_tracker_respects_enabled_false()
    MR.db = make_db({ rupture = { enabled = false } })
    local list = { make_tracker("rupture", "Rupture", "debuffs", 70) }
    local opts = MR.Options:Build(list)
    local getter = opts.args.debuffs.args.tracker_rupture.get
    lu.assertFalse(getter())
end

function TestTrackerToggle:test_tracker_respects_enabled_true_explicitly()
    MR.db = make_db({ rupture = { enabled = true } })
    local list = { make_tracker("rupture", "Rupture", "debuffs", 70) }
    local opts = MR.Options:Build(list)
    local getter = opts.args.debuffs.args.tracker_rupture.get
    lu.assertTrue(getter())
end

function TestTrackerToggle:test_tracker_setter_writes_to_db()
    local list = { make_tracker("rupture", "Rupture", "debuffs", 70) }
    local opts = MR.Options:Build(list)
    local setter = opts.args.debuffs.args.tracker_rupture.set
    setter(nil, false)
    lu.assertFalse(MR.db.profile.trackers.rupture.enabled)
end

function TestTrackerToggle:test_tracker_setter_creates_db_entry_if_missing()
    local list = { make_tracker("rupture", "Rupture", "debuffs", 70) }
    local opts = MR.Options:Build(list)
    lu.assertNil(MR.db.profile.trackers.rupture)
    opts.args.debuffs.args.tracker_rupture.set(nil, false)
    lu.assertNotNil(MR.db.profile.trackers.rupture)
end

-- ─── TestGroupToggle ─────────────────────────────────────────────────────────

TestGroupToggle = {}

function TestGroupToggle:setUp()
    restoreStubs()
    MR.db = make_db()
end

function TestGroupToggle:test_group_defaults_to_enabled()
    local opts = MR.Options:Build({})
    local getter = opts.args.buffs.args.groupEnabled.get
    lu.assertTrue(getter())
end

function TestGroupToggle:test_group_respects_enabled_false()
    MR.db = make_db({}, {
        buffs   = { enabled = false, width = 220, grow = "UP" },
        procs   = { enabled = true,  width = 220, grow = "UP" },
        debuffs = { enabled = true,  width = 220, grow = "UP" },
    })
    local opts = MR.Options:Build({})
    local getter = opts.args.buffs.args.groupEnabled.get
    lu.assertFalse(getter())
end

function TestGroupToggle:test_group_setter_writes_to_db()
    local opts = MR.Options:Build({})
    opts.args.buffs.args.groupEnabled.set(nil, false)
    lu.assertFalse(MR.db.profile.groups.buffs.enabled)
end

-- ─── TestTrackerOrder ────────────────────────────────────────────────────────

TestTrackerOrder = {}

function TestTrackerOrder:setUp()
    restoreStubs()
    MR.db = make_db()
end

function TestTrackerOrder:test_higher_priority_tracker_has_lower_order_number()
    local list = {
        make_tracker("low",  "Low",  "buffs", 70),
        make_tracker("high", "High", "buffs", 90),
    }
    local opts = MR.Options:Build(list)
    lu.assertTrue(opts.args.buffs.args.tracker_high.order < opts.args.buffs.args.tracker_low.order)
end

-- ─── TestLockDefaults ────────────────────────────────────────────────────────
-- Lock state lives in db.profile.locked; the SettingsUI toggle reads and
-- writes it. These tests verify the defaults and db contract the toggle relies on.

TestLockDefaults = {}

function TestLockDefaults:test_default_locked_is_true()
    lu.assertEquals(true, MR.Defaults.profile.locked)
end

function TestLockDefaults:test_db_locked_true_means_bars_are_locked()
    MR.db = make_db()
    MR.db.profile.locked = true
    lu.assertTrue(MR.db.profile.locked ~= false)
end

function TestLockDefaults:test_db_locked_false_means_bars_are_unlocked()
    MR.db = make_db()
    MR.db.profile.locked = false
    lu.assertFalse(MR.db.profile.locked ~= false)
end

function TestLockDefaults:test_toggling_locked_calls_bar_group_set_locked()
    local calls = {}
    MR.BarGroup.SetLocked = function(self, val) table.insert(calls, val) end

    MR.db = make_db()
    MR.db.profile.locked = true

    -- Simulate what the SettingsUI toggle button does
    local nowLocked = not (MR.db.profile.locked ~= false)
    MR.db.profile.locked = nowLocked
    MR.BarGroup:SetLocked(nowLocked)

    lu.assertEquals(1, #calls)
    lu.assertFalse(calls[1])  -- toggled from locked→unlocked

    -- Restore stub
    MR.BarGroup.SetLocked = function() end
end

function TestLockDefaults:test_toggling_twice_returns_to_locked()
    MR.db = make_db()
    MR.db.profile.locked = true

    -- First toggle: unlock
    local nowLocked = not (MR.db.profile.locked ~= false)
    MR.db.profile.locked = nowLocked
    lu.assertFalse(MR.db.profile.locked)

    -- Second toggle: lock again
    nowLocked = not (MR.db.profile.locked ~= false)
    MR.db.profile.locked = nowLocked
    lu.assertTrue(MR.db.profile.locked)
end

-- Runner calls lu.LuaUnit.run() — do not call os.exit here
