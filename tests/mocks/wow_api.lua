--[[
    tests/mocks/wow_api.lua
    Stubs for every Blizzard global the addon touches.
    Tests require this file first, then require the module under test.
    To simulate specific API states, override individual functions inside each test.
--]]

-- Time
_G.GetTime = function() return 1000.0 end

-- Print (suppress or capture in tests)
_G.print = _G.print or print

-- Frame factory — returns a minimal table that satisfies addon usage
local function MockTexture()
    return {
        SetTexture      = function() end,
        SetTexCoord     = function() end,
        SetSize         = function() end,
        SetPoint        = function() end,
        SetAllPoints    = function() end,
        SetColorTexture = function() end,
        SetText         = function() end,
        SetTextColor    = function() end,
        SetJustifyH     = function() end,
        Show            = function() end,
        Hide            = function() end,
    }
end

local function MockFontString()
    local fs = MockTexture()
    fs._text  = ""
    fs._shown = true
    fs.SetText = function(self, t) self._text = t end
    fs.GetText = function(self) return self._text end
    fs.Show    = function(self) self._shown = true end
    fs.Hide    = function(self) self._shown = false end
    fs.IsShown = function(self) return self._shown end
    return fs
end

local function MockStatusBar(parent)
    local sb = {
        _value = 1,
        _min   = 0,
        _max   = 1,
        _color = {},
        _tex   = nil,
    }
    sb.SetPoint             = function() end
    sb.SetHeight            = function() end
    sb.SetMinMaxValues      = function(self, mn, mx) self._min = mn; self._max = mx end
    sb.SetValue             = function(self, v) self._value = v end
    sb.GetValue             = function(self) return self._value end
    sb.SetStatusBarColor    = function(self, r, g, b, a) self._color = {r=r,g=g,b=b,a=a} end
    sb.SetStatusBarTexture  = function(self, t) self._tex = t end
    sb.CreateTexture        = function() return MockTexture() end
    sb.CreateFontString     = function() return MockFontString() end
    sb.Show                 = function() end
    sb.Hide                 = function() end
    return sb
end

local function MockFrame()
    local f = {
        _alpha    = 1.0,
        _shown    = true,
        _points   = {},
        _width    = 0,
        _height   = 0,
        _children = {},
        _scripts  = {},
    }
    f.SetSize          = function(self, w, h) self._width = w; self._height = h end
    f.SetWidth         = function(self, w) self._width = w end
    f.SetHeight        = function(self, h) self._height = h end
    f.GetWidth         = function(self) return self._width end
    f.GetHeight        = function(self) return self._height end
    f.SetPoint         = function(self, ...) table.insert(self._points, {...}) end
    f.GetPoint         = function(self) return "CENTER", nil, "CENTER", 0, 0 end
    f.ClearAllPoints   = function(self) self._points = {} end
    f.SetAlpha         = function(self, a) self._alpha = a end
    f.GetAlpha         = function(self) return self._alpha end
    f.Show             = function(self) self._shown = true end
    f.Hide             = function(self) self._shown = false end
    f.IsShown          = function(self) return self._shown end
    f.SetParent        = function() end
    f.SetFrameStrata   = function() end
    f.SetMovable       = function() end
    f.SetClampedToScreen = function() end
    f.EnableMouse      = function() end
    f.RegisterForDrag  = function() end
    f.SetScript        = function(self, evt, fn) self._scripts[evt] = fn end
    f.StartMoving      = function() end
    f.StopMovingOrSizing = function() end
    f.CreateTexture    = function() return MockTexture() end
    f.CreateFontString = function() return MockFontString() end
    -- Returns a mock StatusBar when the addon calls CreateFrame("StatusBar", ...)
    f._statusbar       = nil

    return f
end

_G.CreateFrame = function(frameType, name, parent, template)
    if frameType == "StatusBar" then
        return MockStatusBar(parent)
    end
    return MockFrame()
end

_G.UIParent = MockFrame()

-- C_Spell stubs
_G.C_Spell = {
    GetSpellInfo = function(spellID)
        return { name = "MockSpell_" .. tostring(spellID), iconID = 12345 }
    end,
}

-- Legacy fallback (some paths may still call this)
_G.GetSpellInfo = function(spellID)
    return "MockSpell_" .. tostring(spellID), nil, 12345
end

-- Spec detection
_G.GetSpecialization = function() return 3 end  -- default: Subtlety

-- Haste (percentage, e.g. 19.0 = 19%)
_G.UnitHaste = function(unit) return 0 end

-- Shared globals the addon references
_G.math  = math
_G.table = table
_G.string = string
_G.pairs  = pairs
_G.ipairs = ipairs
_G.type   = type
_G.tostring = tostring
_G.tonumber = tonumber
_G.select   = select
_G.unpack   = unpack or table.unpack
