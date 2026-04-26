require("tests.mocks.wow_api")
require("tests.mocks.addon_env")
require("AuraEngine")
require("Animations")
require("BarRenderer")

local lu = require("luaunit")

-- Helpers
local function make_tracker(overrides)
    local t = {
        id           = "test_buff",
        name         = "Test Buff",
        spellID      = 12345,
        auraType     = "player_buff",
        group        = "cooldowns",
        priority     = 50,
        showDuration = true,
        showStacks   = false,
        color        = { r=1, g=0, b=0, a=1 },
    }
    if overrides then for k,v in pairs(overrides) do t[k]=v end end
    return t
end

-- GetTime mock returns 1000.0, so expirationTime=1010 → 10s remaining
local function make_aura(overrides)
    local a = {
        name           = "Test Buff",
        icon           = 12345,
        stacks         = 0,
        duration       = 10.0,
        expirationTime = 1010.0,
        isActive       = true,
    }
    if overrides then for k,v in pairs(overrides) do a[k]=v end end
    return a
end

-- ─── Acquire / Release ────────────────────────────────────────────────────────

TestBarRendererPool = {}

function TestBarRendererPool:test_acquire_returns_frame()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    lu.assertIsTable(bar)
    lu.assertIsTable(bar.statusbar)
    lu.assertIsTable(bar.icon)
end

function TestBarRendererPool:test_release_then_acquire_reuses_same_frame()
    local parent = CreateFrame("Frame")
    local bar1 = MR.BarRenderer:AcquireBar(parent)
    MR.BarRenderer:ReleaseBar(bar1)
    local bar2 = MR.BarRenderer:AcquireBar(parent)
    lu.assertEquals(bar1, bar2)
end

function TestBarRendererPool:test_release_clears_tracker_id()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    bar.trackerID = "some_buff"
    MR.BarRenderer:ReleaseBar(bar)
    lu.assertNil(bar.trackerID)
end

-- ─── ConfigureBar ─────────────────────────────────────────────────────────────

TestBarRendererConfigure = {}

function TestBarRendererConfigure:test_sets_color_from_tracker_def()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    MR.BarRenderer:ConfigureBar(bar, make_tracker({color={r=0.5,g=0.2,b=0.8,a=1}}), make_aura(), nil)
    lu.assertEquals(0.5, bar.statusbar._color.r)
    lu.assertEquals(0.2, bar.statusbar._color.g)
    lu.assertEquals(0.8, bar.statusbar._color.b)
end

function TestBarRendererConfigure:test_user_color_overrides_tracker_default()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    MR.BarRenderer:ConfigureBar(bar, make_tracker({color={r=1,g=0,b=0,a=1}}),
        make_aura(), {color={r=0,g=1,b=0,a=1}})
    lu.assertEquals(0, bar.statusbar._color.r)
    lu.assertEquals(1, bar.statusbar._color.g)
end

function TestBarRendererConfigure:test_stores_duration_data_on_bar()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    MR.BarRenderer:ConfigureBar(bar, make_tracker(), make_aura(), nil)
    lu.assertEquals("test_buff", bar.trackerID)
    lu.assertEquals(10.0,        bar.duration)
    lu.assertEquals(1010.0,      bar.endTime)
end

function TestBarRendererConfigure:test_shows_stacks_when_stacks_gt_1()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    MR.BarRenderer:ConfigureBar(bar, make_tracker({showStacks=true}), make_aura({stacks=5}), nil)
    lu.assertEquals("5", bar.stackText._text)
end

function TestBarRendererConfigure:test_hides_stack_text_when_stacks_le_1()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    MR.BarRenderer:ConfigureBar(bar, make_tracker({showStacks=true}), make_aura({stacks=1}), nil)
    lu.assertFalse(bar.stackText._shown)
end

-- ─── UpdateBar ────────────────────────────────────────────────────────────────

TestBarRendererUpdate = {}

function TestBarRendererUpdate:test_fill_ratio_is_correct()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    -- 5s remaining out of 10s total
    MR.BarRenderer:ConfigureBar(bar, make_tracker(), make_aura({duration=10, expirationTime=1005}), nil)
    MR.BarRenderer:UpdateBar(bar)
    lu.assertAlmostEquals(0.5, bar.statusbar._value, 0.01)
end

function TestBarRendererUpdate:test_marks_expired_when_past_end_time()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    MR.BarRenderer:ConfigureBar(bar, make_tracker(), make_aura({duration=10, expirationTime=999}), nil)
    MR.BarRenderer:UpdateBar(bar)
    lu.assertTrue(bar.expired)
end

function TestBarRendererUpdate:test_time_text_shows_minutes_when_over_60s()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    -- 120s remaining (expiry at 1120, GetTime=1000)
    MR.BarRenderer:ConfigureBar(bar, make_tracker(), make_aura({duration=300, expirationTime=1120}), nil)
    MR.BarRenderer:UpdateBar(bar)
    lu.assertEquals("2m", bar.timeText._text)
end

function TestBarRendererUpdate:test_time_text_shows_decimal_seconds_under_60s()
    local bar = MR.BarRenderer:AcquireBar(CreateFrame("Frame"))
    MR.BarRenderer:ConfigureBar(bar, make_tracker(), make_aura({duration=10, expirationTime=1007.5}), nil)
    MR.BarRenderer:UpdateBar(bar)
    lu.assertEquals("7.5", bar.timeText._text)
end

-- Runner calls lu.LuaUnit.run() — do not call os.exit here
