--[[
    tests/runner.lua
    Runs all test suites. Execute via run_tests.sh or:
      lua tests/runner.lua
--]]
local lu = require("luaunit")

-- Load all test suites (order doesn't matter — luaunit collects all TestXxx globals)
require("tests.test_subtlety_defs")
require("tests.test_animations")
require("tests.test_bar_renderer")
require("tests.test_aura_engine")
require("tests.test_options")

os.exit(lu.LuaUnit.run())
