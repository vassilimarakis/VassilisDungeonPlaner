-- Minimal offline WoW API for localization and UI interaction tests.
clientLocale, playerName, playerGuild = "deDE", "Organizer", nil
now = os.time({ year = 2026, month = 10, day = 6, hour = 12, min = 0, sec = 0 })
date, time = os.date, os.time
function GetLocale() return clientLocale end
function GetServerTime() return now end
function GetTime() return now end
function GetNormalizedRealmName() return "TestRealm" end
GetRealmName = GetNormalizedRealmName
function UnitFullName() return playerName, "TestRealm" end
function UnitClass() return "Priest", "PRIEST" end
function UnitLevel() return 60 end
function GetGuildInfo() return playerGuild end
function GetCurrentRegion() return 3 end
function GetNumGuildMembers() return 0 end
function InCombatLockdown() return false end
STANDARD_TEXT_FONT = "test-font"
UISpecialFrames, StaticPopupDialogs, SlashCmdList, frames = {}, {}, {}, {}
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 } }
chat, whispers, packets, timers = {}, {}, {}, {}
function print(message) chat[#chat + 1] = message end
C_Timer = { After = function(delay, callback) timers[#timers + 1] = callback end }
C_GuildInfo = { GuildRoster = function() end }
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendChatMessage = function(message, channel, language, target)
        assert(#message <= 255, "Whisper exceeds the chat limit")
        whispers[#whispers + 1] = { message = message, target = target }
    end,
    SendAddonMessageLogged = function(prefix, message, channel, target)
        packets[#packets + 1] = { prefix = prefix, message = message, channel = channel, target = target }
        return true
    end,
}
local methods = {}
local function frame(kind, name, parent)
    local result = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, shown = true, textValue = "", width = 100, height = 30, level = 1, scroll = 0 }, { __index = methods })
    frames[#frames + 1] = result
    if name then assert(not _G[name], "Duplicate named frame " .. name); _G[name] = result end
    return result
end
CreateFrame = frame
function methods:CreateFontString() return frame("FontString", nil, self) end
function methods:CreateTexture() return frame("Texture", nil, self) end
function methods:SetText(value)
    assert(type(value) == "string" or type(value) == "number", "SetText expects a string or number")
    local changed = self.textValue ~= tostring(value)
    self.textValue = tostring(value)
    if changed and self.kind == "EditBox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function methods:GetText() return self.textValue end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(level) self.level = level end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:SetFocus() self.focus = true; if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end end
function methods:ClearFocus() self.focus = false; if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
function methods:HasFocus() return self.focus end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:Show()
    local changed = not self.shown
    self.shown = true
    if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local changed = self.shown
    self.shown = false
    if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll end
function methods:GetNumLines() return 1 end
function methods:SetScrollChild(child) self.child = child end
function methods:AddLine(value) assert(type(value) == "string") end
for _, name in ipairs({ "SetPoint", "ClearAllPoints", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetFont", "SetTextColor", "SetJustifyH", "SetJustifyV", "SetWordWrap", "SetAlpha", "EnableMouseWheel", "SetAutoFocus", "SetMaxBytes", "SetMaxLetters", "SetMultiLine", "EnableMouse", "SetColorTexture", "SetFrameStrata", "SetScale", "SetMovable", "SetClampedToScreen", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "RegisterForClicks", "RegisterEvent", "SetOwner" }) do
    methods[name] = function() end
end
UIParent = frame("Frame")
UIParent:SetSize(1920, 1080)
Minimap = frame("Frame", nil, UIParent)
GameTooltip = frame("Frame", nil, UIParent)
function StaticPopup_Show(key) assert(StaticPopupDialogs[key]) end
function click(widget) assert(widget.scripts.OnClick, "Missing click handler"); widget.scripts.OnClick(widget, "LeftButton") end
