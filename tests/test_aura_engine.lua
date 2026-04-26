require("tests.mocks.wow_api")
require("tests.mocks.addon_env")
require("AuraEngine")

local lu = require("luaunit")

-- Minimal tracker list for testing
local function make_tracker_list()
    return {
        {
            id       = "symbols_of_death",
            name     = "Symbols of Death",
            spellID  = 212283,
            castID   = 212283,
            duration = 35,
            group    = "cooldowns",
            auraType = "player_buff",
            priority = 90,
            color    = { r=1, g=0, b=0, a=1 },
        },
        {
            id       = "shadow_dance",
            name     = "Shadow Dance",
            spellID  = 185422,
            castID   = 185313,   -- cast ID differs from buff ID
            duration = 8,
            group    = "stealth",
            auraType = "player_buff",
            priority = 98,
            color    = { r=0.5, g=0, b=0.8, a=1 },
        },
        {
            id       = "rupture",
            name     = "Rupture",
            spellID  = 1943,
            castID   = 1943,
            duration = 24,
            group    = "dots",
            auraType = "target_debuff",
            priority = 70,
            color    = { r=0.9, g=0.1, b=0.1, a=1 },
        },
        {
            id       = "stealth_perm",
            name     = "Stealth",
            spellID  = 1784,
            castID   = 1784,
            duration = 0,        -- permanent
            group    = "stealth",
            auraType = "player_buff",
            priority = 100,
            color    = { r=0.4, g=0.4, b=0.8, a=1 },
        },
    }
end

TestAuraEngineCastMap = {}

function TestAuraEngineCastMap:setUp()
    MR.AuraEngine:Reset()
end

function TestAuraEngineCastMap:test_build_cast_map_indexes_by_cast_id()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    -- castID == spellID
    lu.assertNotNil(MR.AuraEngine._castMap[212283])
    lu.assertEquals("symbols_of_death", MR.AuraEngine._castMap[212283].id)
end

function TestAuraEngineCastMap:test_build_cast_map_uses_cast_id_not_spell_id()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    -- Shadow Dance: castID=185313, spellID=185422
    lu.assertNotNil(MR.AuraEngine._castMap[185313])
    lu.assertNil(MR.AuraEngine._castMap[185422])
    lu.assertEquals("shadow_dance", MR.AuraEngine._castMap[185313].id)
end

function TestAuraEngineCastMap:test_build_cast_map_replaces_previous_map()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    MR.AuraEngine:BuildCastMap({})
    lu.assertNil(MR.AuraEngine._castMap[212283])
end

-- ─── OnSpellCast ─────────────────────────────────────────────────────────────

TestAuraEngineOnSpellCast = {}

function TestAuraEngineOnSpellCast:setUp()
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
end

function TestAuraEngineOnSpellCast:test_cast_creates_state_entry()
    MR.AuraEngine:OnSpellCast(212283)
    local data = MR.AuraEngine.state[212283]
    lu.assertNotNil(data)
    lu.assertTrue(data.isActive)
    lu.assertEquals("Symbols of Death", data.name)
end

function TestAuraEngineOnSpellCast:test_cast_sets_correct_expiration()
    -- GetTime() returns 1000.0 in mock; duration=35 → expiration=1035
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertAlmostEquals(1035.0, MR.AuraEngine.state[212283].expirationTime, 0.01)
end

function TestAuraEngineOnSpellCast:test_permanent_aura_has_zero_expiration()
    MR.AuraEngine:OnSpellCast(1784)
    lu.assertEquals(0, MR.AuraEngine.state[1784].expirationTime)
end

function TestAuraEngineOnSpellCast:test_unknown_cast_id_does_nothing()
    MR.AuraEngine:OnSpellCast(99999)
    lu.assertEquals(0, (function()
        local n = 0
        for _ in pairs(MR.AuraEngine.state) do n = n + 1 end
        return n
    end)())
end

function TestAuraEngineOnSpellCast:test_cast_maps_cast_id_to_buff_spell_id()
    -- Shadow Dance: fire castID=185313, state should be keyed by spellID=185422
    MR.AuraEngine:OnSpellCast(185313)
    lu.assertNotNil(MR.AuraEngine.state[185422])
    lu.assertNil(MR.AuraEngine.state[185313])
end

-- ─── Guard: don't overwrite active aura ──────────────────────────────────────

TestAuraEngineGuard = {}

function TestAuraEngineGuard:setUp()
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
end

function TestAuraEngineGuard:test_spam_cast_does_not_reset_active_timer()
    MR.AuraEngine:OnSpellCast(212283)
    local first_expiry = MR.AuraEngine.state[212283].expirationTime
    MR.AuraEngine:OnSpellCast(212283)  -- spam
    lu.assertEquals(first_expiry, MR.AuraEngine.state[212283].expirationTime)
end

function TestAuraEngineGuard:test_recast_after_expiry_creates_new_entry()
    MR.AuraEngine:OnSpellCast(212283)
    -- Simulate time past expiry by temporarily overriding GetTime
    local old = _G.GetTime
    _G.GetTime = function() return 2000.0 end
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertAlmostEquals(2035.0, MR.AuraEngine.state[212283].expirationTime, 0.01)
    _G.GetTime = old
end

function TestAuraEngineGuard:test_permanent_aura_can_always_be_recast()
    MR.AuraEngine:OnSpellCast(1784)
    local first = MR.AuraEngine.state[1784]
    -- Permanent auras have expirationTime=0, guard should not block recast
    -- (they're cleared by ClearStealthOnCombat, not by expiry)
    MR.AuraEngine:OnSpellCast(1784)
    lu.assertNotNil(MR.AuraEngine.state[1784])
end

-- ─── GetPlayerBuff ───────────────────────────────────────────────────────────

TestAuraEngineGetPlayerBuff = {}

function TestAuraEngineGetPlayerBuff:setUp()
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
end

function TestAuraEngineGetPlayerBuff:test_returns_nil_when_no_state()
    lu.assertNil(MR.AuraEngine:GetPlayerBuff(212283))
end

function TestAuraEngineGetPlayerBuff:test_returns_data_for_active_aura()
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertNotNil(MR.AuraEngine:GetPlayerBuff(212283))
end

function TestAuraEngineGetPlayerBuff:test_returns_nil_and_clears_expired_aura()
    MR.AuraEngine:OnSpellCast(212283)
    -- Advance time past expiry
    local old = _G.GetTime
    _G.GetTime = function() return 2000.0 end
    lu.assertNil(MR.AuraEngine:GetPlayerBuff(212283))
    lu.assertNil(MR.AuraEngine.state[212283])
    _G.GetTime = old
end

function TestAuraEngineGetPlayerBuff:test_permanent_aura_never_expires()
    MR.AuraEngine:OnSpellCast(1784)
    local old = _G.GetTime
    _G.GetTime = function() return 9999999.0 end
    lu.assertNotNil(MR.AuraEngine:GetPlayerBuff(1784))
    _G.GetTime = old
end

-- ─── Reset / ClearStealthOnCombat ────────────────────────────────────────────

TestAuraEngineReset = {}

function TestAuraEngineReset:setUp()
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
end

function TestAuraEngineReset:test_reset_clears_all_state()
    MR.AuraEngine:OnSpellCast(212283)
    MR.AuraEngine:OnSpellCast(1784)
    MR.AuraEngine:Reset()
    lu.assertNil(MR.AuraEngine.state[212283])
    lu.assertNil(MR.AuraEngine.state[1784])
end

function TestAuraEngineReset:test_clear_stealth_removes_permanent_stealth_group()
    MR.AuraEngine:OnSpellCast(1784)   -- stealth group, duration=0
    MR.AuraEngine:ClearStealthOnCombat()
    lu.assertNil(MR.AuraEngine.state[1784])
end

function TestAuraEngineReset:test_clear_stealth_keeps_timed_stealth_group()
    MR.AuraEngine:OnSpellCast(185313)  -- shadow dance: stealth group, duration=8
    MR.AuraEngine:ClearStealthOnCombat()
    lu.assertNotNil(MR.AuraEngine.state[185422])
end

function TestAuraEngineReset:test_clear_stealth_keeps_non_stealth_auras()
    MR.AuraEngine:OnSpellCast(212283)  -- cooldowns group
    MR.AuraEngine:OnSpellCast(1943)    -- dots group
    MR.AuraEngine:ClearStealthOnCombat()
    lu.assertNotNil(MR.AuraEngine.state[212283])
    lu.assertNotNil(MR.AuraEngine.state[1943])
end

-- Runner calls lu.LuaUnit.run() — do not call os.exit here
