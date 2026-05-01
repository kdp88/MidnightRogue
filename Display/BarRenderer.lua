--[[
    Display/BarRenderer.lua
    Creates, configures, and recycles individual bar frames.
    Each bar shows: ability icon | status bar (duration) | name text | time text
    Icons are pulled from the game client via spell data — no external assets needed.
--]]

local addonName, MR = ...
MR.BarRenderer = {}
local BarRenderer = MR.BarRenderer

local BAR_HEIGHT_DEFAULT = 24
local TEXT_PADDING       = 4
local BAR_FONT           = "Fonts\\FRIZQT__.TTF"

local function FontSizeForHeight(h)
    return math.max(8, math.floor(h * 0.46))
end

-- Frame pool — recycled to avoid garbage collection pressure
local barPool = {}

local function CreateBarFrame(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(BAR_HEIGHT_DEFAULT)

    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(BAR_HEIGHT_DEFAULT, BAR_HEIGHT_DEFAULT)
    bar.icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    bar.statusbar = CreateFrame("StatusBar", nil, bar)
    bar.statusbar:SetPoint("LEFT", bar.icon, "RIGHT", 2, 0)
    bar.statusbar:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    bar.statusbar:SetHeight(BAR_HEIGHT_DEFAULT)
    bar.statusbar:SetMinMaxValues(0, 1)
    bar.statusbar:SetValue(1)

    bar.bg = bar.statusbar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar.statusbar)
    bar.bg:SetColorTexture(0, 0, 0, 0.5)

    bar.nameText = bar.statusbar:CreateFontString(nil, "OVERLAY")
    bar.nameText:SetPoint("LEFT", bar.statusbar, "LEFT", TEXT_PADDING, 0)
    bar.nameText:SetJustifyH("LEFT")
    bar.nameText:SetTextColor(1, 1, 1, 1)

    bar.timeText = bar.statusbar:CreateFontString(nil, "OVERLAY")
    bar.timeText:SetPoint("RIGHT", bar.statusbar, "RIGHT", -TEXT_PADDING, 0)
    bar.timeText:SetJustifyH("RIGHT")
    bar.timeText:SetTextColor(1, 1, 1, 1)

    -- Stack count overlaid on icon (parented to bar Frame, not Texture)
    bar.stackText = bar:CreateFontString(nil, "OVERLAY")
    bar.stackText:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMRIGHT", 0, 0)
    bar.stackText:SetTextColor(1, 1, 0, 1)

    bar:Hide()
    return bar
end

-- Pull a bar from the pool or create a new one
function BarRenderer:AcquireBar(parent)
    local bar = table.remove(barPool)
    if not bar then
        bar = CreateBarFrame(parent)
    else
        bar:SetParent(parent)
    end
    bar:Show()
    return bar
end

-- Return a bar to the pool
function BarRenderer:ReleaseBar(bar)
    bar:Hide()
    bar:ClearAllPoints()
    -- Clear state so stale data doesn't bleed into the next use
    bar.trackerID  = nil
    bar.startTime  = nil
    bar.endTime    = nil
    bar.duration   = nil
    bar.flashBelow = nil
    bar.expired    = nil
    bar._flashing  = nil
    table.insert(barPool, bar)
end

-- Configure a bar from a tracker definition and live aura data
-- trackerDef: entry from TrackerDefinitions/Subtlety.lua
-- auraData:   result from AuraEngine:GetPlayerBuff / GetTargetDebuff
-- settings:   per-tracker user settings from saved variables
-- barHeight:  pixel height for this bar (from group settings); nil = default
function BarRenderer:ConfigureBar(bar, trackerDef, auraData, settings, barHeight)
    local cfg = settings or {}
    local h   = barHeight or BAR_HEIGHT_DEFAULT
    local fs  = FontSizeForHeight(h)

    -- Height and font size applied every configure so pooled bars resize correctly
    bar:SetHeight(h)
    bar.icon:SetSize(h, h)
    bar.statusbar:SetHeight(h)
    bar.nameText:SetFont(BAR_FONT, fs)
    bar.timeText:SetFont(BAR_FONT, fs)
    bar.stackText:SetFont(BAR_FONT, math.max(8, fs - 2))

    -- Icon: use user override if set, otherwise pull from spell data
    local iconID = cfg.iconOverride or MR.AuraEngine:GetSpellIcon(trackerDef.spellID)
    if iconID then
        bar.icon:SetTexture(iconID)
        bar.icon:Show()
    else
        bar.icon:Hide()
    end

    -- Bar color: user override first, then tracker default
    local r = cfg.color and cfg.color.r or trackerDef.color.r
    local g = cfg.color and cfg.color.g or trackerDef.color.g
    local b = cfg.color and cfg.color.b or trackerDef.color.b
    local a = cfg.color and cfg.color.a or trackerDef.color.a
    bar.statusbar:SetStatusBarColor(r, g, b, a)

    -- Bar texture
    if cfg.texture then
        bar.statusbar:SetStatusBarTexture(cfg.texture)
    else
        bar.statusbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end

    -- Name text
    local showName = cfg.showName ~= false  -- default true
    if showName then
        bar.nameText:SetText(cfg.nameOverride or trackerDef.name)
        bar.nameText:Show()
    else
        bar.nameText:Hide()
    end

    -- Stacks
    local stacks = auraData.stacks or 0
    local showStacks = trackerDef.showStacks and stacks > 1
    if showStacks then
        bar.stackText:SetText(tostring(stacks))
        bar.stackText:Show()
    else
        bar.stackText:Hide()
    end

    -- Duration tracking data stored on the bar for OnUpdate
    -- endTime=nil means no expiry (permanent until cleared by game state)
    bar.trackerID  = trackerDef.id
    bar.duration   = auraData.duration
    bar.endTime    = (auraData.expirationTime and auraData.expirationTime > 0) and auraData.expirationTime or nil
    bar.startTime  = bar.endTime and (bar.endTime - auraData.duration) or nil
    bar.flashBelow = trackerDef.flashBelow or cfg.flashBelow
    bar.showDuration = trackerDef.showDuration

    -- Initial bar fill
    BarRenderer:UpdateBar(bar)
end

-- Called every frame via the bar group's OnUpdate handler
function BarRenderer:UpdateBar(bar)
    if not bar.endTime then
        bar.statusbar:SetValue(1)
        bar.timeText:Hide()
        return
    end

    local now      = MR.AuraEngine:Now()
    local remaining = bar.endTime - now
    local total     = bar.duration

    if remaining <= 0 then
        -- Signal to BarGroup that this bar should be released
        bar.expired = true
        return
    end

    -- Fill proportion
    if total and total > 0 then
        bar.statusbar:SetValue(remaining / total)
    else
        bar.statusbar:SetValue(1)
    end

    -- Duration text
    if bar.showDuration then
        if remaining >= 60 then
            bar.timeText:SetText(string.format("%dm", math.floor(remaining / 60)))
        else
            bar.timeText:SetText(string.format("%.1f", remaining))
        end
        bar.timeText:Show()
    else
        bar.timeText:Hide()
    end

    -- Flash when low
    MR.Animations:UpdateFlash(bar, remaining)
end

-- Set the pixel width of a bar
function BarRenderer:SetWidth(bar, width)
    bar:SetWidth(width)
    -- Icon stays fixed; statusbar stretches
end
