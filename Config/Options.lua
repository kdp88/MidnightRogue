--[[
    Config/Options.lua
    Ace3 options table. Generates the /mr configuration panel.

    Panel layout:
      General          — lock toggle, current spec
      Buffs            — group enable, per-tracker toggles, layout settings
      Procs            — group enable, per-tracker toggles, layout settings
      Debuffs          — group enable, per-tracker toggles, layout settings
--]]

local addonName, MR = ...
MR.Options = {}
local Options = MR.Options

local GROUP_ORDER = { buffs = 2, procs = 3, debuffs = 4 }
local GROUP_LABELS = { buffs = "Buffs", procs = "Procs", debuffs = "Debuffs" }

-- Builds the args table for one group panel.
-- Top section: group-level enable + per-tracker toggles (ordered by priority desc).
-- Bottom section: layout controls (width, grow direction).
local function BuildGroupPanel(groupName, trackerDefs)
    local args = {}

    -- Group-level enable
    args.groupEnabled = {
        name  = "Enable " .. GROUP_LABELS[groupName],
        type  = "toggle",
        order = 1,
        width = "full",
        get   = function()
            local g = MR.db.profile.groups[groupName]
            return g == nil and true or (g.enabled ~= false)
        end,
        set   = function(_, v)
            MR.db.profile.groups[groupName] = MR.db.profile.groups[groupName] or {}
            MR.db.profile.groups[groupName].enabled = v
            MR:RefreshDisplay()
        end,
    }

    args.trackerHeader = {
        name  = "Trackers",
        type  = "header",
        order = 10,
    }

    -- Per-tracker enable toggles, sorted by priority (highest first)
    local sorted = {}
    for _, def in ipairs(trackerDefs) do
        table.insert(sorted, def)
    end
    table.sort(sorted, function(a, b) return a.priority > b.priority end)

    for i, def in ipairs(sorted) do
        local id = def.id
        args["tracker_" .. id] = {
            name  = def.name,
            type  = "toggle",
            order = 10 + i,
            width = "full",
            get   = function()
                local t = MR.db.profile.trackers[id]
                return t == nil and true or (t.enabled ~= false)
            end,
            set   = function(_, v)
                MR.db.profile.trackers[id] = MR.db.profile.trackers[id] or {}
                MR.db.profile.trackers[id].enabled = v
                MR:RefreshDisplay()
            end,
        }
    end

    -- Layout settings
    args.layoutHeader = {
        name  = "Layout",
        type  = "header",
        order = 200,
    }

    args.width = {
        name  = "Bar Width",
        type  = "range",
        order = 201,
        min   = 100, max = 600, step = 10,
        get   = function()
            local g = MR.db.profile.groups[groupName]
            return g and g.width or 220
        end,
        set   = function(_, v)
            MR.db.profile.groups[groupName] = MR.db.profile.groups[groupName] or {}
            MR.db.profile.groups[groupName].width = v
            MR.BarGroup:SetWidth(groupName, v)
        end,
    }

    args.grow = {
        name   = "Grow Direction",
        type   = "select",
        order  = 202,
        values = { UP = "Upward", DOWN = "Downward" },
        get    = function()
            local g = MR.db.profile.groups[groupName]
            return g and g.grow or "UP"
        end,
        set    = function(_, v)
            MR.db.profile.groups[groupName] = MR.db.profile.groups[groupName] or {}
            MR.db.profile.groups[groupName].grow = v
            MR:RefreshDisplay()
        end,
    }

    return {
        name  = GROUP_LABELS[groupName],
        type  = "group",
        order = GROUP_ORDER[groupName] or 99,
        args  = args,
    }
end

function Options:Build(trackerList)
    -- Bucket tracker defs by group
    local byGroup = {}
    if trackerList then
        for _, def in ipairs(trackerList) do
            local g = def.group
            if g then
                byGroup[g] = byGroup[g] or {}
                table.insert(byGroup[g], def)
            end
        end
    end

    local panels = {
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
                    name     = function()
                        return "Profile: " .. MR.Profiles:GetCurrentProfileName() .. " (reload to change)"
                    end,
                    type     = "description",
                    order    = 2,
                    fontSize = "medium",
                },
            },
        },
    }

    for groupName in pairs(GROUP_LABELS) do
        panels[groupName] = BuildGroupPanel(groupName, byGroup[groupName] or {})
    end

    return {
        name = "MidnightRogue",
        type = "group",
        args = panels,
    }
end
