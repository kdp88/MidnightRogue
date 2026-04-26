--[[
    Config/Profiles.lua
    Profile switching on login/reload.
    Profiles are named after specs: "Subtlety", "Assassination", "Outlaw".
    Switching spec mid-session requires /reload — see README.md.
--]]

local addonName, MR = ...
MR.Profiles = {}
local Profiles = MR.Profiles

function Profiles:ApplySpecProfile(specName)
    if not MR.db then return end
    -- Switch AceDB profile to the spec name
    -- AceDB creates the profile if it doesn't exist, seeding from defaults
    local ok, err = pcall(function()
        MR.db:SetProfile(specName)
    end)
    if not ok then
        print("|cFFFF4444[MidnightRogue] Failed to switch to profile '" .. specName .. "': " .. tostring(err) .. "|r")
    else
        print("|cFF00FF88[MidnightRogue] Loaded profile: " .. specName .. "|r")
    end
end

function Profiles:GetCurrentProfileName()
    if MR.db then return MR.db:GetCurrentProfile() end
    return "Unknown"
end
