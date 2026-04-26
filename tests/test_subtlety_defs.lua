require("tests.mocks.wow_api")
require("tests.mocks.addon_env")
require("Subtlety")

local lu = require("luaunit")

TestSubtletyDefs = {}

function TestSubtletyDefs:setUp()
    self.defs = MR.Trackers["Subtlety"]
end

function TestSubtletyDefs:test_tracker_table_loads()
    lu.assertIsTable(self.defs)
    lu.assertTrue(#self.defs > 0)
end

function TestSubtletyDefs:test_unique_ids()
    local seen = {}
    for _, def in ipairs(self.defs) do
        lu.assertIsString(def.id)
        lu.assertNil(seen[def.id], "duplicate id: " .. def.id)
        seen[def.id] = true
    end
end

function TestSubtletyDefs:test_required_fields_present()
    local required = { "id", "name", "spellID", "castID", "duration", "auraType", "group", "priority", "color" }
    for _, def in ipairs(self.defs) do
        for _, field in ipairs(required) do
            lu.assertNotNil(def[field], def.id .. " missing field: " .. field)
        end
    end
end

function TestSubtletyDefs:test_cast_ids_are_positive_integers()
    for _, def in ipairs(self.defs) do
        lu.assertIsNumber(def.castID, def.id .. " castID must be a number")
        lu.assertTrue(def.castID > 0, def.id .. " castID must be > 0")
        lu.assertEquals(math.floor(def.castID), def.castID, def.id .. " castID must be integer")
    end
end

function TestSubtletyDefs:test_durations_are_non_negative()
    for _, def in ipairs(self.defs) do
        lu.assertIsNumber(def.duration, def.id .. " duration must be a number")
        lu.assertTrue(def.duration >= 0, def.id .. " duration must be >= 0")
    end
end

function TestSubtletyDefs:test_spell_ids_are_positive_integers()
    for _, def in ipairs(self.defs) do
        lu.assertIsNumber(def.spellID)
        lu.assertTrue(def.spellID > 0, def.id .. " spellID must be > 0")
        lu.assertEquals(math.floor(def.spellID), def.spellID, def.id .. " spellID must be integer")
    end
end

function TestSubtletyDefs:test_aura_types_are_valid()
    local valid = { player_buff=true, target_debuff=true, focus_debuff=true }
    for _, def in ipairs(self.defs) do
        lu.assertNotNil(valid[def.auraType], def.id .. " unknown auraType: " .. tostring(def.auraType))
    end
end

function TestSubtletyDefs:test_groups_are_valid()
    local valid = { stealth=true, cooldowns=true, procs=true, dots=true, debuffs=true }
    for _, def in ipairs(self.defs) do
        lu.assertNotNil(valid[def.group], def.id .. " unknown group: " .. tostring(def.group))
    end
end

function TestSubtletyDefs:test_colors_are_valid_rgba()
    for _, def in ipairs(self.defs) do
        local c = def.color
        for _, ch in ipairs({"r","g","b","a"}) do
            lu.assertIsNumber(c[ch], def.id .. " color." .. ch .. " missing")
            lu.assertTrue(c[ch] >= 0 and c[ch] <= 1, def.id .. " color." .. ch .. " out of range: " .. tostring(c[ch]))
        end
    end
end

function TestSubtletyDefs:test_priorities_are_positive()
    for _, def in ipairs(self.defs) do
        lu.assertIsNumber(def.priority)
        lu.assertTrue(def.priority > 0, def.id .. " priority must be > 0")
    end
end

function TestSubtletyDefs:test_no_priority_collision_within_group()
    local seen = {}
    for _, def in ipairs(self.defs) do
        local key = def.group .. ":" .. tostring(def.priority)
        lu.assertNil(seen[key], "priority collision in group '" .. def.group .. "' at priority " .. def.priority)
        seen[key] = def.id
    end
end

-- Runner calls lu.LuaUnit.run() — do not call os.exit here
