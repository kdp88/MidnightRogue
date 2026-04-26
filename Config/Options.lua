--[[
    Config/Options.lua
    Ace3 options table. Generates the /mr configuration panel.
    Groups: General | Bar Groups | Trackers (per tracker entry from active spec)
--]]

local addonName, MR = ...
MR.Options = {}
local Options = MR.Options

local GROUP_LABELS = {
    stealth   = "Stealth States",
    cooldowns = "Major Cooldowns",
    procs     = "Procs",
    dots      = "DoTs on Target",
    debuffs   = "Debuffs on Target",
}

local function GetGroupOptions(groupName)
    local label = GROUP_LABELS[groupName] or groupName
    return {
        name  = label,
        type  = "group",
        order = 1,
        args  = {
            enabled = {
                name    = "Enabled",
                type    = "toggle",
                order   = 1,
                get     = function() return MR.db.profile.groups[groupName].enabled end,
                set     = function(_, v)
                    MR.db.profile.groups[groupName].enabled = v
                    MR:RefreshDisplay()
                end,
            },
            width = {
                name    = "Width",
                type    = "range",
                order   = 2,
                min     = 100, max = 600, step = 10,
                get     = function() return MR.db.profile.groups[groupName].width end,
                set     = function(_, v)
                    MR.db.profile.groups[groupName].width = v
                    MR.BarGroup:SetWidth(groupName, v)
                end,
            },
            grow = {
                name   = "Grow Direction",
                type   = "select",
                order  = 3,
                values = { UP = "Upward", DOWN = "Downward" },
                get    = function() return MR.db.profile.groups[groupName].grow end,
                set    = function(_, v)
                    MR.db.profile.groups[groupName].grow = v
                    MR:RefreshDisplay()
                end,
            },
        },
    }
end

local function GetTrackerOptions(trackerDef)
    local id = trackerDef.id
    return {
        name  = trackerDef.name,
        type  = "group",
        order = trackerDef.priority,
        args  = {
            enabled = {
                name  = "Track This",
                type  = "toggle",
                order = 1,
                get   = function()
                    local t = MR.db.profile.trackers[id]
                    return t == nil and true or t.enabled  -- default enabled
                end,
                set   = function(_, v)
                    MR.db.profile.trackers[id] = MR.db.profile.trackers[id] or {}
                    MR.db.profile.trackers[id].enabled = v
                    MR:RefreshDisplay()
                end,
            },
            showName = {
                name  = "Show Name",
                type  = "toggle",
                order = 2,
                get   = function()
                    local t = MR.db.profile.trackers[id]
                    return t == nil and true or (t.showName ~= false)
                end,
                set   = function(_, v)
                    MR.db.profile.trackers[id] = MR.db.profile.trackers[id] or {}
                    MR.db.profile.trackers[id].showName = v
                    MR:RefreshDisplay()
                end,
            },
            color = {
                name  = "Bar Color",
                type  = "color",
                order = 3,
                hasAlpha = true,
                get   = function()
                    local t = MR.db.profile.trackers[id]
                    local c = (t and t.color) or trackerDef.color
                    return c.r, c.g, c.b, c.a
                end,
                set   = function(_, r, g, b, a)
                    MR.db.profile.trackers[id] = MR.db.profile.trackers[id] or {}
                    MR.db.profile.trackers[id].color = { r=r, g=g, b=b, a=a }
                    MR:RefreshDisplay()
                end,
            },
            flashBelow = {
                name  = "Flash Below (seconds)",
                type  = "range",
                order = 4,
                min = 0, max = 15, step = 0.5,
                get   = function()
                    local t = MR.db.profile.trackers[id]
                    return (t and t.flashBelow) or (trackerDef.flashBelow or 0)
                end,
                set   = function(_, v)
                    MR.db.profile.trackers[id] = MR.db.profile.trackers[id] or {}
                    MR.db.profile.trackers[id].flashBelow = v
                end,
            },
        },
    }
end

function Options:Build(trackerList)
    local groupArgs = {}
    for groupName, _ in pairs(MR.Defaults.profile.groups) do
        groupArgs[groupName] = GetGroupOptions(groupName)
    end

    local trackerArgs = {}
    if trackerList then
        for _, def in ipairs(trackerList) do
            trackerArgs[def.id] = GetTrackerOptions(def)
        end
    end

    return {
        name    = "MidnightRogue",
        type    = "group",
        args    = {
            general = {
                name  = "General",
                type  = "group",
                order = 1,
                args  = {
                    locked = {
                        name  = "Lock Bar Groups",
                        type  = "toggle",
                        order = 1,
                        get   = function() return MR.db.profile.locked end,
                        set   = function(_, v)
                            MR.db.profile.locked = v
                            MR.BarGroup:SetLocked(v)
                        end,
                    },
                    currentSpec = {
                        name     = "Active Spec Profile",
                        type     = "description",
                        order    = 2,
                        fontSize = "medium",
                        image    = "",
                        get      = function()
                            return "Profile: " .. MR.Profiles:GetCurrentProfileName() .. " (reload to change)"
                        end,
                    },
                },
            },
            groups = {
                name  = "Bar Groups",
                type  = "group",
                order = 2,
                args  = groupArgs,
            },
            trackers = {
                name  = "Trackers",
                type  = "group",
                order = 3,
                args  = trackerArgs,
            },
        },
    }
end
