--[[
    Display/BarGroup.lua
    Manages a named collection of bars (e.g. "Stealth", "Cooldowns", "Procs", "DoTs").
    Handles layout, anchoring, grow direction, drag-to-move when unlocked,
    and the OnUpdate loop that drives per-bar duration updates.
--]]

local addonName, MR = ...
MR.BarGroup = {}
local BarGroup = MR.BarGroup

local GROW = { UP = "UP", DOWN = "DOWN" }
local BAR_SPACING = 2
local groups = {}  -- active group frames keyed by group name

local function OnGroupUpdate(frame, elapsed)
    frame._tick = (frame._tick or 0) + elapsed
    if frame._tick < 0.05 then return end
    frame._tick = 0

    local toRelease = nil
    for i, bar in ipairs(frame._bars) do
        MR.BarRenderer:UpdateBar(bar)
        if bar.expired then
            toRelease = toRelease or {}
            table.insert(toRelease, i)
        end
    end

    if toRelease then
        for i = #toRelease, 1, -1 do
            local idx = toRelease[i]
            MR.BarRenderer:ReleaseBar(frame._bars[idx])
            table.remove(frame._bars, idx)
        end
        BarGroup:LayoutBars(frame)
    end
end

local function EnableDragging(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        -- Save position to profile
        local point, _, relPoint, x, y = f:GetPoint()
        if MR.db and MR.db.profile and MR.db.profile.groups and MR.db.profile.groups[f._groupName] then
            MR.db.profile.groups[f._groupName].x = x
            MR.db.profile.groups[f._groupName].y = y
        end
    end)
end

local function DisableDragging(frame)
    frame:SetMovable(false)
    frame:EnableMouse(false)
end

-- Create or return existing group frame by name
function BarGroup:GetOrCreate(groupName, settings)
    if groups[groupName] then return groups[groupName] end

    local frame = CreateFrame("Frame", "MR_Group_" .. groupName, UIParent)
    frame:SetSize(settings.width or 200, 1)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetScript("OnUpdate", OnGroupUpdate)

    -- Header label (shown only when unlocked)
    frame._label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame._label:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    frame._label:SetText(groupName)
    frame._label:Hide()

    frame._bars      = {}
    frame._groupName = groupName
    frame._grow      = settings.grow or GROW.UP
    frame._width     = settings.width or 200
    frame._height    = settings.height or 24

    -- Restore position
    local x = settings.x or 0
    local y = settings.y or 0
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

    if not settings.locked then
        EnableDragging(frame)
        frame._label:Show()
    end

    groups[groupName] = frame
    return frame
end

-- Stack bars inside their group frame according to grow direction
function BarGroup:LayoutBars(frame)
    local barCount = #frame._bars
    local barHeight = frame._height or 24
    local spacing = BAR_SPACING
    local totalHeight = barCount > 0 and (barCount * barHeight + (barCount - 1) * spacing) or 1
    frame:SetHeight(math.max(totalHeight, 1))

    for i, bar in ipairs(frame._bars) do
        bar:ClearAllPoints()
        bar:SetWidth(frame._width)
        local offset
        if frame._grow == GROW.UP then
            offset = (i - 1) * (barHeight + spacing)
            bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, offset)
        else
            offset = (i - 1) * (barHeight + spacing)
            bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -offset)
        end
    end
end

-- Add a configured bar to a group (sorted by priority, highest first)
function BarGroup:AddBar(groupName, bar, priority)
    local frame = groups[groupName]
    if not frame then return end

    bar._priority = priority or 0
    table.insert(frame._bars, bar)
    table.sort(frame._bars, function(a, b)
        return (a._priority or 0) > (b._priority or 0)
    end)

    BarGroup:LayoutBars(frame)
end

-- Remove all bars from a group and release them back to the pool
function BarGroup:ClearGroup(groupName)
    local frame = groups[groupName]
    if not frame then return end
    for _, bar in ipairs(frame._bars) do
        MR.BarRenderer:ReleaseBar(bar)
    end
    frame._bars = {}
    frame:SetHeight(1)
end

-- Remove all bars from all groups
function BarGroup:ClearAll()
    for name, _ in pairs(groups) do
        BarGroup:ClearGroup(name)
    end
end

-- Lock or unlock all groups
function BarGroup:SetLocked(locked)
    for _, frame in pairs(groups) do
        if locked then
            DisableDragging(frame)
            frame._label:Hide()
        else
            EnableDragging(frame)
            frame._label:Show()
        end
    end
end

function BarGroup:SetWidth(groupName, width)
    local frame = groups[groupName]
    if not frame then return end
    frame._width = width
    for _, bar in ipairs(frame._bars) do
        MR.BarRenderer:SetWidth(bar, width)
    end
end

function BarGroup:SetHeight(groupName, height)
    local frame = groups[groupName]
    if not frame then return end
    frame._height = height
    BarGroup:LayoutBars(frame)
end

BarGroup.GROW = GROW
