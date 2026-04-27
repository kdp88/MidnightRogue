--[[
    Config/SettingsUI.lua
    Custom settings panel built with raw WoW frames (no AceGUI/AceConfigDialog).
    Opens via /mr. Tabs: Buffs | Procs | Debuffs.
--]]

local addonName, MR = ...
MR.SettingsUI = {}
local UI = MR.SettingsUI

local PANEL_W    = 300
local PANEL_H    = 500
local TAB_H      = 28
local ROW_H      = 24
local INDENT     = 12
local FONT       = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE  = 12

local GROUP_ORDER  = { "buffs", "procs", "debuffs" }
local GROUP_LABELS = { buffs = "Buffs", procs = "Procs", debuffs = "Debuffs" }

local frame       = nil   -- created once
local tabButtons  = {}
local tabPanes    = {}    -- tabPanes[groupName] = frame
local activeTab   = nil

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function SetFont(fs, size)
    fs:SetFont(FONT, size or FONT_SIZE)
end

local function MakeBackground(f, r, g, b, a)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    return bg
end

-- Simple toggle row: colored box + label. Returns the row frame.
local function CreateToggleRow(parent, label, getVal, setVal)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    local box = row:CreateTexture(nil, "ARTWORK")
    box:SetSize(14, 14)
    box:SetPoint("LEFT", INDENT, 0)

    local text = row:CreateFontString(nil, "OVERLAY")
    SetFont(text)
    text:SetPoint("LEFT", box, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    text:SetText(label)

    local function Refresh()
        if getVal() then
            box:SetColorTexture(0.2, 0.85, 0.2, 1)
            text:SetTextColor(1, 1, 1, 1)
        else
            box:SetColorTexture(0.4, 0.4, 0.4, 0.6)
            text:SetTextColor(0.6, 0.6, 0.6, 1)
        end
    end

    row:SetScript("OnClick", function()
        setVal(not getVal())
        Refresh()
        MR:RefreshDisplay()
    end)

    row.Refresh = Refresh
    Refresh()
    return row
end

-- ─── Tab switching ────────────────────────────────────────────────────────────

local function ShowTab(groupName)
    for _, name in ipairs(GROUP_ORDER) do
        if tabPanes[name] then
            tabPanes[name]:SetShown(name == groupName)
        end
        if tabButtons[name] then
            if name == groupName then
                tabButtons[name].bg:SetColorTexture(0.25, 0.25, 0.35, 1)
                tabButtons[name].label:SetTextColor(1, 1, 1, 1)
            else
                tabButtons[name].bg:SetColorTexture(0.12, 0.12, 0.18, 1)
                tabButtons[name].label:SetTextColor(0.7, 0.7, 0.7, 1)
            end
        end
    end
    activeTab = groupName
end

-- ─── Pane builder ────────────────────────────────────────────────────────────

local function BuildPane(parent, groupName, trackerDefs)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    MakeBackground(pane, 0.08, 0.08, 0.12, 1)

    local rows = {}
    local y = -8

    -- Group enable toggle
    local groupRow = CreateToggleRow(pane, "Enable " .. GROUP_LABELS[groupName],
        function()
            local g = MR.db.profile.groups[groupName]
            return g == nil and true or (g.enabled ~= false)
        end,
        function(v)
            MR.db.profile.groups[groupName] = MR.db.profile.groups[groupName] or {}
            MR.db.profile.groups[groupName].enabled = v
        end
    )
    groupRow:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, y)
    groupRow:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
    table.insert(rows, groupRow)
    y = y - ROW_H

    -- Divider
    local div = pane:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", pane, "TOPLEFT", INDENT, y - 4)
    div:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -INDENT, y - 4)
    div:SetColorTexture(0.3, 0.3, 0.4, 0.8)
    y = y - 12

    -- Per-tracker toggles sorted by priority descending
    local sorted = {}
    for _, def in ipairs(trackerDefs or {}) do
        table.insert(sorted, def)
    end
    table.sort(sorted, function(a, b) return a.priority > b.priority end)

    for _, def in ipairs(sorted) do
        local id = def.id
        local row = CreateToggleRow(pane, def.name,
            function()
                local t = MR.db.profile.trackers[id]
                return t == nil and true or (t.enabled ~= false)
            end,
            function(v)
                MR.db.profile.trackers[id] = MR.db.profile.trackers[id] or {}
                MR.db.profile.trackers[id].enabled = v
            end
        )
        row:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, y)
        row:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
        table.insert(rows, row)
        y = y - ROW_H
    end

    pane.rows = rows
    return pane
end

-- ─── Main frame ──────────────────────────────────────────────────────────────

local function CreateMainFrame()
    frame = CreateFrame("Frame", "MidnightRogueSettings", UIParent)
    frame:SetSize(PANEL_W, PANEL_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:Hide()

    MakeBackground(frame, 0.08, 0.08, 0.12, 0.97)

    -- Border line
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints(frame)
    border:SetColorTexture(0.3, 0.3, 0.45, 1)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    MakeBackground(titleBar, 0.15, 0.15, 0.25, 1)

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    SetFont(title, 13)
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetText("MidnightRogue")
    title:SetTextColor(1, 0.85, 0, 1)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    local closeBg = closeBtn:CreateTexture(nil, "ARTWORK")
    closeBg:SetAllPoints(closeBtn)
    closeBg:SetColorTexture(0.6, 0.1, 0.1, 0.8)
    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY")
    SetFont(closeLabel, 12)
    closeLabel:SetAllPoints(closeBtn)
    closeLabel:SetText("X")
    closeLabel:SetJustifyH("CENTER")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Tab row
    local tabRow = CreateFrame("Frame", nil, frame)
    tabRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -30)
    tabRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -30)
    tabRow:SetHeight(TAB_H)
    MakeBackground(tabRow, 0.1, 0.1, 0.18, 1)

    local tabW = (PANEL_W - 2) / #GROUP_ORDER
    for i, groupName in ipairs(GROUP_ORDER) do
        local btn = CreateFrame("Button", nil, tabRow)
        btn:SetSize(tabW, TAB_H)
        btn:SetPoint("LEFT", tabRow, "LEFT", (i - 1) * tabW, 0)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
        btn.bg:SetColorTexture(0.12, 0.12, 0.18, 1)

        btn.label = btn:CreateFontString(nil, "OVERLAY")
        SetFont(btn.label)
        btn.label:SetAllPoints(btn)
        btn.label:SetText(GROUP_LABELS[groupName])
        btn.label:SetJustifyH("CENTER")
        btn.label:SetTextColor(0.7, 0.7, 0.7, 1)

        btn:SetScript("OnClick", function() ShowTab(groupName) end)
        tabButtons[groupName] = btn
    end

    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -(30 + TAB_H))
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.content = content

    return content
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function UI:Rebuild(trackerList)
    -- Create main frame on first Rebuild (PLAYER_ENTERING_WORLD guarantees APIs are ready)
    if not frame then
        CreateMainFrame()
    end

    -- Group tracker defs by group name
    local byGroup = {}
    for _, def in ipairs(trackerList or {}) do
        if def.group then
            byGroup[def.group] = byGroup[def.group] or {}
            table.insert(byGroup[def.group], def)
        end
    end

    -- Rebuild panes with current tracker list
    for _, name in ipairs(GROUP_ORDER) do
        if tabPanes[name] then
            tabPanes[name]:Hide()
            tabPanes[name] = nil
        end
    end
    for _, name in ipairs(GROUP_ORDER) do
        tabPanes[name] = BuildPane(frame.content, name, byGroup[name])
    end
    ShowTab(activeTab or GROUP_ORDER[1])
end

function UI:Open()
    if not frame then return end  -- not yet initialized (before PLAYER_ENTERING_WORLD)
    -- Refresh all toggle states in case db changed since last open
    for _, name in ipairs(GROUP_ORDER) do
        if tabPanes[name] and tabPanes[name].rows then
            for _, row in ipairs(tabPanes[name].rows) do
                if row.Refresh then row:Refresh() end
            end
        end
    end
    frame:Show()
end
