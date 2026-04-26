require("tests.mocks.wow_api")
require("tests.mocks.addon_env")
require("Animations")

local lu = require("luaunit")

TestAnimations = {}

local function make_bar(flashBelow)
    return {
        flashBelow = flashBelow,
        _flashing  = false,
        _alpha     = 1.0,
        SetAlpha   = function(self, a) self._alpha = a end,
    }
end

function TestAnimations:test_no_flash_when_above_threshold()
    local bar = make_bar(5)
    MR.Animations:UpdateFlash(bar, 10)
    lu.assertFalse(bar._flashing)
    lu.assertEquals(1.0, bar._alpha)
end

function TestAnimations:test_no_flash_when_threshold_not_set()
    local bar = make_bar(nil)
    MR.Animations:UpdateFlash(bar, 2)
    lu.assertFalse(bar._flashing)
end

function TestAnimations:test_flashes_when_below_threshold()
    local bar = make_bar(5)
    MR.Animations:UpdateFlash(bar, 4)
    lu.assertTrue(bar._flashing)
end

function TestAnimations:test_alpha_in_range_when_flashing()
    local bar = make_bar(5)
    MR.Animations:UpdateFlash(bar, 3)
    lu.assertTrue(bar._alpha >= 0.3 and bar._alpha <= 1.0,
        "alpha out of range: " .. tostring(bar._alpha))
end

function TestAnimations:test_alpha_resets_when_leaving_flash_range()
    local bar = make_bar(5)
    bar._flashing = true
    MR.Animations:UpdateFlash(bar, 10)
    lu.assertEquals(1.0, bar._alpha)
    lu.assertFalse(bar._flashing)
end

function TestAnimations:test_flashes_at_exact_threshold_boundary()
    local bar = make_bar(5)
    -- remaining == threshold: 5 > 5 is false, so flash should activate
    MR.Animations:UpdateFlash(bar, 5)
    lu.assertTrue(bar._flashing)
end

-- Runner calls lu.LuaUnit.run() — do not call os.exit here
