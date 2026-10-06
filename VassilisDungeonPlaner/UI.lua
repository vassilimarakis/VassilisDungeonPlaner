local _, GB = ...
local L = GB.L
local UI = { filter = "ALL", search = "", rows = {}, people = {}, history = false }
GB.UI = UI
local localizedLabels = {}
local function textKey(key) return { key = key } end
local function setLocalizedText(widget, key)
    localizedLabels[widget] = key
    widget:SetText(L(key))
end
local C = {
    bg = { 0.035, 0.045, 0.065, 1 }, panel = { 0.058, 0.073, 0.099, 1 },
    row = { 0.08, 0.098, 0.13, 1 }, border = { 0.18, 0.21, 0.26, 1 },
    gold = { 0.89, 0.73, 0.43, 1 }, muted = { 0.57, 0.64, 0.73, 1 },
    white = { 0.91, 0.93, 0.96, 1 }, green = { 0.40, 0.81, 0.64, 1 }, red = { 0.94, 0.46, 0.46, 1 },
}
local roleKeys = { TANK = "ROLE_TANK", HEALER = "ROLE_HEALER", DAMAGER = "ROLE_DAMAGE" }
local roleNames = GB.Locale.Names(roleKeys)
local activityKeys = { RAID = "ACTIVITY_RAID", DUNGEON = "ACTIVITY_DUNGEON", OTHER = "ACTIVITY_OTHER" }
local activityNames = GB.Locale.Names(activityKeys)
local statusNames = GB.Locale.Names({ NONE = "STATUS_NONE", INVITED = "STATUS_INVITED", PENDING = "STATUS_PENDING", CONFIRMED = "STATUS_CONFIRMED", BENCH = "STATUS_BENCH", MAYBE = "STATUS_MAYBE", NO = "STATUS_NO" })
local statusColors = { CONFIRMED = C.green, NO = C.red, MAYBE = C.gold, BENCH = C.gold }
local weekdays = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }
local unpack = unpack or table.unpack

local function box(parent, x, y, w, h, color, name, kind)
    local f = CreateFrame(kind or "Frame", name, parent, "BackdropTemplate")
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetSize(w, h)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(unpack(color or C.panel))
    f:SetBackdropBorderColor(unpack(C.border))
    return f
end
local function label(parent, x, y, text, size, color, width)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont(STANDARD_TEXT_FONT, size or 13, "")
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetTextColor(unpack(color or C.white))
    f:SetJustifyH("LEFT")
    f:SetJustifyV("TOP")
    if width then f:SetWidth(width) end
    if type(text) == "table" then setLocalizedText(f, text.key)
    else f:SetText(text or "") end
    return f
end
local function button(parent, x, y, w, h, text, callback, accent)
    local b = box(parent, x, y, w, h, accent and { 0.24, 0.19, 0.115, 1 } or C.row, nil, "Button")
    b.text = label(b, 0, 0, text, 12, accent and C.gold or C.white)
    b.text:ClearAllPoints(); b.text:SetPoint("CENTER")
    b.text:SetSize(w - 8, h - 4); b.text:SetJustifyH("CENTER"); b.text:SetJustifyV("MIDDLE"); b.text:SetWordWrap(false)
    b:SetScript("OnClick", callback)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.gold)) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(self.selected and C.gold or C.border)) end)
    return b
end
local function selected(b, enabled)
    b.selected = enabled
    b:SetBackdropBorderColor(unpack(enabled and C.gold or C.border))
    b.text:SetTextColor(unpack(enabled and C.gold or C.white))
end
local function active(b, enabled)
    b:SetEnabled(enabled)
    b:SetAlpha(enabled and 1 or 0.4)
end
local function input(parent, x, y, w, h, max, multiline)
    local shell = box(parent, x, y, w, h, C.bg)
    local viewport
    if multiline then
        viewport = CreateFrame("ScrollFrame", nil, shell)
        viewport:SetPoint("TOPLEFT", 9, -7); viewport:SetSize(w - 18, h - 14)
    end
    local e = CreateFrame("EditBox", nil, viewport or shell)
    if multiline then
        e:SetPoint("TOPLEFT", 0, 0); e:SetSize(w - 18, h - 14); viewport:SetScrollChild(e)
        viewport:EnableMouseWheel(true)
        viewport:SetScript("OnMouseWheel", function(self, delta)
            self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScroll() - delta * 34, math.max(0, e:GetHeight() - self:GetHeight()))))
        end)
        e:SetScript("OnTextChanged", function(self)
            self:SetHeight(math.max(h - 14, self:GetNumLines() * 17 + 4))
            viewport:SetVerticalScroll(math.min(viewport:GetVerticalScroll(), math.max(0, self:GetHeight() - viewport:GetHeight())))
        end)
        e:SetScript("OnCursorChanged", function(_, _, cursorY, _, cursorHeight)
            local top, offset = -cursorY, viewport:GetVerticalScroll()
            if top < offset then viewport:SetVerticalScroll(top)
            elseif top + cursorHeight > offset + viewport:GetHeight() then viewport:SetVerticalScroll(top + cursorHeight - viewport:GetHeight()) end
        end)
    else
        e:SetPoint("TOPLEFT", 9, -7); e:SetPoint("BOTTOMRIGHT", -9, 7)
    end
    e:SetFont(STANDARD_TEXT_FONT, 13, "")
    e:SetTextColor(unpack(C.white))
    e:SetAutoFocus(false)
    -- The byte buffer also needs room for its terminator; otherwise the last
    -- digit cannot be typed (20:0 / 4). Keep the visible character limit exact.
    e:SetMaxBytes(max + 1); e:SetMaxLetters(max)
    e:SetMultiLine(multiline or false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if not multiline then e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
    e.shell = shell
    if multiline then
        e:SetJustifyV("TOP")
        e.hint = label(shell, 10, 8, textKey("DESCRIPTION_HINT"), 13, C.muted, w - 20)
        local hovered = {}
        local function appearance()
            local focus, hover = e:HasFocus(), next(hovered) ~= nil
            shell:SetBackdropBorderColor(unpack(focus and C.gold or (hover and C.white or C.border)))
            shell:SetBackdropColor(unpack((focus or hover) and C.row or C.bg))
            e.hint:SetShown(e:GetText() == "" and not focus)
            if e.stateLabel then
                e.stateLabel:SetText(focus and L("INPUT_ACTIVE") or (hover and L("CLICK_WRITE") or L("CLICK_WRITE_IDLE")))
                e.stateLabel:SetTextColor(unpack(focus and C.gold or (hover and C.white or C.muted)))
            end
        end
        e.updateAppearance = appearance
        for _, surface in ipairs({ shell, viewport, e }) do
            surface:EnableMouse(true)
            surface:SetScript("OnEnter", function(self) hovered[self] = true; appearance() end)
            surface:SetScript("OnLeave", function(self) hovered[self] = nil; appearance() end)
        end
        -- Padding and the empty part of the scroll area must focus the same editor.
        shell:SetScript("OnMouseDown", function() e:SetFocus() end)
        viewport:SetScript("OnMouseDown", function() e:SetFocus() end)
        e:SetScript("OnEditFocusGained", appearance)
        e:SetScript("OnEditFocusLost", appearance)
        local changed = e:GetScript("OnTextChanged")
        e:SetScript("OnTextChanged", function(self) changed(self); appearance() end)
        shell:SetScript("OnHide", function() hovered = {}; e:ClearFocus(); appearance() end)
    end
    return e
end
local function scroll(parent, x, y, w, h)
    local f = CreateFrame("ScrollFrame", nil, parent)
    f:SetPoint("TOPLEFT", x, -y); f:SetSize(w, h)
    local child = CreateFrame("Frame", nil, f)
    child:SetPoint("TOPLEFT", 0, 0); child:SetSize(w - 10, h); f:SetScrollChild(child)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScroll() - delta * 48, math.max(0, child:GetHeight() - self:GetHeight()))))
    end)
    local track = f:CreateTexture(nil, "OVERLAY")
    track:SetColorTexture(unpack(C.border)); track:SetPoint("TOPRIGHT", -1, 0); track:SetSize(3, h)
    f.thumb = f:CreateTexture(nil, "OVERLAY")
    f.thumb:SetColorTexture(unpack(C.gold)); f.thumb:SetSize(3, h)
    f:SetScript("OnVerticalScroll", function(self, offset)
        local height = self:GetHeight()
        local thumb = math.max(20, height * math.min(1, height / math.max(1, child:GetHeight())))
        self.thumb:SetHeight(thumb); self.thumb:ClearAllPoints()
        local range = math.max(1, child:GetHeight() - height)
        self.thumb:SetPoint("TOPRIGHT", -1, -(height - thumb) * offset / range)
    end)
    return f, child
end
local function resizeScroll(f, child, height)
    child:SetHeight(math.max(f:GetHeight(), height))
    f:SetVerticalScroll(math.min(f:GetVerticalScroll(), math.max(0, child:GetHeight() - f:GetHeight())))
    local handler = f:GetScript("OnVerticalScroll")
    handler(f, f:GetVerticalScroll())
end
local function shortName(name) return name:match("^([^-]+)") or name end
local function when(stamp)
    local d = date("*t", stamp)
    return L(weekdays[d.wday]) .. ", " .. date(L("DATE_SHORT"), stamp) .. " · " .. date("%H:%M", stamp)
end
function UI.Notify(message, error)
    if UI.toast then
        UI.toast:SetText(message or "")
        UI.toast:SetTextColor(unpack(error and C.red or C.green))
    elseif message then GB.Print(message) end
end
local function outcome(record, err)
    if not record then UI.Notify(err or L("ACTION_FAILED"), true); return end
    UI.Notify(L("SAVED_SHARED"))
    UI.Refresh()
end
function UI.Reset()
    UI.selected = nil
    if UI.overlay then UI.overlay:Hide() end
    if UI.guestOverlay then UI.guestOverlay:Hide() end
    if UI.inboxOverlay then UI.inboxOverlay:Hide() end
end

local function makeEventRow(index)
    local r = box(UI.listChild, 0, (index - 1) * 98, 306, 89, C.row, nil, "Button")
    r.date = label(r, 14, 12, "", 12, C.gold, 276)
    r.title = label(r, 14, 33, "", 16, C.white, 276); r.title:SetHeight(20)
    r.info = label(r, 14, 62, "", 11, C.muted, 276)
    r:SetScript("OnClick", function(self)
        UI.selected = self.eventId
        UI.personScroll:SetVerticalScroll(0)
        UI.Refresh()
    end)
    r:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.gold)) end)
    r:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(self.eventId == UI.selected and C.gold or C.border)) end)
    UI.rows[index] = r
    return r
end
local function makePerson(index)
    local row = box(UI.personChild, 0, (index - 1) * 43, 618, 38, C.row, nil, "Button")
    row.name = label(row, 12, 11, "", 13, C.white, 220); row.name:SetHeight(17); row.name:SetWordWrap(false)
    row.levelText = label(row, 245, 12, "", 12, C.muted, 49)
    row.role = label(row, 306, 12, "", 12, C.muted, 68)
    row.status = label(row, 390, 12, "", 11, C.gold, 149)
    row.hint = label(row, 546, 13, "", 10, C.muted, 62)
    row:SetScript("OnClick", function(self) if self.editable then UI.OpenGuest(self.player) end end)
    row:SetScript("OnEnter", function(self)
        if self.editable then self:SetBackdropBorderColor(unpack(C.gold)) end
        local s = GB.model and GB.model:GetSignup(self.eventId, self.player)
        if not s then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self.player, 1, 1, 1)
        GameTooltip:AddLine(L("LEVEL_TOOLTIP", s.level > 0 and s.level or L("UNKNOWN")), 0.7, 0.75, 0.8)
        if s.note ~= "" then GameTooltip:AddLine(L("NOTE_TOOLTIP", s.note), 1, 1, 1, true) end
        if s.kind == "M" then GameTooltip:AddLine(s.source == "WHISPER" and L("WHISPER_REPLY") or L("ADDED_BY_LEAD"), 0.7, 0.75, 0.8) end
        if self.editable then GameTooltip:AddLine(L("CLICK_EDIT"), 0.89, 0.73, 0.43) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)); GameTooltip:Hide() end)
    UI.people[index] = row
    return row
end

function UI.Refresh()
    if not UI.frame or not UI.frame:IsShown() then return end
    UI.languageButton.text:SetText(L("LANGUAGE_BUTTON", GB.Locale.PreferenceName()))
    UI.historyButton.text:SetText(L(UI.history and "HISTORY_ON" or "HISTORY_OFF"))
    local model = GB.model
    UI.guild:SetText((GB.guildName and (L("GUILD_GUESTS", GB.guildName)) or L("SOLO_HEADING")) .. "  /  WoW: Forever")
    if UI.inboxButton then UI.inboxButton.text:SetText(L("INVITE_COUNT", model and #GB.Guests.Inbox() or 0)) end
    UI.syncText:SetText(GB.SyncStatus())
    for key, b in pairs(UI.filters) do selected(b, UI.filter == key) end
    active(UI.newButton, model ~= nil)
    local events = model and model:Events(UI.filter, UI.search, UI.history) or {}
    local found = false
    for _, e in ipairs(events) do if e.event == UI.selected then found = true end end
    if not found then UI.selected = events[1] and events[1].event or nil end
    for i, e in ipairs(events) do
        local row = UI.rows[i] or makeEventRow(i)
        local counts = model:Counts(e.event)
        row.eventId = e.event
        row.date:SetText(when(e.start))
        row.title:SetText(e.title)
        row.info:SetText(e.cancelled == 1 and L("CANCELLED_CAPS") or (L("EVENT_ROW", activityNames[e.activity], counts.confirmed, e.capacity, counts.yes)))
        row.info:SetTextColor(unpack(e.cancelled == 1 and C.red or C.muted))
        row:SetBackdropBorderColor(unpack(e.event == UI.selected and C.gold or C.border)); row:Show()
    end
    for i = #events + 1, #UI.rows do UI.rows[i]:Hide() end
    resizeScroll(UI.listScroll, UI.listChild, #events * 98)
    UI.count:SetText(L("EVENT_COUNT", #events))
    UI.noEvents:SetShown(#events == 0)
    UI.noEvents:SetText(L("NO_EVENTS"))
    local e = model and UI.selected and model:GetEvent(UI.selected)
    UI.detail:SetShown(e ~= nil)
    UI.emptyDetail:SetShown(e == nil)
    if not e then return end
    local own = GB.Core.SamePlayer(e.author, GB.actor)
    local open = e.cancelled == 0 and e.start > GB.Now()
    local counts = model:Counts(e.event)
    UI.eventTitle:SetText(e.title)
    UI.eventType:SetText(activityNames[e.activity])
    UI.eventWhen:SetText(L("EVENT_WHEN", when(e.start), e.capacity))
    UI.organizer:SetText(L(e.scope == "" and "ORGANIZER_PRIVATE" or "ORGANIZER_GUILD", e.author))
    UI.description:SetText(e.note ~= "" and e.note or L("DESCRIPTION_EMPTY"))
    UI.rolesSummary:SetText(L("ROLE_COUNTS", counts.TANK, counts.HEALER, counts.DAMAGER))
    UI.capacity:SetText(L("CONFIRMED_COUNT", counts.confirmed, e.capacity))
    local current = model:GetSignup(e.event, GB.actor)
    local status = model:Status(e.event, GB.actor)
    UI.myStatus:SetText(e.cancelled == 1 and L("EVENT_CANCELLED") or statusNames[status])
    UI.myStatus:SetTextColor(unpack(e.cancelled == 1 and C.red or statusColors[status] or C.muted))
    UI.mySummary:SetText(current and (roleNames[current.role] .. "  ·  " .. (current.note ~= "" and current.note or L("NO_NOTE"))) or L("CLICK_SIGNUP"))
    UI.myEditHint:SetText(current and L("EDIT_ARROW") or L("SIGNUP_ARROW"))
    active(UI.mySignup, open)
    local people = model:Participants(e.event)
    UI.peopleLabel:SetText(L("PARTICIPANT_COUNT", #people))
    UI.addGuest:SetShown(own); active(UI.addGuest, open)
    UI.noPeople:SetShown(#people == 0)
    for i, s in ipairs(people) do
        local row = UI.people[i] or makePerson(i)
        local player = GB.Core.Player(s)
        local state = model:Status(e.event, player)
        row.player, row.eventId = player, e.event
        row.editable = open and (own or GB.Core.SamePlayer(player, GB.actor))
        row.name:SetText(GB.Core.SamePlayer(player, GB.actor) and L("PLAYER_SELF", shortName(player)) or shortName(player))
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[s.class]
        if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(unpack(C.white)) end
        row.role:SetText(roleNames[s.role])
        row.levelText:SetText(s.level > 0 and tostring(s.level) or "—")
        row.status:SetText(statusNames[state]); row.status:SetTextColor(unpack(statusColors[state] or C.muted))
        row.hint:SetText(row.editable and L("CHANGE_ARROW") or "")
        row:Show()
    end
    for i = #people + 1, #UI.people do UI.people[i]:Hide() end
    resizeScroll(UI.personScroll, UI.personChild, math.max(0, #people * 43 - 5))
    UI.edit:SetShown(own); UI.cancel:SetShown(own)
    active(UI.edit, open); active(UI.cancel, open)
    UI.ownerHint:SetText(own and L("LEAD_HINT") or L("SELF_ONLY"))
end

local function parseTime(dayText, hourText)
    local day, month, year = dayText:match("^(%d%d?)%.(%d%d?)%.(%d%d%d%d)$")
    local hour, minute = hourText:match("^(%d%d?):(%d%d)$")
    day, month, year, hour, minute = tonumber(day), tonumber(month), tonumber(year), tonumber(hour), tonumber(minute)
    if not day or not hour or day < 1 or day > 31 or month < 1 or month > 12 or hour > 23 or minute > 59 then return nil end
    local ok, stamp = pcall(time, { year = year, month = month, day = day, hour = hour, min = minute, sec = 0 })
    if not ok or not stamp then return nil end
    local check = date("*t", stamp)
    if check.day ~= day or check.month ~= month or check.year ~= year or check.hour ~= hour or check.min ~= minute then return nil end
    return stamp
end
UI.ParseTime = parseTime
local months = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local function setEditorDay(ed, stamp)
    ed.dayStamp = stamp
    ed.dayText = date("%d.%m.%Y", stamp)
    ed.day.text:SetText(L(weekdays[date("*t", stamp).wday]) .. ", " .. date(L("DATE_FULL"), stamp))
end
local function openDatePicker(ed)
    if not ed.datePicker then
        local cover = box(ed, 0, 0, 570, 565, { 0.015, 0.02, 0.03, 0.93 }, "GuildBoardDatePicker")
        ed.datePicker = cover
        cover:SetFrameLevel(ed:GetFrameLevel() + 20); cover:EnableMouse(true)
        table.insert(UISpecialFrames, "GuildBoardDatePicker")
        cover:SetScript("OnMouseDown", function() cover:Hide() end)
        local panel = box(cover, 112, 85, 346, 395, C.panel)
        panel:EnableMouse(true)
        label(panel, 18, 18, textKey("SELECT_DATE"), 19, C.white)
        button(panel, 300, 12, 28, 26, "X", function() cover:Hide() end)
        cover.heading = label(panel, 67, 66, "", 16, C.gold, 212)
        local function choose(stamp)
            setEditorDay(ed, stamp)
            cover:Hide()
        end
        local function render()
            cover.heading:SetText(L(months[cover.month]) .. " " .. cover.year)
            local first = time({ year = cover.year, month = cover.month, day = 1, hour = 12, min = 0, sec = 0 })
            local offset = (date("*t", first).wday + 5) % 7 -- Monday is the first column.
            local today = date("%d.%m.%Y", GB.Now())
            for i, b in ipairs(cover.days) do
                b.stamp = first + (i - offset - 1) * 86400
                local d = date("*t", b.stamp)
                b.inMonth = d.month == cover.month and d.year == cover.year
                b.text:SetText(tostring(d.day))
                local dayText = date("%d.%m.%Y", b.stamp)
                selected(b, dayText == ed.dayText)
                b:SetBackdropColor(unpack(b.selected and { 0.24, 0.19, 0.115, 1 } or (b.inMonth and C.row or C.bg)))
                b.text:SetTextColor(unpack((b.selected or dayText == today) and C.gold or (b.inMonth and C.white or C.muted)))
                b:Show()
            end
            active(cover.previous, cover.year > 1970 or cover.month > 1)
            active(cover.next, cover.year < 9999 or cover.month < 12)
        end
        local function move(delta)
            cover.month = cover.month + delta
            if cover.month == 0 then cover.month, cover.year = 12, cover.year - 1
            elseif cover.month == 13 then cover.month, cover.year = 1, cover.year + 1 end
            render()
        end
        cover.previous = button(panel, 18, 58, 32, 30, "<", function() move(-1) end)
        cover.next = button(panel, 296, 58, 32, 30, ">", function() move(1) end)
        cover.days = {}
        for i, name in ipairs({ "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN" }) do
            local day = label(panel, 18 + (i - 1) * 45, 104, textKey(name), 11, C.muted, 40)
            day:SetHeight(16); day:SetJustifyH("CENTER"); day:SetWordWrap(false)
        end
        for i = 1, 42 do
            cover.days[i] = button(panel, 18 + ((i - 1) % 7) * 45, 126 + math.floor((i - 1) / 7) * 33, 40, 28, "", function(self) choose(self.stamp) end)
        end
        local function relativeDay(delta)
            local d = date("*t", GB.Now())
            -- Noon avoids skipping or repeating a day around a DST clock change.
            local noon = time({ year = d.year, month = d.month, day = d.day, hour = 12, min = 0, sec = 0 })
            choose(noon + delta * 86400)
        end
        cover.today = button(panel, 18, 344, 150, 32, textKey("TODAY"), function() relativeDay(0) end)
        cover.tomorrow = button(panel, 178, 344, 150, 32, textKey("TOMORROW"), function() relativeDay(1) end)
        cover.render = render
    end
    for _, field in ipairs({ ed.title, ed.hour, ed.capacity, ed.note }) do field:ClearFocus() end
    local d = date("*t", ed.dayStamp)
    ed.datePicker.year, ed.datePicker.month = d.year, d.month
    ed.datePicker.render()
    ed.datePicker:Show()
end
function UI.OpenEditor(id)
    if not GB.model then return end
    if not UI.editor then
        UI.overlay = box(UI.frame, 0, 0, 1060, 720, { 0.015, 0.02, 0.03, 0.96 })
        UI.overlay:SetFrameLevel(UI.frame:GetFrameLevel() + 30); UI.overlay:EnableMouse(true)
        local ed = box(UI.overlay, 245, 72, 570, 565, C.panel, "GuildBoardEditor")
        UI.editor = ed
        table.insert(UISpecialFrames, "GuildBoardEditor")
        local function closeFields()
            if ed.datePicker then ed.datePicker:Hide() end
            for _, field in ipairs({ ed.title, ed.hour, ed.capacity, ed.note }) do field:ClearFocus() end
        end
        ed:SetScript("OnHide", function() closeFields(); UI.overlay:Hide() end)
        UI.overlay:SetScript("OnHide", closeFields)
        ed.heading = label(ed, 24, 24, textKey("CREATE_EVENT"), 23, C.white)
        label(ed, 24, 69, textKey("TITLE"), 11, C.muted)
        ed.title = input(ed, 24, 89, 522, 34, 80)
        label(ed, 24, 143, textKey("ACTIVITY"), 11, C.muted)
        ed.kinds = {}
        local function kindChoice(key)
            ed.activity = key
            for k, b in pairs(ed.kinds) do selected(b, k == key) end
        end
        for i, k in ipairs({ "RAID", "DUNGEON", "OTHER" }) do
            ed.kinds[k] = button(ed, 24 + (i - 1) * 176, 164, 170, 32, textKey(activityKeys[k]), function()
                kindChoice(k)
                ed.capacity:SetText(k == "DUNGEON" and "5" or "40")
            end)
        end
        ed.kindChoice = kindChoice
        label(ed, 24, 218, textKey("DATE_LABEL"), 11, C.muted)
        label(ed, 225, 218, textKey("TIME_LABEL"), 11, C.muted)
        label(ed, 403, 218, textKey("CAPACITY_LABEL"), 11, C.muted)
        ed.day = button(ed, 24, 239, 185, 34, "", function() openDatePicker(ed) end)
        ed.hour = input(ed, 225, 239, 160, 34, 5)
        ed.capacity = input(ed, 403, 239, 143, 34, 2)
        label(ed, 24, 295, textKey("DESCRIPTION_LABEL"), 11, C.muted)
        ed.note = input(ed, 24, 317, 522, 112, 500, true)
        ed.note.stateLabel = label(ed, 382, 295, "", 11, C.muted, 164)
        ed.note.updateAppearance()
        ed.share = button(ed, 24, 440, 295, 25, "", function(self)
            if not ed.eventId and GB.guildKey then ed.private = not ed.private; self.text:SetText(ed.private and L("VISIBILITY_PRIVATE") or L("VISIBILITY_GUILD")) end
        end)
        ed.error = label(ed, 24, 473, "", 12, C.red, 520)
        button(ed, 24, 516, 170, 32, textKey("BACK"), function() UI.overlay:Hide() end)
        ed.save = button(ed, 346, 516, 200, 32, textKey("SAVE_EVENT"), function()
            local stamp = parseTime(ed.dayText, ed.hour:GetText())
            local capacity = tonumber(ed.capacity:GetText())
            if not stamp then ed.error:SetText(L("INVALID_DATE")); return end
            if not capacity or capacity < 1 or capacity > 40 or capacity ~= math.floor(capacity) then ed.error:SetText(L("INVALID_CAPACITY")); return end
            if GB.Core.Trim(ed.title:GetText()) == "" then ed.error:SetText(L("TITLE_REQUIRED")); return end
            local r, err = GB.model:SaveEvent(ed.eventId, ed.title:GetText(), ed.activity, stamp, capacity, ed.note:GetText(), ed.private and "" or GB.guildKey)
            if not r then ed.error:SetText(err); return end
            UI.selected = r.event
            UI.filter, UI.search = "ALL", ""
            UI.searchBox:SetText("")
            UI.overlay:Hide(); outcome(r)
        end, true)
    end
    local ed, e = UI.editor, id and GB.model:GetEvent(id)
    local tomorrow = date("*t", GB.Now() + 86400)
    tomorrow.hour, tomorrow.min, tomorrow.sec = 20, 0, 0
    local stamp = e and e.start or time(tomorrow)
    ed.eventId = id
    ed.private = (e and e.scope == "") or (not e and not GB.guildKey)
    ed.share.text:SetText(ed.private and L("VISIBILITY_PRIVATE") or L("VISIBILITY_GUILD"))
    active(ed.share, not id and GB.guildKey ~= nil)
    ed.heading:SetText(e and L("EDIT_EVENT") or L("PLAN_TOGETHER"))
    ed.title:SetText(e and e.title or "")
    setEditorDay(ed, stamp); ed.hour:SetText(date("%H:%M", stamp))
    ed.capacity:SetText(tostring(e and e.capacity or 40))
    ed.note:SetText(e and e.note or "")
    ed.kindChoice(e and e.activity or "RAID"); ed.error:SetText("")
    if ed.datePicker then ed.datePicker:Hide() end
    UI.overlay:Show(); ed:Show(); ed.title:SetFocus()
end

function UI.OpenGuest(player)
    local e = GB.model and UI.selected and GB.model:GetEvent(UI.selected)
    if not e or e.cancelled == 1 or e.start <= GB.Now() then return end
    local owner = GB.Core.SamePlayer(e.author, GB.actor)
    local selfEdit = player and GB.Core.SamePlayer(player, GB.actor)
    if not owner and not selfEdit then return end
    if not UI.guestEditor then
        UI.guestOverlay = box(UI.frame, 0, 0, 1060, 720, { 0.015, 0.02, 0.03, 0.96 })
        UI.guestOverlay:SetFrameLevel(UI.frame:GetFrameLevel() + 30); UI.guestOverlay:EnableMouse(true)
        local ed = box(UI.guestOverlay, 245, 70, 570, 580, C.panel, "GuildBoardGuestEditor")
        UI.guestEditor = ed
        table.insert(UISpecialFrames, "GuildBoardGuestEditor")
        ed:SetScript("OnHide", function() UI.guestOverlay:Hide() end)
        ed.heading = label(ed, 24, 24, "", 23, C.white)
        label(ed, 24, 72, textKey("CHARACTER_NAME"), 11, C.muted)
        label(ed, 424, 72, textKey("LEVEL"), 11, C.muted)
        ed.nameInput = input(ed, 24, 92, 384, 34, 100)
        ed.levelInput = input(ed, 424, 92, 122, 34, 3)
        ed.identityHint = label(ed, 24, 140, "", 11, C.muted, 522)
        ed.identityHint:SetHeight(30)
        ed.roles, ed.answers, ed.decisions = {}, {}, {}
        local function chooseDecision(value)
            ed.decision = value
            for k, b in pairs(ed.decisions) do selected(b, k == value) end
        end
        local function choose(role, response)
            ed.role, ed.response = role or ed.role, response or ed.response
            for k, b in pairs(ed.roles) do selected(b, k == ed.role) end
            for k, b in pairs(ed.answers) do selected(b, k == ed.response) end
            if ed.response ~= "YES" then chooseDecision(nil) end
            for _, b in pairs(ed.decisions) do active(b, ed.response == "YES") end
        end
        ed.choose, ed.chooseDecision = choose, chooseDecision
        label(ed, 24, 179, textKey("ROLE"), 11, C.muted)
        for i, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
            ed.roles[role] = button(ed, 24 + (i - 1) * 176, 201, 170, 29, textKey(roleKeys[role]), function() choose(role) end)
        end
        label(ed, 24, 247, textKey("RESPONSE_LABEL"), 11, C.muted)
        for i, response in ipairs({ "INVITED", "YES", "MAYBE", "NO" }) do
            local titles = { INVITED = "STATUS_INVITED", YES = "STATUS_YES", MAYBE = "STATUS_MAYBE", NO = "STATUS_NO" }
            ed.answers[response] = button(ed, 24 + (i - 1) * 132, 269, 126, 29, textKey(titles[response]), function() choose(nil, response) end)
        end
        label(ed, 24, 315, textKey("SIGNUP_NOTE"), 11, C.muted)
        ed.note = input(ed, 24, 336, 522, 52, 120, true)
        setLocalizedText(ed.note.hint, "NOTE_EXAMPLE")
        ed.decisionLabel = label(ed, 24, 404, "", 11, C.muted, 522)
        for i, decision in ipairs({ "CONFIRMED", "BENCH", "PENDING" }) do
            local titles = { CONFIRMED = "CONFIRM", BENCH = "STATUS_BENCH", PENDING = "PENDING" }
            ed.decisions[decision] = button(ed, 24 + (i - 1) * 176, 425, 170, 28, textKey(titles[decision]), function() chooseDecision(decision) end)
        end
        ed.error = label(ed, 24, 470, "", 12, C.red, 522); ed.error:SetHeight(43)
        local function save(invite)
            ed.error:SetTextColor(unpack(C.red))
            local event = GB.model and GB.model:GetEvent(ed.eventId)
            if not event then ed.error:SetText(L("EVENT_UNAVAILABLE")); return end
            local isOwner = GB.Core.SamePlayer(event.author, GB.actor)
            local isSelf = ed.player and GB.Core.SamePlayer(ed.player, GB.actor)
            if not isOwner and not isSelf then ed.error:SetText(L("SELF_ONLY")); return end
            local name = GB.Guests.ValidName(ed.nameInput:GetText())
            if not name then ed.error:SetText(L("INVALID_NAME")); return end
            if ed.player and not GB.Core.SamePlayer(ed.player, name) then ed.error:SetText(L("NAME_LOCKED")); return end
            if not isOwner and not GB.Core.SamePlayer(name, GB.actor) then return end
            local rawLevel = GB.Core.Trim(ed.levelInput:GetText())
            local level = isSelf and math.max(0, UnitLevel("player")) or (rawLevel == "" and 0 or tonumber(rawLevel))
            if not level or level < 0 or level > 255 or level ~= math.floor(level) then ed.error:SetText(L("INVALID_LEVEL")); return end
            if isOwner and ed.decision == "CONFIRMED" and ed.response == "YES"
                and GB.model:Status(ed.eventId, name) ~= "CONFIRMED" and GB.model:Counts(ed.eventId).confirmed >= event.capacity then
                ed.error:SetText(L("CAPACITY_FULL")); return
            end
            local r, err
            if isSelf then
                local _, class = UnitClass("player")
                r, err = GB.model:SignUp(ed.eventId, ed.role, ed.response, ed.note:GetText(), class, level)
            else
                r, err = GB.model:SetManual(ed.eventId, name, ed.role, ed.response, ed.note:GetText(), "MANUAL", level)
            end
            if not r then ed.error:SetText(err); return end
            if isOwner and ed.decision and ed.response == "YES" then
                local decided, why = GB.model:Decide(ed.eventId, name, ed.decision)
                if not decided then ed.error:SetText(L("SIGNUP_SAVED_ERROR", why)); return end
            end
            if invite then
                if not isOwner or isSelf then return end
                local sent, message = GB.Guests.Invite(ed.eventId, name)
                if not sent then ed.error:SetText(L("ENTRY_SAVED_ERROR", message)); return end
                UI.Notify(message)
            else outcome(r) end
            UI.guestOverlay:Hide()
        end
        ed.close = button(ed, 24, 528, 120, 32, textKey("CANCEL"), function() UI.guestOverlay:Hide() end)
        ed.save = button(ed, 153, 528, 171, 32, textKey("SAVE"), function() save(false) end, true)
        ed.invite = button(ed, 333, 528, 213, 32, textKey("SEND_INVITE"), function() save(true) end)
        UI.guestOverlay:SetScript("OnHide", function() ed.nameInput:ClearFocus(); ed.levelInput:ClearFocus(); ed.note:ClearFocus() end)
    end
    local ed, old = UI.guestEditor, player and GB.model:GetSignup(e.event, player)
    ed.eventId, ed.player = e.event, player
    ed.heading:SetText(selfEdit and L("EDIT_SIGNUP") or (player and L("EDIT_PARTICIPANT") or L("ADD_PARTICIPANT")))
    ed.nameInput:SetText(player or "")
    ed.nameInput:SetEnabled(not player)
    local level = selfEdit and math.max(0, UnitLevel("player")) or (old and old.level or 0)
    ed.levelInput:SetText(level > 0 and tostring(level) or ""); ed.levelInput:SetEnabled(not selfEdit)
    ed.identityHint:SetText(selfEdit and L("SELF_IDENTITY_HINT")
        or L("GUEST_IDENTITY_HINT"))
    ed.note:SetText(old and old.note or "")
    ed.answers.INVITED:SetShown(not selfEdit)
    for i, response in ipairs({ "YES", "MAYBE", "NO" }) do
        local b = ed.answers[response]
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", ed, "TOPLEFT", selfEdit and (24 + (i - 1) * 176) or (24 + i * 132), -269)
        b:SetWidth(selfEdit and 170 or 126); b.text:SetWidth(selfEdit and 162 or 118)
    end
    ed.chooseDecision(nil)
    local response = old and old.response or (selfEdit and "YES" or "INVITED")
    if selfEdit and response == "INVITED" then response = "YES" end
    ed.choose(old and old.role or "DAMAGER", response)
    ed.decisionLabel:SetText(owner and (L("LEAD_STATUS", statusNames[GB.model:Status(e.event, player or "")]))
        or L("LEAD_DECIDES"))
    for _, b in pairs(ed.decisions) do b:SetShown(owner) end
    ed.invite:SetShown(owner and not selfEdit)
    ed:SetHeight(owner and 580 or 532)
    ed.error:ClearAllPoints(); ed.error:SetPoint("TOPLEFT", ed, "TOPLEFT", 24, owner and -470 or -422)
    for _, item in ipairs({ { ed.close, 24 }, { ed.save, 153 }, { ed.invite, 333 } }) do
        item[1]:ClearAllPoints(); item[1]:SetPoint("TOPLEFT", ed, "TOPLEFT", item[2], owner and -528 or -480)
    end
    ed.error:SetText("")
    UI.guestOverlay:Show(); ed:Show()
    if not player then ed.nameInput:SetFocus() end
end

function UI.OpenInvites()
    if not GB.model then return end
    if not UI.inboxPanel then
        UI.inboxOverlay = box(UI.frame, 0, 0, 1060, 720, { 0.015, 0.02, 0.03, 0.96 })
        UI.inboxOverlay:SetFrameLevel(UI.frame:GetFrameLevel() + 30); UI.inboxOverlay:EnableMouse(true)
        local panel = box(UI.inboxOverlay, 195, 105, 670, 500, C.panel, "GuildBoardInvites")
        UI.inboxPanel = panel
        table.insert(UISpecialFrames, "GuildBoardInvites")
        panel:SetScript("OnHide", function() UI.inboxOverlay:Hide() end)
        label(panel, 24, 24, textKey("YOUR_INVITES"), 23, C.white)
        label(panel, 24, 66, textKey("INVITES_HELP"), 12, C.muted, 620)
        UI.inviteScroll, UI.inviteChild = scroll(panel, 24, 112, 622, 305)
        UI.inviteRows = {}
        UI.inviteEmpty = label(panel, 24, 133, textKey("NO_INVITES"), 14, C.muted, 615)
        button(panel, 24, 448, 170, 32, textKey("CLOSE"), function() UI.inboxOverlay:Hide() end)
    end
    local list = GB.Guests.Inbox()
    UI.inviteEmpty:SetShown(#list == 0)
    for i, item in ipairs(list) do
        local row = UI.inviteRows[i]
        if not row then
            row = box(UI.inviteChild, 0, (i - 1) * 100, 606, 91, C.row)
            row.title = label(row, 12, 12, "", 16, C.white, 575); row.title:SetHeight(20)
            row.detail = label(row, 12, 39, "", 11, C.muted, 575)
            row.accept = button(row, 314, 59, 160, 25, textKey("OPEN_EVENT"), function()
                local ok, err = GB.Guests.Accept(row.eventId)
                if not ok then UI.Notify(err, true); return end
                UI.inboxOverlay:Hide(); UI.searchBox:SetText(""); UI.Refresh()
            end, true)
            row.ignore = button(row, 482, 59, 111, 25, textKey("DISMISS"), function()
                GB.model.data.inbox[row.eventId] = nil; UI.OpenInvites(); UI.Refresh()
            end)
            UI.inviteRows[i] = row
        end
        row.eventId = item.event.event
        row.title:SetText(item.event.title)
        row.detail:SetText(L("INVITE_DETAIL", when(item.event.start), item.owner))
        row:Show()
    end
    for i = #list + 1, #UI.inviteRows do UI.inviteRows[i]:Hide() end
    resizeScroll(UI.inviteScroll, UI.inviteChild, #list * 100)
    UI.inboxOverlay:Show(); UI.inboxPanel:Show()
end

function UI.Relocalize()
    for widget, key in pairs(localizedLabels) do widget:SetText(L(key)) end
    if GameTooltip then GameTooltip:Hide() end
    if UI.toast then UI.toast:SetText("") end
    if UI.editor then
        local ed = UI.editor
        ed.heading:SetText(L(ed.eventId and "EDIT_EVENT" or "PLAN_TOGETHER"))
        ed.share.text:SetText(L(ed.private and "VISIBILITY_PRIVATE" or "VISIBILITY_GUILD"))
        if ed.dayStamp then setEditorDay(ed, ed.dayStamp) end
        if ed.datePicker and ed.datePicker.month then ed.datePicker.render() end
        ed.note.updateAppearance()
        ed.error:SetText("")
    end
    if UI.guestEditor then UI.guestEditor.error:SetText("") end
    local dialog = StaticPopupDialogs.GUILDBOARD_CANCEL
    if dialog then
        dialog.text, dialog.button1, dialog.button2 = L("CANCEL_CONFIRM"), L("CANCEL_EVENT"), L("BACK")
    end
    if UI.languagePanel then UI.languagePanel.refresh() end
    UI.Refresh()
end

function UI.OpenLanguage()
    if not UI.languagePanel then
        local cover = box(UI.frame, 0, 0, 1060, 720, { 0.015, 0.02, 0.03, 0.96 })
        UI.languageOverlay = cover
        cover:SetFrameLevel(UI.frame:GetFrameLevel() + 40); cover:EnableMouse(true)
        local panel = box(cover, 245, 195, 570, 305, C.panel, "GuildBoardLanguage")
        UI.languagePanel = panel
        table.insert(UISpecialFrames, "GuildBoardLanguage")
        panel:SetScript("OnHide", function() cover:Hide() end)
        label(panel, 24, 24, textKey("LANGUAGE_TITLE"), 23, C.white)
        local help = label(panel, 24, 68, textKey("LANGUAGE_HELP"), 13, C.muted, 522)
        help:SetHeight(70)
        panel.buttons = {}
        for i, preference in ipairs({ "auto", "deDE", "enUS" }) do
            local title = preference == "auto" and textKey("LANGUAGE_AUTO") or (preference == "deDE" and "Deutsch" or "English")
            panel.buttons[preference] = button(panel, 24 + (i - 1) * 176, 155, 170, 34, title, function()
                GB.Locale.SetPreference(preference)
            end)
        end
        panel.current = label(panel, 24, 208, "", 13, C.gold, 522)
        panel.refresh = function()
            for preference, b in pairs(panel.buttons) do selected(b, GB.Locale.Preference() == preference) end
            panel.current:SetText(L("LANGUAGE_EFFECTIVE", GB.Locale.Current() == "deDE" and "Deutsch" or "English"))
        end
        button(panel, 376, 253, 170, 32, textKey("CLOSE"), function() cover:Hide() end)
    end
    UI.languagePanel.refresh()
    UI.languageOverlay:Show(); UI.languagePanel:Show()
end

function UI.Create()
    if UI.frame then return end
    local f = box(UIParent, 0, 0, 1060, 720, C.bg, "GuildBoardFrame")
    UI.frame = f
    f:ClearAllPoints(); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    local scale = math.min(1, (UIParent:GetWidth() - 30) / 1060, (UIParent:GetHeight() - 30) / 720)
    f:SetScale(math.max(0.5, scale))
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetScript("OnShow", UI.Refresh)
    table.insert(UISpecialFrames, "GuildBoardFrame")
    label(f, 22, 19, GB.NAME, 14, C.gold)
    label(f, 20, 40, textKey("TAGLINE"), 26, C.white)
    UI.guild = label(f, 22, 77, "", 12, C.muted, 735)
    UI.languageButton = button(f, 780, 76, 219, 27, "", function() UI.OpenLanguage() end)
    UI.newButton = button(f, 828, 35, 171, 36, textKey("NEW_EVENT"), function() UI.OpenEditor() end, true)
    UI.inboxButton = button(f, 653, 35, 161, 36, textKey("INBOX_ZERO"), function() UI.OpenInvites() end)
    button(f, 1011, 13, 29, 27, "X", function() f:Hide() end)
    UI.filters = {}
    local labels = { "FILTER_ALL", "FILTER_RAIDS", "FILTER_DUNGEONS", "FILTER_MINE" }
    for i, key in ipairs({ "ALL", "RAID", "DUNGEON", "MINE" }) do
        UI.filters[key] = button(f, 20 + (i - 1) * 82, 111, 76, 29, textKey(labels[i]), function()
            UI.filter = key; UI.listScroll:SetVerticalScroll(0); UI.Refresh()
        end)
    end
    UI.searchBox = input(f, 20, 153, 322, 31, 80)
    UI.searchBox:SetScript("OnTextChanged", function(self)
        UI.search = self:GetText()
        if UI.searchHint then UI.searchHint:SetShown(UI.search == "") end
        UI.Refresh()
    end)
    -- Keep the placeholder above the input's opaque backdrop.
    UI.searchHint = label(UI.searchBox.shell, 10, 9, textKey("SEARCH_HINT"), 12, C.muted, 302)
    UI.listScroll, UI.listChild = scroll(f, 20, 198, 322, 432)
    UI.noEvents = label(f, 39, 232, "", 15, C.muted, 276)
    UI.count = label(f, 22, 641, "", 11, C.muted, 320)
    UI.historyButton = button(f, 20, 672, 151, 26, textKey("HISTORY_OFF"), function(self)
        UI.history = not UI.history
        self.text:SetText(UI.history and L("HISTORY_ON") or L("HISTORY_OFF"))
        UI.Refresh()
    end)
    button(f, 180, 672, 162, 26, textKey("SYNC"), function() GB.RequestSync() end)
    UI.emptyDetail = label(f, 444, 286, textKey("DETAIL_EMPTY"), 20, C.muted, 490)
    UI.detail = box(f, 364, 111, 676, 544, C.panel)
    local d = UI.detail
    UI.eventTitle = label(d, 20, 19, "", 23, C.white, 478); UI.eventTitle:SetHeight(28)
    UI.eventType = label(d, 513, 25, "", 11, C.gold, 144)
    UI.eventWhen = label(d, 20, 61, "", 13, C.gold, 630)
    UI.organizer = label(d, 20, 84, "", 12, C.muted, 630)
    UI.description = label(d, 20, 111, "", 13, C.white, 630); UI.description:SetHeight(40)
    UI.descriptionArea = CreateFrame("Frame", nil, d)
    UI.descriptionArea:SetPoint("TOPLEFT", 20, -108); UI.descriptionArea:SetSize(630, 44); UI.descriptionArea:EnableMouse(true)
    UI.descriptionArea:SetScript("OnEnter", function(self)
        local e = GB.model and UI.selected and GB.model:GetEvent(UI.selected)
        if e and e.note ~= "" then GameTooltip:SetOwner(self, "ANCHOR_CURSOR"); GameTooltip:SetText(e.note, 1, 1, 1, 1, true); GameTooltip:Show() end
    end)
    UI.descriptionArea:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local metrics = box(d, 20, 164, 636, 36, C.bg)
    UI.rolesSummary = label(metrics, 12, 11, "", 12, C.white, 380)
    UI.capacity = label(metrics, 439, 11, "", 12, C.green, 182)
    UI.mySignup = box(d, 20, 214, 636, 62, C.row, nil, "Button")
    UI.mySignup:SetScript("OnClick", function() UI.OpenGuest(GB.actor) end)
    UI.mySignup:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.gold)) end)
    UI.mySignup:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    label(UI.mySignup, 12, 10, textKey("YOUR_SIGNUP"), 11, C.muted)
    UI.myStatus = label(UI.mySignup, 190, 10, "", 12, C.gold, 270)
    UI.mySummary = label(UI.mySignup, 12, 34, "", 12, C.white, 485)
    UI.mySummary:SetHeight(16); UI.mySummary:SetWordWrap(false)
    UI.myEditHint = label(UI.mySignup, 524, 25, "", 11, C.gold, 100)
    UI.peopleLabel = label(d, 20, 298, textKey("PARTICIPANTS"), 11, C.muted)
    UI.addGuest = button(d, 454, 290, 202, 25, textKey("ADD_GUEST"), function() UI.OpenGuest() end)
    local columns = box(d, 20, 325, 618, 25, C.bg)
    label(columns, 12, 7, textKey("CHARACTER"), 10, C.muted)
    label(columns, 245, 7, textKey("LEVEL"), 10, C.muted)
    label(columns, 306, 7, textKey("ROLE"), 10, C.muted)
    label(columns, 390, 7, textKey("STATUS"), 10, C.muted)
    UI.personScroll, UI.personChild = scroll(d, 20, 354, 636, 124)
    UI.noPeople = label(d, 31, 378, textKey("NO_SIGNUPS"), 13, C.muted, 580)
    UI.ownerHint = label(d, 20, 503, "", 10, C.muted, 410)
    UI.edit = button(d, 440, 500, 104, 27, textKey("EDIT"), function() UI.OpenEditor(UI.selected) end)
    UI.cancel = button(d, 552, 500, 104, 27, textKey("CANCEL_EVENT"), function()
        StaticPopup_Show("GUILDBOARD_CANCEL", nil, nil, UI.selected)
    end)
    StaticPopupDialogs.GUILDBOARD_CANCEL = {
        text = L("CANCEL_CONFIRM"),
        button1 = L("CANCEL_EVENT"), button2 = L("BACK"), timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, id) if GB.model then outcome(GB.model:Cancel(id)) end end,
    }
    UI.syncText = label(f, 365, 668, "", 11, C.muted, 675)
    UI.toast = label(f, 365, 690, "", 10, C.green, 675)
    f:Hide()
end
function UI.Toggle()
    UI.Create()
    UI.frame:SetShown(not UI.frame:IsShown())
end
function UI.CreateLauncher()
    local b = box(Minimap, 0, 0, 34, 34, C.bg, "GuildBoardMinimapButton", "Button")
    b:SetFrameStrata("MEDIUM")
    local t = label(b, 0, 0, "VDP", 11, C.gold); t:ClearAllPoints(); t:SetPoint("CENTER")
    local function position()
        local angle = math.rad(GuildBoardDB.minimapAngle or 220)
        b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 87, math.sin(angle) * 87)
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(_, mouse) if mouse == "RightButton" then GB.RequestSync() else UI.Toggle() end end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            GuildBoardDB.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
            position()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(GB.NAME, 0.89, 0.73, 0.43)
        GameTooltip:AddLine(L("MINIMAP_HELP"), 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    position()
end
