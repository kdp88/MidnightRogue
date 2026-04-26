--[[
    Display/Animations.lua
    Flash and fade effects for bars approaching expiration.
--]]

local addonName, MR = ...
MR.Animations = {}
local Animations = MR.Animations

local FLASH_MIN_ALPHA = 0.3
local FLASH_MAX_ALPHA = 1.0
local FLASH_SPEED     = 2.0  -- cycles per second

-- Called per bar per update tick. Applies flash when remaining time < bar.flashBelow.
function Animations:UpdateFlash(bar, remaining)
    local threshold = bar.flashBelow
    if not threshold or remaining > threshold then
        -- Ensure alpha is fully reset when not flashing
        if bar._flashing then
            bar:SetAlpha(1.0)
            bar._flashing = false
        end
        return
    end

    bar._flashing = true
    local t = GetTime()
    local pulse = math.abs(math.sin(t * math.pi * FLASH_SPEED))
    local alpha = FLASH_MIN_ALPHA + (FLASH_MAX_ALPHA - FLASH_MIN_ALPHA) * pulse
    bar:SetAlpha(alpha)
end
