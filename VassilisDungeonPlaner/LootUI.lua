local _, GB = ...
local L, UI, Loot = GB.L, GB.UI, GB.Loot
local W = UI.Widgets
local box, label, button, input, scroll = W.box, W.label, W.button, W.input, W.scroll
local textKey, C = W.textKey, W.colors
local View = { rows = {}, items = {}, inboxRows = {}, filter = "ALL", search = "", quality = 0, mine = false }
GB.LootUI = View
local unpack = unpack or table.unpack

local function choose(id)
    View.selected = id
    View.itemScroll:SetVerticalScroll(0)
    UI.Refresh()
end
local function row(index)
    local r = box(View.listChild, 0, (index - 1) * 88, 306, 80, C.row, nil, "Button")
    r.date = label(r, 12, 10, "", 11, C.gold, 280)
    r.title = label(r, 12, 30, "", 15, C.white, 280); r.title:SetHeight(20)
    r.info = label(r, 12, 58, "", 11, C.muted, 280)
    r:SetScript("OnClick", function() choose(r.id) end)
    View.rows[index] = r
    return r
end
local function itemRow(index)
    local r = box(View.itemChild, 0, (index - 1) * 57, 618, 51, C.row, nil, "Button")
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetPoint("TOPLEFT", 8, -8); r.icon:SetSize(35, 35)
    r.title = label(r, 54, 8, "", 13, C.white, 545); r.title:SetHeight(17); r.title:SetWordWrap(false)
    r.info = label(r, 54, 29, "", 11, C.muted, 545)
    r:SetScript("OnEnter", function(self)
        if self.entry then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local link = Loot.Link(self.entry)
            GameTooltip:SetHyperlink(link); GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        if self.entry and HandleModifiedItemClick then local link = Loot.Link(self.entry); HandleModifiedItemClick(link) end
    end)
    View.items[index] = r
    return r
end

function View.OpenShare()
    local run = Loot.data and Loot.data.runs[View.selected]
    if not run or not run.finished or run.receivedFrom then return end
    if not View.shareOverlay then
        local overlay = box(UI.frame, 0, 0, 1060, 720, { 0.015, 0.02, 0.03, 0.96 })
        View.shareOverlay = overlay
        overlay:SetFrameLevel(UI.frame:GetFrameLevel() + 30); overlay:EnableMouse(true)
        local panel = box(overlay, 275, 200, 510, 300, C.panel, "VDPLootShare")
        View.sharePanel = panel
        table.insert(UISpecialFrames, "VDPLootShare")
        panel:SetScript("OnHide", function() overlay:Hide() end)
        label(panel, 22, 20, textKey("LOOT_SHARE"), 22, C.white)
        View.shareTitle = label(panel, 22, 59, "", 13, C.gold, 465); View.shareTitle:SetHeight(20)
        label(panel, 22, 98, textKey("CHARACTER_NAME"), 11, C.muted)
        View.target = input(panel, 22, 119, 466, 32, 100)
        label(panel, 22, 166, textKey("LOOT_SHARE_HELP"), 12, C.muted, 465)
        View.shareError = label(panel, 22, 211, "", 11, C.red, 465); View.shareError:SetHeight(30)
        button(panel, 22, 252, 150, 30, textKey("CANCEL"), function() overlay:Hide() end)
        View.sendButton = button(panel, 282, 252, 206, 30, textKey("LOOT_SEND"), function()
            local ok, message = Loot.Share(View.shareID, View.target:GetText())
            if not ok then View.shareError:SetText(message); return end
            overlay:Hide(); UI.Notify(message)
        end, true)
    end
    View.shareID = run.id
    View.shareTitle:SetText(run.name .. " · " .. date(L("DATE_FULL"), run.started))
    View.shareError:SetText(""); View.target:SetText("")
    View.shareOverlay:Show(); View.sharePanel:Show(); View.target:SetFocus()
end

function View.RefreshInbox()
    if not View.inboxOverlay or not View.inboxOverlay:IsShown() then return end
    local list = Loot.Inbox()
    View.inboxEmpty:SetShown(#list == 0)
    for i, item in ipairs(list) do
        local r = View.inboxRows[i]
        if not r then
            r = box(View.inboxChild, 0, (i - 1) * 105, 606, 96, C.row)
            r.title = label(r, 12, 10, "", 16, C.white, 575); r.title:SetHeight(20)
            r.info = label(r, 12, 35, "", 11, C.muted, 575); r.info:SetHeight(17)
            r.progress = label(r, 12, 66, "", 11, C.gold, 265)
            r.accept = button(r, 304, 62, 155, 26, textKey("LOOT_IMPORT"), function()
                local ok, err = Loot.Accept(r.key)
                if not ok then UI.Notify(err, true) end
                View.RefreshInbox()
            end, true)
            r.dismiss = button(r, 470, 62, 124, 26, textKey("DISMISS"), function() Loot.Dismiss(r.key) end)
            View.inboxRows[i] = r
        end
        local offer = item.offer
        r.key = item.key
        r.title:SetText(offer.run.name)
        r.info:SetText(L("LOOT_INBOX_ROW", offer.sender, date(L("DATE_FULL"), offer.run.started), offer.run.size))
        local transfer = Loot.incoming[item.key]
        W.active(r.accept, transfer == nil)
        r.progress:SetText(transfer and L("LOOT_PROGRESS", transfer.count, transfer.run.size) or "")
        r:Show()
    end
    for i = #list + 1, #View.inboxRows do View.inboxRows[i]:Hide() end
    W.resizeScroll(View.inboxScroll, View.inboxChild, #list * 105)
end
function View.OpenInbox()
    if not View.inboxOverlay then
        local overlay = box(UI.frame, 0, 0, 1060, 720, { 0.015, 0.02, 0.03, 0.96 })
        View.inboxOverlay = overlay
        overlay:SetFrameLevel(UI.frame:GetFrameLevel() + 30); overlay:EnableMouse(true)
        local panel = box(overlay, 195, 105, 670, 500, C.panel, "VDPLootInbox")
        View.inboxPanel = panel
        table.insert(UISpecialFrames, "VDPLootInbox")
        panel:SetScript("OnHide", function() overlay:Hide() end)
        label(panel, 24, 22, textKey("LOOT_INBOX"), 23, C.white)
        View.inboxScroll, View.inboxChild = scroll(panel, 24, 77, 622, 342)
        View.inboxEmpty = label(panel, 24, 91, textKey("LOOT_NO_OFFERS"), 14, C.muted, 615)
        button(panel, 24, 448, 170, 32, textKey("CLOSE"), function() overlay:Hide() end)
    end
    View.inboxOverlay:Show(); View.inboxPanel:Show(); View.RefreshInbox()
end

function View.Refresh()
    if not UI.lootPanel then return end
    View.RefreshInbox()
    View.inboxButton.text:SetText(L("LOOT_INBOX_COUNT", #Loot.Inbox()))
    for kind, b in pairs(View.filters) do W.selected(b, View.filter == kind) end
    local runs = Loot.Runs(View.search, View.filter)
    local found = false
    for _, run in ipairs(runs) do if run.id == View.selected then found = true end end
    if not found then View.selected = runs[1] and runs[1].id end
    for i, run in ipairs(runs) do
        local r = View.rows[i] or row(i)
        r.id = run.id
        r.date:SetText(date(L("DATE_FULL") .. " %H:%M", run.started))
        r.title:SetText(run.name)
        r.info:SetText(L("LOOT_ROW", #run.items) .. (not run.finished and (" · " .. L("LOOT_RECORDING")) or (run.receivedFrom and (" · " .. L("LOOT_IMPORTED")) or "")))
        r:SetBackdropBorderColor(unpack(run.id == View.selected and C.gold or C.border)); r:Show()
    end
    for i = #runs + 1, #View.rows do View.rows[i]:Hide() end
    W.resizeScroll(View.listScroll, View.listChild, #runs * 88)
    View.count:SetText(L("LOOT_RUN_COUNT", #runs))
    View.empty:SetShown(#runs == 0)
    local run = Loot.data and Loot.data.runs[View.selected]
    View.detail:SetShown(run ~= nil)
    if not run then return end
    View.title:SetText(run.name)
    View.when:SetText(date(L("DATE_FULL") .. " %H:%M", run.started) .. (run.finished and (" – " .. date("%H:%M", run.finished)) or (" · " .. L("LOOT_RECORDING"))))
    View.source:SetText(L(run.receivedFrom and "LOOT_SOURCE_IMPORTED" or "LOOT_SOURCE", run.recorder))
    View.mineButton.text:SetText(L(View.mine and "LOOT_MINE" or "LOOT_EVERYONE"))
    W.selected(View.mineButton, View.mine)
    for quality, b in pairs(View.qualities) do W.selected(b, View.quality == quality) end
    local n, total = 0, 0
    for _, entry in ipairs(run.items) do
        if (View.quality == 0 or entry.quality == View.quality) and (not View.mine or GB.Core.SamePlayer(entry.player, GB.actor)) then
            n, total = n + 1, total + entry.quantity
            local r = View.items[n] or itemRow(n)
            local link, icon = Loot.Link(entry)
            r.entry = entry; r.title:SetText(link); r.icon:SetTexture(icon)
            r.info:SetText(L("LOOT_ITEM_ROW", entry.player, date("%H:%M", entry.at), entry.quantity)); r:Show()
        end
    end
    for i = n + 1, #View.items do View.items[i]:Hide() end
    W.resizeScroll(View.itemScroll, View.itemChild, n * 57)
    View.noItems:SetShown(n == 0)
    View.itemCount:SetText(L("LOOT_ITEM_COUNT", total))
    W.active(View.shareButton, run.finished ~= nil and not run.receivedFrom)
    W.active(View.deleteButton, Loot.data.active ~= run.id)
end
function View.Relocalize()
    if View.shareError then View.shareError:SetText("") end
    if StaticPopupDialogs.VDP_LOOT_DELETE then
        StaticPopupDialogs.VDP_LOOT_DELETE.text = L("LOOT_DELETE_CONFIRM")
        StaticPopupDialogs.VDP_LOOT_DELETE.button1 = L("LOOT_DELETE")
        StaticPopupDialogs.VDP_LOOT_DELETE.button2 = L("CANCEL")
    end
end
function View.Create()
    local f = CreateFrame("Frame", nil, UI.frame)
    f:SetPoint("TOPLEFT", 0, 0); f:SetSize(1060, 720)
    UI.lootPanel = f
    f:SetScript("OnHide", function()
        if View.shareOverlay then View.shareOverlay:Hide() end
        if View.inboxOverlay then View.inboxOverlay:Hide() end
    end)
    View.inboxButton = button(f, 653, 17, 161, 36, textKey("LOOT_INBOX"), View.OpenInbox)
    View.newButton = button(f, 828, 17, 171, 36, textKey("LOOT_NEW_RUN"), function()
        local run, err = Loot.NewRun()
        if run then choose(run.id) else UI.Notify(err or L("LOOT_STORAGE_FULL"), true) end
    end)
    View.filters = {}
    for i, spec in ipairs({ { "ALL", "FILTER_ALL" }, { "raid", "FILTER_RAIDS" }, { "party", "FILTER_DUNGEONS" } }) do
        local kind = spec[1]
        View.filters[kind] = button(f, 20 + (i - 1) * 109, 78, 103, 29, textKey(spec[2]), function()
            View.filter = kind; View.listScroll:SetVerticalScroll(0); UI.Refresh()
        end)
    end
    View.searchBox = input(f, 20, 120, 322, 31, 80)
    View.searchHint = label(View.searchBox.shell, 10, 9, textKey("SEARCH_HINT"), 12, C.muted, 302)
    View.searchBox:SetScript("OnTextChanged", function(self)
        View.search = self:GetText(); View.searchHint:SetShown(View.search == ""); View.listScroll:SetVerticalScroll(0); UI.Refresh()
    end)
    View.listScroll, View.listChild = scroll(f, 20, 165, 322, 465)
    View.empty = label(f, 32, 195, textKey("LOOT_NO_RUNS"), 13, C.muted, 295)
    View.count = label(f, 22, 641, "", 11, C.muted, 320)
    View.detail = box(f, 364, 78, 676, 577, C.panel)
    local d = View.detail
    View.title = label(d, 20, 18, "", 23, C.white, 630); View.title:SetHeight(29)
    View.when = label(d, 20, 60, "", 13, C.gold, 630)
    View.source = label(d, 20, 84, "", 12, C.muted, 630)
    View.qualities = {}
    for i, spec in ipairs({ { 0, "FILTER_ALL" }, { 3, "LOOT_RARE" }, { 4, "LOOT_EPIC" } }) do
        local quality = spec[1]
        View.qualities[quality] = button(d, 20 + (i - 1) * 89, 119, 82, 29, textKey(spec[2]), function()
            View.quality = quality; View.itemScroll:SetVerticalScroll(0); UI.Refresh()
        end)
    end
    View.mineButton = button(d, 456, 119, 200, 29, textKey("LOOT_EVERYONE"), function()
        View.mine = not View.mine; View.itemScroll:SetVerticalScroll(0); UI.Refresh()
    end)
    View.itemScroll, View.itemChild = scroll(d, 20, 165, 636, 343)
    View.noItems = label(d, 32, 191, textKey("LOOT_NO_ITEMS"), 13, C.muted, 600)
    View.itemCount = label(d, 20, 540, "", 11, C.muted, 255)
    View.shareButton = button(d, 338, 531, 151, 29, textKey("LOOT_SHARE"), View.OpenShare, true)
    View.deleteButton = button(d, 505, 531, 151, 29, textKey("LOOT_DELETE"), function()
        StaticPopup_Show("VDP_LOOT_DELETE", nil, nil, View.selected)
    end)
    StaticPopupDialogs.VDP_LOOT_DELETE = { text = L("LOOT_DELETE_CONFIRM"), button1 = L("LOOT_DELETE"),
        button2 = L("CANCEL"), timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, id) Loot.Delete(id) end }
    f:Hide()
end
