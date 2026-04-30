--[[
    Config/SettingsUI.lua
    Custom settings panel built with raw WoW frames (no AceGUI/AceConfigDialog).
    Opens via /mr. Tabs: Buffs | Procs | Debuffs.
    Each tab: group enable toggle, width stepper, per-tracker enable + color swatch.
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

local WIDTH_MIN  = 100
local WIDTH_MAX  = 400
local WIDTH_STEP = 10

local GROUP_ORDER  = { "buffs", "procs", "debuffs" }
local GROUP_LABELS = { buffs = "Buffs", procs = "Procs", debuffs = "Debuffs" }

local frame      = nil
local tabButtons = {}
local tabPanes   = {}
local activeTab  = nil

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

local function MakeButton(parent, w, h, label, fontSize)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w, h)
    local bg = btn:CreateTexture(nil, "ARTWORK")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0.25, 0.25, 0.35, 1)
    btn._bg = bg
    local fs = btn:CreateFontString(nil, "OVERLAY")
    SetFont(fs, fontSize or FONT_SIZE)
    fs:SetAllPoints(btn)
    fs:SetJustifyH("CENTER")
    fs:SetText(label)
    btn._label = fs
    return btn
end

-- ─── Color picker (WoW built-in with preset palette fallback) ─────────────────

local PRESET_COLORS = {
    { r=0.9, g=0.1, b=0.1 }, { r=1.0, g=0.5, b=0.0 }, { r=1.0, g=0.9, b=0.0 }, { r=0.1, g=0.9, b=0.1 },
    { r=0.0, g=0.8, b=0.8 }, { r=0.2, g=0.4, b=1.0 }, { r=0.6, g=0.0, b=0.9 }, { r=1.0, g=0.4, b=0.7 },
    { r=1.0, g=1.0, b=1.0 }, { r=0.7, g=0.7, b=0.7 }, { r=0.35,g=0.35,b=0.35}, { r=0.05,g=0.05,b=0.05},
}

local presetPopup = nil

local function OpenPresetPalette(anchor, a, onConfirm)
    if not presetPopup then
        local cols, rows = 4, 3
        local sw_size, pad = 18, 5
        presetPopup = CreateFrame("Frame", nil, UIParent)
        presetPopup:SetSize(cols * sw_size + (cols - 1) * 2 + pad * 2,
                            rows * sw_size + (rows - 1) * 2 + pad * 2)
        presetPopup:SetFrameStrata("TOOLTIP")
        presetPopup:SetClampedToScreen(true)
        MakeBackground(presetPopup, 0.08, 0.08, 0.12, 0.97)
        local border = presetPopup:CreateTexture(nil, "BORDER")
        border:SetAllPoints(presetPopup)
        border:SetColorTexture(0.3, 0.3, 0.45, 1)
        presetPopup._swatches = {}
        for i, c in ipairs(PRESET_COLORS) do
            local s = CreateFrame("Button", nil, presetPopup)
            s:SetSize(sw_size, sw_size)
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            s:SetPoint("TOPLEFT", presetPopup, "TOPLEFT",
                pad + col * (sw_size + 2), -(pad + row * (sw_size + 2)))
            local tex = s:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(s)
            tex:SetColorTexture(c.r, c.g, c.b, 1)
            s._color = c
            presetPopup._swatches[i] = s
        end
        presetPopup:Hide()
    end

    for _, s in ipairs(presetPopup._swatches) do
        s:SetScript("OnClick", function()
            local c = s._color
            onConfirm(c.r, c.g, c.b, a)
            presetPopup:Hide()
        end)
    end

    presetPopup:ClearAllPoints()
    presetPopup:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    presetPopup:Show()
end

local function OpenColorPicker(swatchBtn, r, g, b, a, onConfirm, onCancel)
    if not ColorPickerFrame then
        OpenPresetPalette(swatchBtn, a, onConfirm)
        return
    end

    local function onSwatchChange()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = ColorPickerFrame.GetColorAlpha and (1 - ColorPickerFrame:GetColorAlpha())
                   or (1 - (ColorPickerFrame.opacity or 0))
        onConfirm(nr, ng, nb, na)
    end

    local function onPickerCancel(prev)
        if prev then
            onCancel(prev.r, prev.g, prev.b, prev.a)
        else
            onCancel(r, g, b, a)
        end
    end

    -- Try Dragonflight+ API first
    if ColorPickerFrame.SetupColorPickerAndShow then
        local ok = pcall(function()
            ColorPickerFrame:SetupColorPickerAndShow({
                swatchFunc  = onSwatchChange,
                opacityFunc = onSwatchChange,
                cancelFunc  = onPickerCancel,
                hasOpacity  = true,
                opacity     = 1 - a,
                r = r, g = g, b = b,
            })
        end)
        if ok then return end
    end

    -- Legacy API
    local ok = pcall(function()
        ColorPickerFrame.func        = onSwatchChange
        ColorPickerFrame.opacityFunc = onSwatchChange
        ColorPickerFrame.cancelFunc  = onPickerCancel
        ColorPickerFrame.hasOpacity  = true
        ColorPickerFrame.opacity     = 1 - a
        ColorPickerFrame:SetColorRGB(r, g, b)
        ShowUIPanel(ColorPickerFrame)
    end)
    if ok then return end

    -- Both failed — preset palette
    OpenPresetPalette(swatchBtn, a, onConfirm)
end

-- ─── Row builders ─────────────────────────────────────────────────────────────

-- Group-level enable toggle (full-width button)
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

-- Width stepper: [-] [value] [+]
local function CreateWidthStepper(parent, groupName)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)

    local label = row:CreateFontString(nil, "OVERLAY")
    SetFont(label)
    label:SetPoint("LEFT", INDENT, 0)
    label:SetText("Width:")
    label:SetTextColor(0.8, 0.8, 0.8, 1)

    local plusBtn  = MakeButton(row, 20, 16, "+", 11)
    plusBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)

    local valueLabel = row:CreateFontString(nil, "OVERLAY")
    SetFont(valueLabel)
    valueLabel:SetSize(34, ROW_H)
    valueLabel:SetPoint("RIGHT", plusBtn, "LEFT", -3, 0)
    valueLabel:SetJustifyH("CENTER")
    valueLabel:SetTextColor(1, 1, 1, 1)

    local minusBtn = MakeButton(row, 20, 16, "-", 11)
    minusBtn:SetPoint("RIGHT", valueLabel, "LEFT", -3, 0)

    local function GetW()
        local g = MR.db.profile.groups[groupName]
        return (g and g.width) or 220
    end

    local function ApplyWidth(w)
        w = math.max(WIDTH_MIN, math.min(WIDTH_MAX, w))
        MR.db.profile.groups[groupName] = MR.db.profile.groups[groupName] or {}
        MR.db.profile.groups[groupName].width = w
        valueLabel:SetText(tostring(w))
        MR.BarGroup:SetWidth(groupName, w)
        MR:RefreshDisplay()
    end

    local function Refresh()
        valueLabel:SetText(tostring(GetW()))
    end

    minusBtn:SetScript("OnClick", function() ApplyWidth(GetW() - WIDTH_STEP) end)
    plusBtn:SetScript("OnClick",  function() ApplyWidth(GetW() + WIDTH_STEP) end)

    row.Refresh = Refresh
    Refresh()
    return row
end

-- Tracker row: enable box + name + color swatch (separate clickable regions)
local function CreateTrackerRow(parent, def)
    local id = def.id
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)

    -- Enable button (left box)
    local enableBtn = CreateFrame("Button", nil, row)
    enableBtn:SetSize(ROW_H, ROW_H)
    enableBtn:SetPoint("LEFT", 0, 0)

    local box = enableBtn:CreateTexture(nil, "ARTWORK")
    box:SetSize(14, 14)
    box:SetPoint("CENTER", enableBtn, "CENTER", 0, 0)

    -- Color swatch (right)
    local swatchBtn = CreateFrame("Button", nil, row)
    swatchBtn:SetSize(ROW_H, ROW_H)
    swatchBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local swatchTex = swatchBtn:CreateTexture(nil, "ARTWORK")
    swatchTex:SetSize(14, 14)
    swatchTex:SetPoint("CENTER", swatchBtn, "CENTER", 0, 0)

    -- Name label
    local text = row:CreateFontString(nil, "OVERLAY")
    SetFont(text)
    text:SetPoint("LEFT", enableBtn, "RIGHT", 4, 0)
    text:SetPoint("RIGHT", swatchBtn, "LEFT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetText(def.name)

    local function GetEffectiveColor()
        local t = MR.db.profile.trackers[id]
        if t and t.color then
            return t.color.r, t.color.g, t.color.b, t.color.a
        end
        local c = def.color
        return c.r, c.g, c.b, c.a
    end

    local function IsEnabled()
        local t = MR.db.profile.trackers[id]
        return t == nil or (t.enabled ~= false)
    end

    local function Refresh()
        if IsEnabled() then
            box:SetColorTexture(0.2, 0.85, 0.2, 1)
            text:SetTextColor(1, 1, 1, 1)
        else
            box:SetColorTexture(0.4, 0.4, 0.4, 0.6)
            text:SetTextColor(0.6, 0.6, 0.6, 1)
        end
        local r, g, b = GetEffectiveColor()
        swatchTex:SetColorTexture(r, g, b, 1)
    end

    enableBtn:SetScript("OnClick", function()
        MR.db.profile.trackers[id] = MR.db.profile.trackers[id] or {}
        MR.db.profile.trackers[id].enabled = not IsEnabled()
        Refresh()
        MR:RefreshDisplay()
    end)

    swatchBtn:SetScript("OnClick", function()
        local r, g, b, a = GetEffectiveColor()
        OpenColorPicker(swatchBtn, r, g, b, a,
            function(nr, ng, nb, na)
                MR.db.profile.trackers[id] = MR.db.profile.trackers[id] or {}
                local c = MR.db.profile.trackers[id].color or {}
                c.r, c.g, c.b, c.a = nr, ng, nb, na
                MR.db.profile.trackers[id].color = c
                Refresh()
                MR:RefreshDisplay()
            end,
            function(pr, pg, pb, pa)
                MR.db.profile.trackers[id] = MR.db.profile.trackers[id] or {}
                local c = MR.db.profile.trackers[id].color or {}
                c.r, c.g, c.b, c.a = pr, pg, pb, pa
                MR.db.profile.trackers[id].color = c
                Refresh()
                MR:RefreshDisplay()
            end
        )
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
    pane:SetPoint("TOPLEFT",     parent, "TOPLEFT",     0, 0)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    MakeBackground(pane, 0.08, 0.08, 0.12, 1)

    local rows = {}
    local y = -8

    local function addRow(row)
        row:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, y)
        row:SetPoint("RIGHT",   pane, "RIGHT",   0, 0)
        table.insert(rows, row)
        y = y - ROW_H
    end

    local function addDivider()
        local div = pane:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1)
        div:SetPoint("TOPLEFT",  pane, "TOPLEFT",  INDENT,  y - 4)
        div:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -INDENT, y - 4)
        div:SetColorTexture(0.3, 0.3, 0.4, 0.8)
        y = y - 12
    end

    -- Group enable toggle
    addRow(CreateToggleRow(pane, "Enable " .. GROUP_LABELS[groupName],
        function()
            local g = MR.db.profile.groups[groupName]
            return g == nil or (g.enabled ~= false)
        end,
        function(v)
            MR.db.profile.groups[groupName] = MR.db.profile.groups[groupName] or {}
            MR.db.profile.groups[groupName].enabled = v
        end
    ))

    -- Width stepper
    addRow(CreateWidthStepper(pane, groupName))

    addDivider()

    -- Per-tracker rows sorted by priority descending
    local sorted = {}
    for _, def in ipairs(trackerDefs or {}) do
        table.insert(sorted, def)
    end
    table.sort(sorted, function(a, b) return (a.priority or 0) > (b.priority or 0) end)

    for _, def in ipairs(sorted) do
        addRow(CreateTrackerRow(pane, def))
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

    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints(frame)
    border:SetColorTexture(0.3, 0.3, 0.45, 1)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    MakeBackground(titleBar, 0.15, 0.15, 0.25, 1)

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    SetFont(title, 13)
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetText("MidnightRogue")
    title:SetTextColor(1, 0.85, 0, 1)

    local closeBtn = MakeButton(frame, 22, 22, "X", 12)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn._bg:SetColorTexture(0.6, 0.1, 0.1, 0.8)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Unlock bars toggle in title bar
    local lockBtn = MakeButton(frame, 80, 18, "", 10)
    lockBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)

    local function RefreshLockBtn()
        local locked = MR.db.profile.locked ~= false
        if locked then
            lockBtn._label:SetText("Unlock Bars")
            lockBtn._bg:SetColorTexture(0.25, 0.25, 0.35, 1)
            lockBtn._label:SetTextColor(0.8, 0.8, 0.8, 1)
        else
            lockBtn._label:SetText("Lock Bars")
            lockBtn._bg:SetColorTexture(0.1, 0.55, 0.1, 1)
            lockBtn._label:SetTextColor(1, 1, 1, 1)
        end
    end

    lockBtn:SetScript("OnClick", function()
        local nowLocked = not (MR.db.profile.locked ~= false)
        MR.db.profile.locked = nowLocked
        MR.BarGroup:SetLocked(nowLocked)
        RefreshLockBtn()
        MR:RefreshDisplay()
    end)

    frame._refreshLockBtn = RefreshLockBtn
    RefreshLockBtn()

    local tabRow = CreateFrame("Frame", nil, frame)
    tabRow:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -30)
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

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT",     frame, "TOPLEFT",     1, -(30 + TAB_H))
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.content = content

    return content
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function UI:Rebuild(trackerList)
    if not frame then
        CreateMainFrame()
    end

    local byGroup = {}
    for _, def in ipairs(trackerList or {}) do
        if def.group then
            byGroup[def.group] = byGroup[def.group] or {}
            table.insert(byGroup[def.group], def)
        end
    end

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
    if not frame then return end
    if frame._refreshLockBtn then frame._refreshLockBtn() end
    for _, name in ipairs(GROUP_ORDER) do
        if tabPanes[name] and tabPanes[name].rows then
            for _, row in ipairs(tabPanes[name].rows) do
                if row.Refresh then row:Refresh() end
            end
        end
    end
    frame:Show()
end
