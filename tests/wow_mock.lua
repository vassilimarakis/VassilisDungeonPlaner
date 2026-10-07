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
function methods:SetTexture(path) self.texture = path end
function methods:SetVertexColor(...) self.vertexColor = { ... } end
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
function methods:SetHyperlink(value) assert(type(value) == "string"); self.link = value end
for _, name in ipairs({ "SetPoint", "ClearAllPoints", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetFont", "SetTextColor", "SetJustifyH", "SetJustifyV", "SetWordWrap", "SetAlpha", "EnableMouseWheel", "SetAutoFocus", "SetMaxBytes", "SetMaxLetters", "SetMultiLine", "EnableMouse", "SetColorTexture", "SetFrameStrata", "SetScale", "SetMovable", "SetClampedToScreen", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "RegisterForClicks", "RegisterEvent", "SetOwner" }) do
    methods[name] = function() end
end
UIParent = frame("Frame")
UIParent:SetSize(1920, 1080)
Minimap = frame("Frame", nil, UIParent)
GameTooltip = frame("Frame", nil, UIParent)
function StaticPopup_Show(key) assert(StaticPopupDialogs[key]) end
function click(widget) assert(widget.scripts.OnClick, "Missing click handler"); widget.scripts.OnClick(widget, "LeftButton") end

-- Loot events and delayed item metadata for recording/transfer integration tests.
instanceName, instanceKind, instanceMap, instanceDifficulty = "World", "none", 0, 0
function GetInstanceInfo() return instanceName, instanceKind, instanceDifficulty, "Normal", 40, 0, false, instanceMap end
itemData, itemRequests = {}, {}
C_Item = {
    GetItemInfo = function(item)
        local id = tonumber(tostring(item):match("item:(%d+)") or item)
        local data = itemData[id]
        if data then return data.name, nil, data.quality, 60, 60, "Armor", "Cloth", 1, "", data.icon or 134400 end
    end,
    RequestLoadItemDataByID = function(id) itemRequests[id] = true end,
}
function SetLootLocale(locale)
    if locale == "deDE" then
        LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE = "Ihr erhaltet Beute: %s.", "Ihr erhaltet Beute: %sx%d."
        LOOT_ITEM, LOOT_ITEM_MULTIPLE = "%s erhält Beute: %s.", "%s erhält Beute: %sx%d."
    else
        LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %s.", "You receive loot: %sx%d."
        LOOT_ITEM, LOOT_ITEM_MULTIPLE = "%s receives loot: %s.", "%s receives loot: %sx%d."
    end
end
SetLootLocale(clientLocale)
function enterInstance(name, kind, map)
    instanceName, instanceKind, instanceMap = name, kind, map
    GB.Loot.frame.scripts.OnEvent(nil, "ZONE_CHANGED_NEW_AREA")
end
function lootLink(id) return "|cff0070dd|Hitem:" .. id .. ":0:0:0:0:0:0:0|h[Item " .. id .. "]|h|r" end
function loot(id, player, quantity, lineID)
    local link = lootLink(id)
    local message
    if player == "self" then
        message = quantity > 1 and string.format(LOOT_ITEM_SELF_MULTIPLE, link, quantity) or string.format(LOOT_ITEM_SELF, link)
    else
        message = quantity > 1 and string.format(LOOT_ITEM_MULTIPLE, player, link, quantity) or string.format(LOOT_ITEM, player, link)
    end
    GB.Loot.frame.scripts.OnEvent(nil, "CHAT_MSG_LOOT", message, "", "", "", "", "", 0, 0, "", 0, lineID)
end
