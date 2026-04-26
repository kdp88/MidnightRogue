--[[
    tests/mocks/addon_env.lua
    Simulates the WoW addon loading environment.
    Require this after wow_api.lua and before any addon module.

    WoW passes (addonName, addonTable) as varargs to each file via `...`.
    Outside the client we replicate this by setting a global MR table and
    using a loader wrapper so modules can still do `local addonName, MR = ...`
--]]

-- Global addon table (mirrors what WoW creates from the .toc)
_G.MR = _G.MR or {}
_G.MR.Trackers = _G.MR.Trackers or {}

-- Wrap require so each addon file receives ("MidnightRogue", MR) as varargs
local _real_loadfile = loadfile

local function addon_loadfile(path)
    local chunk, err = _real_loadfile(path)
    if not chunk then return nil, err end
    -- Return a wrapper that injects (...) = addonName, MR
    return function(...)
        return chunk("MidnightRogue", _G.MR)
    end
end

-- Override package.loaders / package.searchers to use our loadfile
-- so that require("AuraEngine") injects the addon env automatically
local base = "C:/dev/MidnightRogue/"

local function addon_searcher(modname)
    -- Map module names to file paths
    local paths = {
        ["AuraEngine"]          = base .. "AuraEngine.lua",
        ["SpecDetection"]       = base .. "SpecDetection.lua",
        ["Subtlety"]            = base .. "TrackerDefinitions/Subtlety.lua",
        ["Animations"]          = base .. "Display/Animations.lua",
        ["BarRenderer"]         = base .. "Display/BarRenderer.lua",
        ["BarGroup"]            = base .. "Display/BarGroup.lua",
        ["Defaults"]            = base .. "Config/Defaults.lua",
        ["Options"]             = base .. "Config/Options.lua",
        ["Profiles"]            = base .. "Config/Profiles.lua",
    }
    local filepath = paths[modname]
    if not filepath then return nil end
    local loader, err = addon_loadfile(filepath)
    if not loader then return "\n\t" .. tostring(err) end
    return loader
end

-- Prepend our searcher so it takes priority
table.insert(package.searchers or package.loaders, 1, addon_searcher)
