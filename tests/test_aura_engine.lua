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

function TestAuraEngineTalents:test_cast_id_add_appends_when_talent_learned()
    _G.IsPlayerSpell = function(id) return id == 319949 end
    local list = {
        {
            id = "find_weakness", name = "Find Weakness", spellID = 91021,
            castID = { 1833, 185438 }, duration = 10,
            talents = { { spellID = 319949, castIDAdd = 53 } },
            group = "debuffs", auraType = "target_debuff",
            priority = 60, color = { r=0.5, g=0.5, b=0.5, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(3, #list[1].castID)
    lu.assertEquals(53, list[1].castID[3])
end

function TestAuraEngineTalents:test_cast_id_add_skipped_when_talent_not_learned()
    _G.IsPlayerSpell = function(id) return false end
    local list = {
        {
            id = "find_weakness", name = "Find Weakness", spellID = 91021,
            castID = { 1833, 185438 }, duration = 10,
            talents = { { spellID = 319949, castIDAdd = 53 } },
            group = "debuffs", auraType = "target_debuff",
            priority = 60, color = { r=0.5, g=0.5, b=0.5, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(2, #list[1].castID)
end

function TestAuraEngineTalents:test_cast_id_add_does_not_compound_on_repeated_resolve()
    _G.IsPlayerSpell = function(id) return id == 319949 end
    local list = {
        {
            id = "find_weakness", name = "Find Weakness", spellID = 91021,
            castID = { 1833, 185438 }, duration = 10,
            talents = { { spellID = 319949, castIDAdd = 53 } },
            group = "debuffs", auraType = "target_debuff",
            priority = 60, color = { r=0.5, g=0.5, b=0.5, a=1 },
        }
    }
    MR.AuraEngine:ResolveTalents(list)
    MR.AuraEngine:ResolveTalents(list)
    MR.AuraEngine:ResolveTalents(list)
    lu.assertEquals(3, #list[1].castID)  -- not 5 or 7
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

function TestAuraEngineOnSpellCast:test_disabled_tracker_skips_state()
    MR.db = { profile = { trackers = { symbols_of_death = { enabled = false } } } }
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertNil(MR.AuraEngine.state[212283])
    MR.db = nil
end

function TestAuraEngineOnSpellCast:test_enabled_tracker_still_writes_state()
    MR.db = { profile = { trackers = { symbols_of_death = { enabled = true } } } }
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertNotNil(MR.AuraEngine.state[212283])
    MR.db = nil
end

function TestAuraEngineOnSpellCast:test_missing_db_entry_defaults_to_enabled()
    -- trackers table exists but no entry for this tracker — should still fire
    MR.db = { profile = { trackers = {} } }
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertNotNil(MR.AuraEngine.state[212283])
    MR.db = nil
end

function TestAuraEngineOnSpellCast:test_nil_db_defaults_to_enabled()
    MR.db = nil
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertNotNil(MR.AuraEngine.state[212283])
end

function TestAuraEngineOnSpellCast:test_disabled_does_not_affect_other_trackers()
    -- disabling rupture should not block symbols_of_death on the same cast event
    MR.db = { profile = { trackers = { rupture = { enabled = false } } } }
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertNotNil(MR.AuraEngine.state[212283])
    MR.db = nil
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

-- ─── BuildCastMap: _spellIDMap ───────────────────────────────────────────────

TestAuraEngineSpellIDMap = {}

function TestAuraEngineSpellIDMap:setUp()
    MR.AuraEngine:Reset()
end

function TestAuraEngineSpellIDMap:test_spell_id_map_keyed_by_spell_id()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    lu.assertNotNil(MR.AuraEngine._spellIDMap[212283])
    lu.assertEquals("symbols_of_death", MR.AuraEngine._spellIDMap[212283].id)
end

function TestAuraEngineSpellIDMap:test_spell_id_map_uses_spell_id_not_cast_id()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    -- shadow_dance: castID=185313, spellID=185422
    lu.assertNotNil(MR.AuraEngine._spellIDMap[185422])
    lu.assertNil(MR.AuraEngine._spellIDMap[185313])
end

function TestAuraEngineSpellIDMap:test_trigger_only_excluded_from_spell_id_map()
    local list = {
        {
            id = "find_weakness", name = "Find Weakness",
            spellID = 91021, castID = { 1833, 185438 }, duration = 10,
            auraType = "target_debuff", group = "debuffs", priority = 60,
            color = { r=0.5, g=0.5, b=0.5, a=1 },
        },
        {
            id = "find_weakness_backstab", name = "Find Weakness (Backstab)",
            spellID = 91021, castID = 53, duration = 10,
            auraType = "target_debuff", group = "debuffs", priority = 57,
            color = { r=0.5, g=0.5, b=0.5, a=1 },
            triggerOnly = true,
        },
    }
    MR.AuraEngine:BuildCastMap(list)
    -- spellID 91021 should be in the map (from find_weakness, not the triggerOnly sibling)
    lu.assertNotNil(MR.AuraEngine._spellIDMap[91021])
    lu.assertEquals("find_weakness", MR.AuraEngine._spellIDMap[91021].id)
end

function TestAuraEngineSpellIDMap:test_spell_id_map_cleared_on_rebuild()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    MR.AuraEngine:BuildCastMap({})
    lu.assertNil(MR.AuraEngine._spellIDMap[212283])
end

-- ─── OnUnitAura ──────────────────────────────────────────────────────────────

TestAuraEngineOnUnitAura = {}

function TestAuraEngineOnUnitAura:setUp()
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
    -- Reset C_UnitAuras to empty
    _G.C_UnitAuras.GetAuraDataByIndex = function() return nil end
    _G.C_UnitAuras.GetAuraDataByAuraInstanceID = function() return nil end
end

local function makeAuraData(spellId, opts)
    opts = opts or {}
    return {
        spellId        = spellId,
        name           = opts.name or "TestAura",
        icon           = opts.icon or 12345,
        applications   = opts.applications or 0,
        duration       = opts.duration or 10,
        expirationTime = opts.expirationTime or 1010.0,
        auraInstanceID = opts.auraInstanceID or 1,
    }
end

-- Midnight restriction: auraData where all fields except spellId throw on access
local function makeRestrictedAuraData(spellId, instanceID)
    local t = {}
    setmetatable(t, {
        __index = function(_, k)
            if k == "spellId" then return spellId end
            if k == "auraInstanceID" then return instanceID end
            error("attempted to index a table that cannot be indexed with secret keys")
        end
    })
    return t
end

function TestAuraEngineOnUnitAura:test_full_update_nil_scans_unit()
    -- Set up GetAuraDataByIndex to return one aura then nil
    local called = false
    _G.C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        if index == 1 and unit == "player" then
            called = true
            return makeAuraData(212283, { expirationTime = 1035.0, duration = 35 })
        end
        return nil
    end
    MR.AuraEngine:OnUnitAura("player", nil)
    lu.assertTrue(called)
    lu.assertNotNil(MR.AuraEngine.state[212283])
end

function TestAuraEngineOnUnitAura:test_full_update_flag_scans_unit()
    _G.C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        if index == 1 then return makeAuraData(212283) end
        return nil
    end
    MR.AuraEngine:OnUnitAura("player", { isFullUpdate = true })
    lu.assertNotNil(MR.AuraEngine.state[212283])
end

function TestAuraEngineOnUnitAura:test_full_update_clears_stale_state()
    -- Pre-populate state via cast, then do a full scan that returns nothing
    MR.AuraEngine:OnSpellCast(212283)
    lu.assertNotNil(MR.AuraEngine.state[212283])
    MR.AuraEngine:OnUnitAura("player", nil)
    lu.assertNil(MR.AuraEngine.state[212283])
end

function TestAuraEngineOnUnitAura:test_added_auras_populates_state()
    local updateInfo = {
        addedAuras = { makeAuraData(212283, { expirationTime = 1035.0, duration = 35 }) },
    }
    MR.AuraEngine:OnUnitAura("player", updateInfo)
    lu.assertNotNil(MR.AuraEngine.state[212283])
    lu.assertTrue(MR.AuraEngine.state[212283].isActive)
end

function TestAuraEngineOnUnitAura:test_added_auras_reads_expiration_time()
    local updateInfo = {
        addedAuras = { makeAuraData(212283, { expirationTime = 1042.0, duration = 35 }) },
    }
    MR.AuraEngine:OnUnitAura("player", updateInfo)
    lu.assertAlmostEquals(1042.0, MR.AuraEngine.state[212283].expirationTime, 0.01)
end

function TestAuraEngineOnUnitAura:test_added_auras_reads_stack_count()
    local list = {{
        id = "shadow_techniques", name = "Shadow Techniques",
        spellID = 196912, castID = 196912, duration = 0,
        auraType = "player_buff", group = "procs", priority = 82,
        color = { r=0.3, g=0.3, b=0.9, a=1 },
    }}
    MR.AuraEngine:BuildCastMap(list)
    local updateInfo = {
        addedAuras = { makeAuraData(196912, { applications = 7, duration = 0, expirationTime = 0 }) },
    }
    MR.AuraEngine:OnUnitAura("player", updateInfo)
    lu.assertEquals(7, MR.AuraEngine.state[196912].stacks)
end

function TestAuraEngineOnUnitAura:test_updated_instance_refreshes_state()
    -- First add via addedAuras
    MR.AuraEngine:OnUnitAura("player", {
        addedAuras = { makeAuraData(212283, { expirationTime = 1035.0, auraInstanceID = 42 }) },
    })
    -- Now update via updatedAuraInstanceIDs
    _G.C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, id)
        if id == 42 then
            return makeAuraData(212283, { expirationTime = 1050.0, auraInstanceID = 42 })
        end
    end
    MR.AuraEngine:OnUnitAura("player", { updatedAuraInstanceIDs = { 42 } })
    lu.assertAlmostEquals(1050.0, MR.AuraEngine.state[212283].expirationTime, 0.01)
end

function TestAuraEngineOnUnitAura:test_removed_instance_clears_state()
    MR.AuraEngine:OnUnitAura("player", {
        addedAuras = { makeAuraData(212283, { auraInstanceID = 99 }) },
    })
    lu.assertNotNil(MR.AuraEngine.state[212283])
    MR.AuraEngine:OnUnitAura("player", { removedAuraInstanceIDs = { 99 } })
    lu.assertNil(MR.AuraEngine.state[212283])
end

function TestAuraEngineOnUnitAura:test_unknown_unit_is_ignored()
    -- Should not error or write state
    MR.AuraEngine:OnUnitAura("nameplate1", nil)
    lu.assertEquals(0, (function()
        local n = 0; for _ in pairs(MR.AuraEngine.state) do n = n + 1 end; return n
    end)())
end

function TestAuraEngineOnUnitAura:test_wrong_unit_type_aura_ignored()
    -- target_debuff aura arriving on unit="player" should be ignored
    local updateInfo = {
        addedAuras = { makeAuraData(1943, { expirationTime = 1024.0 }) },  -- rupture: target_debuff
    }
    MR.AuraEngine:OnUnitAura("player", updateInfo)
    lu.assertNil(MR.AuraEngine.state[1943])
end

function TestAuraEngineOnUnitAura:test_unknown_spell_id_is_ignored()
    local updateInfo = {
        addedAuras = { makeAuraData(99999) },
    }
    MR.AuraEngine:OnUnitAura("player", updateInfo)
    lu.assertNil(MR.AuraEngine.state[99999])
end

-- ─── Midnight restricted auraData (secret keys) ──────────────────────────────

TestAuraEngineRestrictedAura = {}

function TestAuraEngineRestrictedAura:setUp()
    MR.AuraEngine:Reset()
    MR.AuraEngine:BuildCastMap(make_tracker_list())
end

function TestAuraEngineRestrictedAura:test_restricted_aura_does_not_error()
    -- Midnight blocks ALL field access including spellId
    local fullyRestricted = setmetatable({}, {
        __index = function(_, k)
            error("attempted to index a table that cannot be indexed with secret keys")
        end
    })
    local ok, err = pcall(function()
        MR.AuraEngine:OnUnitAura("player", { addedAuras = { fullyRestricted } })
    end)
    lu.assertTrue(ok, "should not throw: " .. tostring(err))
end

function TestAuraEngineRestrictedAura:test_secret_spell_id_used_as_table_key_does_not_error()
    -- safeRead succeeds but returns a secret value that errors when used as a table key
    local secretValue = setmetatable({}, {
        __tostring = function() return "secret" end,
    })
    local sneakyAura = setmetatable({}, {
        __index = function(_, k)
            if k == "spellId" then return secretValue end
            error("secret key")
        end
    })
    -- Indexing _spellIDMap with secretValue should not propagate an error
    local ok, err = pcall(function()
        MR.AuraEngine:OnUnitAura("player", { addedAuras = { sneakyAura } })
    end)
    lu.assertTrue(ok, "secret spellId used as key should not throw: " .. tostring(err))
end

function TestAuraEngineRestrictedAura:test_restricted_aura_still_marks_active()
    local restricted = makeRestrictedAuraData(212283, nil)
    MR.AuraEngine:OnUnitAura("player", { addedAuras = { restricted } })
    local state = MR.AuraEngine.state[212283]
    lu.assertNotNil(state)
    lu.assertTrue(state.isActive)
end

function TestAuraEngineRestrictedAura:test_restricted_aura_falls_back_to_def_duration()
    -- When expirationTime is unreadable, falls back to def.duration (35s from t=1000)
    local restricted = makeRestrictedAuraData(212283, nil)
    MR.AuraEngine:OnUnitAura("player", { addedAuras = { restricted } })
    local state = MR.AuraEngine.state[212283]
    lu.assertAlmostEquals(1035.0, state.expirationTime, 0.01)
end

function TestAuraEngineRestrictedAura:test_restricted_aura_stacks_default_zero()
    local restricted = makeRestrictedAuraData(212283, nil)
    MR.AuraEngine:OnUnitAura("player", { addedAuras = { restricted } })
    lu.assertEquals(0, MR.AuraEngine.state[212283].stacks)
end

function TestAuraEngineRestrictedAura:test_restricted_aura_no_instance_id_skips_instance_map()
    local restricted = makeRestrictedAuraData(212283, nil)
    MR.AuraEngine:OnUnitAura("player", { addedAuras = { restricted } })
    -- _instanceMap should be empty since instanceID was nil
    local count = 0
    for _ in pairs(MR.AuraEngine._instanceMap) do count = count + 1 end
    lu.assertEquals(0, count)
end

-- ─── Reset clears _instanceMap ───────────────────────────────────────────────

function TestAuraEngineReset:test_reset_clears_instance_map()
    MR.AuraEngine:OnUnitAura("player", {
        addedAuras = { makeAuraData(212283, { auraInstanceID = 7 }) },
    })
    MR.AuraEngine:Reset()
    local count = 0
    for _ in pairs(MR.AuraEngine._instanceMap) do count = count + 1 end
    lu.assertEquals(0, count)
end

-- ─── ClearUnitDebuffs clears _instanceMap ────────────────────────────────────

function TestAuraEngineClearUnitDebuffs:test_clears_instance_map_for_unit()
    MR.AuraEngine:OnUnitAura("target", {
        addedAuras = { makeAuraData(1943, { auraInstanceID = 55 }) },
    })
    MR.AuraEngine:ClearUnitDebuffs("target_debuff")
    lu.assertNil(MR.AuraEngine._instanceMap[55])
end

function TestAuraEngineClearUnitDebuffs:test_keeps_instance_map_for_other_unit()
    MR.AuraEngine:OnUnitAura("player", {
        addedAuras = { makeAuraData(212283, { auraInstanceID = 11 }) },
    })
    MR.AuraEngine:ClearUnitDebuffs("target_debuff")
    lu.assertNotNil(MR.AuraEngine._instanceMap[11])
end

-- Runner calls lu.LuaUnit.run() — do not call os.exit here
