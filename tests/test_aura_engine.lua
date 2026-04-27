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
            group    = "buffs",
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
            group    = "buffs",
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
            group    = "debuffs",
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
            group    = "buffs",
            auraType = "player_buff",
            priority = 100,
            color    = { r=0.4, g=0.4, b=0.8, a=1 },
        },
    }
end

-- ─── ResolveTalents ──────────────────────────────────────────────────────────

TestAuraEngineTalents = {}

function TestAuraEngineTalents:setUp()
    MR.AuraEngine:Reset()
    _G.GetHaste = function() return 0 end
end

function TestAuraEngineTalents:test_talent_overrides_cooldown_when_learned()
    _G.IsPlayerSpell = function(id) return id == 231691 end
    local list = {
        {
            id = "sprint", name = "Sprint", spellID = 2983, castID = 2983,
            duration = 12, cooldown = 120,
            talents = { { spellID = 231691, cooldown = 60 } },
            group = "cooldowns", auraType = "player_buff",
            priority = 85, color = { r=0.8, g=0.8, b=0, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(60, list[1].cooldown)
    lu.assertEquals(12, list[1].duration)  -- duration unchanged
end

function TestAuraEngineTalents:test_talent_does_not_override_when_not_learned()
    _G.IsPlayerSpell = function(id) return false end
    local list = {
        {
            id = "sprint", name = "Sprint", spellID = 2983, castID = 2983,
            duration = 12, cooldown = 120,
            talents = { { spellID = 231691, cooldown = 60 } },
            group = "cooldowns", auraType = "player_buff",
            priority = 85, color = { r=0.8, g=0.8, b=0, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(120, list[1].cooldown)
end

function TestAuraEngineTalents:test_talent_overrides_duration_when_learned()
    _G.IsPlayerSpell = function(id) return id == 99999 end
    local list = {
        {
            id = "test", name = "Test", spellID = 111, castID = 111,
            duration = 8, cooldown = 30,
            talents = { { spellID = 99999, duration = 12 } },
            group = "cooldowns", auraType = "player_buff",
            priority = 50, color = { r=1, g=0, b=0, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(12, list[1].duration)
end

function TestAuraEngineTalents:test_duration_add_increments_duration()
    _G.IsPlayerSpell = function(id) return id == 193531 end
    local list = {
        {
            id = "slice_and_dice", name = "Slice and Dice", spellID = 315496, castID = 315496,
            duration = 42,
            talents = {
                { spellID = 193531, durationAdd = 6 },
                { spellID = 394320, durationAdd = 6 },
            },
            group = "cooldowns", auraType = "player_buff",
            priority = 87, color = { r=0, g=0.8, b=0.3, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(48, list[1].duration)  -- base 42 + one talent's 6
end

function TestAuraEngineTalents:test_duration_add_both_talents_stack()
    _G.IsPlayerSpell = function(id) return id == 193531 or id == 394320 end
    local list = {
        {
            id = "slice_and_dice", name = "Slice and Dice", spellID = 315496, castID = 315496,
            duration = 42,
            talents = {
                { spellID = 193531, durationAdd = 6 },
                { spellID = 394320, durationAdd = 6 },
            },
            group = "cooldowns", auraType = "player_buff",
            priority = 87, color = { r=0, g=0.8, b=0.3, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(54, list[1].duration)  -- base 42 + 6 + 6
end

function TestAuraEngineTalents:test_haste_scales_duration_no_talents()
    _G.IsPlayerSpell = function(id) return false end
    _G.GetHaste = function() return 19.0 end
    local list = {
        {
            id = "secret_technique", name = "Secret Technique", spellID = 280719, castID = 280719,
            duration = 25, hasteScales = true,
            talents = { { spellID = 441274, durationMult = 0.90 } },
            group = "cooldowns", auraType = "player_buff",
            priority = 91, color = { r=0.4, g=0, b=0.9, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    -- 25 / 1.19 = 21.008...
    lu.assertAlmostEquals(25 / 1.19, list[1].duration, 0.01)
    _G.GetHaste = function() return 0 end
end

function TestAuraEngineTalents:test_haste_scales_after_talent_mult()
    _G.IsPlayerSpell = function(id) return id == 441274 end
    _G.GetHaste = function() return 19.0 end
    local list = {
        {
            id = "secret_technique", name = "Secret Technique", spellID = 280719, castID = 280719,
            duration = 25, hasteScales = true,
            talents = { { spellID = 441274, durationMult = 0.90 } },
            group = "cooldowns", auraType = "player_buff",
            priority = 91, color = { r=0.4, g=0, b=0.9, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    -- 25 * 0.90 / 1.19 = 22.5 / 1.19 ≈ 18.908
    lu.assertAlmostEquals(22.5 / 1.19, list[1].duration, 0.01)
    _G.GetHaste = function() return 0 end
end

function TestAuraEngineTalents:test_haste_scales_zero_haste_unchanged()
    _G.IsPlayerSpell = function(id) return false end
    _G.GetHaste = function() return 0 end
    local list = {
        {
            id = "secret_technique", name = "Secret Technique", spellID = 280719, castID = 280719,
            duration = 25, hasteScales = true, talents = {},
            group = "cooldowns", auraType = "player_buff",
            priority = 91, color = { r=0.4, g=0, b=0.9, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    lu.assertAlmostEquals(25.0, list[1].duration, 0.01)
end

function TestAuraEngineTalents:test_repeated_resolve_does_not_compound_duration_add()
    _G.IsPlayerSpell = function(id) return id == 193531 end
    _G.GetHaste = function() return 0 end
    local list = {
        {
            id = "slice_and_dice", name = "Slice and Dice", spellID = 315496, castID = 315496,
            duration = 42,
            talents = { { spellID = 193531, durationAdd = 6 } },
            group = "cooldowns", auraType = "player_buff",
            priority = 87, color = { r=0, g=0.8, b=0.3, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    MR.AuraEngine:ResolveTalents(list)
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(48, list[1].duration)  -- 42+6, not 42+6+6+6
end

function TestAuraEngineTalents:test_repeated_resolve_does_not_compound_haste()
    _G.IsPlayerSpell = function(id) return id == 441274 end
    _G.GetHaste = function() return 19.0 end
    local list = {
        {
            id = "secret_technique", name = "Secret Technique", spellID = 280719, castID = 280719,
            duration = 25, hasteScales = true,
            talents = { { spellID = 441274, durationMult = 0.90 } },
            group = "cooldowns", auraType = "player_buff",
            priority = 91, color = { r=0.4, g=0, b=0.9, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    MR.AuraEngine:ResolveTalents(list)
    MR.AuraEngine:ResolveTalents(list)
    lu.assertAlmostEquals(22.5 / 1.19, list[1].duration, 0.01)  -- not compounded
end

function TestAuraEngineTalents:test_no_talents_field_is_safe()
    _G.IsPlayerSpell = function(id) return false end
    local list = {
        {
            id = "test", name = "Test", spellID = 111, castID = 111,
            duration = 8, group = "cooldowns", auraType = "player_buff",
            priority = 50, color = { r=1, g=0, b=0, a=1 },
        }
    }
    -- should not error
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(8, list[1].duration)
end

TestAuraEngineCastMap = {}

function TestAuraEngineCastMap:setUp()
    MR.AuraEngine:Reset()
end

function TestAuraEngineCastMap:test_build_cast_map_indexes_by_cast_id()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    lu.assertNotNil(MR.AuraEngine._castMap[212283])
    lu.assertEquals("symbols_of_death", MR.AuraEngine._castMap[212283][1].id)
end

function TestAuraEngineCastMap:test_build_cast_map_uses_cast_id_not_spell_id()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    lu.assertNotNil(MR.AuraEngine._castMap[185313])
    lu.assertNil(MR.AuraEngine._castMap[185422])
    lu.assertEquals("shadow_dance", MR.AuraEngine._castMap[185313][1].id)
end

function TestAuraEngineCastMap:test_build_cast_map_replaces_previous_map()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    MR.AuraEngine:BuildCastMap({})
    lu.assertNil(MR.AuraEngine._castMap[212283])
end

function TestAuraEngineCastMap:test_build_cast_map_handles_array_cast_id()
    local list = {
        {
            id = "find_weakness", name = "Find Weakness",
            spellID = 91021, castID = { 1833, 8676 },
            duration = 10, group = "debuffs", auraType = "target_debuff",
            priority = 60, color = { r=0.5, g=0.5, b=0.5, a=1 },
        }
    }
    MR.AuraEngine:BuildCastMap(list)
    lu.assertNotNil(MR.AuraEngine._castMap[1833])
    lu.assertNotNil(MR.AuraEngine._castMap[8676])
    lu.assertEquals("find_weakness", MR.AuraEngine._castMap[1833][1].id)
    lu.assertEquals("find_weakness", MR.AuraEngine._castMap[8676][1].id)
end

function TestAuraEngineCastMap:test_shared_cast_id_triggers_multiple_trackers()
    -- Cheap Shot (1833) should trigger both cheap_shot and find_weakness
    local list = {
        {
            id = "cheap_shot", name = "Cheap Shot",
            spellID = 1833, castID = 1833,
            duration = 4, group = "debuffs", auraType = "target_debuff",
            priority = 62, color = { r=1, g=0.6, b=0, a=1 },
        },
        {
            id = "find_weakness", name = "Find Weakness",
            spellID = 91021, castID = { 1833, 8676 },
            duration = 10, group = "debuffs", auraType = "target_debuff",
            priority = 60, color = { r=0.5, g=0.5, b=0.5, a=1 },
        }
    }
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(list)
    MR.AuraEngine:OnSpellCast(1833)
    lu.assertNotNil(MR.AuraEngine.state[1833],  "cheap_shot bar should appear")
    lu.assertNotNil(MR.AuraEngine.state[91021], "find_weakness bar should appear")
end

function TestAuraEngineCastMap:test_array_cast_id_triggers_correct_spell_id()
    local list = {
        {
            id = "find_weakness", name = "Find Weakness",
            spellID = 91021, castID = { 1833, 8676 },
            duration = 10, group = "debuffs", auraType = "target_debuff",
            priority = 60, color = { r=0.5, g=0.5, b=0.5, a=1 },
        }
    }
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(list)
    MR.AuraEngine:OnSpellCast(8676)
    lu.assertNotNil(MR.AuraEngine.state[91021])
    lu.assertEquals("Find Weakness", MR.AuraEngine.state[91021].name)
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

-- ─── Refresh behaviour ───────────────────────────────────────────────────────

TestAuraEngineRefresh = {}

function TestAuraEngineRefresh:setUp()
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
end

function TestAuraEngineRefresh:test_recast_resets_timer()
    MR.AuraEngine:OnSpellCast(212283)
    local old = _G.GetTime
    _G.GetTime = function() return 1020.0 end  -- 20s later, mid-duration
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertAlmostEquals(1055.0, MR.AuraEngine.state[212283].expirationTime, 0.01)
    _G.GetTime = old
end

function TestAuraEngineRefresh:test_recast_after_expiry_creates_new_entry()
    MR.AuraEngine:OnSpellCast(212283)
    local old = _G.GetTime
    _G.GetTime = function() return 2000.0 end
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertAlmostEquals(2035.0, MR.AuraEngine.state[212283].expirationTime, 0.01)
    _G.GetTime = old
end

function TestAuraEngineRefresh:test_permanent_aura_recast_keeps_entry()
    MR.AuraEngine:OnSpellCast(1784)
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


-- ─── ClearUnitDebuffs ────────────────────────────────────────────────────────

TestAuraEngineClearUnitDebuffs = {}

function TestAuraEngineClearUnitDebuffs:setUp()
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
end

function TestAuraEngineClearUnitDebuffs:test_clears_target_debuffs()
    MR.AuraEngine:OnSpellCast(1943)   -- rupture: target_debuff
    MR.AuraEngine:ClearUnitDebuffs("target_debuff")
    lu.assertNil(MR.AuraEngine.state[1943])
end

function TestAuraEngineClearUnitDebuffs:test_keeps_player_buffs()
    MR.AuraEngine:OnSpellCast(212283)  -- symbols_of_death: player_buff
    MR.AuraEngine:ClearUnitDebuffs("target_debuff")
    lu.assertNotNil(MR.AuraEngine.state[212283])
end

function TestAuraEngineClearUnitDebuffs:test_focus_debuff_does_not_clear_target_debuff()
    MR.AuraEngine:OnSpellCast(1943)   -- rupture: target_debuff
    MR.AuraEngine:ClearUnitDebuffs("focus_debuff")
    lu.assertNotNil(MR.AuraEngine.state[1943])
end

-- Runner calls lu.LuaUnit.run() — do not call os.exit here
