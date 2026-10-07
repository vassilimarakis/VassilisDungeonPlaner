local _, GB = ...
local L = GB.L
local Core = GB.Core
local G = {}
GB.Guests = G
local cooldown = {}
local function open(e) return e and e.cancelled == 0 and e.start > GB.Now() end
local function mine(e) return e and Core.SamePlayer(e.author, GB.actor) end
local function records(id)
    local result = {}
    for _, r in pairs(GB.model.data.records) do if r.event == id then result[#result + 1] = r end end
    local order = { E = 1, M = 2, S = 3, D = 4 }
    table.sort(result, function(a, b) return order[a.kind] < order[b.kind] end)
    return result
end
local function sendRecord(kind, token, r, target)
    local fields = { kind, "DIRECT", token }
    for _, value in ipairs(Core.ToFields(r)) do fields[#fields + 1] = value end
    return GB.Enqueue(fields, target)
end
local function recordFrom(fields)
    local data = {}
    for i = 4, #fields do data[#data + 1] = fields[i] end
    return Core.FromFields(data)
end
local function invitation(id, player)
    local all = GB.model.data.invites[id]
    return all and all[Core.PlayerKey(player)]
end
local function snapshot(id, player)
    for _, r in ipairs(records(id)) do sendRecord("V", id, r, player) end
end
function G.ValidName(raw)
    local name = GB.Name(raw)
    if not name then return nil end
    local character, realm = name:match("^([^-]+)%-(.+)$")
    -- Lua character classes depend on the host locale and may classify UTF-8
    -- name bytes as punctuation. Reject ASCII nonletters explicitly instead.
    if not character or #name > 100 or character:find("[%z\1-\64\91-\96\123-\127]") or realm:find("[%z\1-\31\127|@/~]") then return nil end
    return name
end
local function newCode()
    local used = {}
    for _, guests in pairs(GB.model.data.invites) do for _, invite in pairs(guests) do used[invite.code] = true end end
    for _ = 1, 100 do
        local code = string.format("%06X", math.random(0, 16777215))
        if not used[code] then return code end
    end
end
function G.Invite(id, raw)
    local e, name = GB.model:GetEvent(id), G.ValidName(raw)
    if not open(e) or not mine(e) then return nil, L("OWNER_INVITE_ONLY") end
    if not name then return nil, L("NAME_REQUIRED") end
    if Core.SamePlayer(name, GB.actor) then return nil, L("INVITE_SELF") end
    if InCombatLockdown() or (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) then
        return nil, L("INVITE_BLOCKED")
    end
    local invite = invitation(id, name)
    if invite and invite.sent and GB.Now() - invite.sent < 10 then return nil, L("INVITE_COOLDOWN") end
    local code = invite and invite.code or newCode()
    if not code then return nil, L("INVITE_NO_CODE") end
    local when = date(L("DATE_INVITE"), e.start)
    -- State the sender's local time explicitly; addon recipients render their own.
    local template = L("INVITE_WHISPER", GB.NAME, "", when, code, code, code)
    local title = Core.Clean(e.title, math.max(0, math.min(60, 255 - #template)))
    local message = L("INVITE_WHISPER", GB.NAME, title, when, code, code, code)
    local send = C_ChatInfo.SendChatMessage or SendChatMessage
    if not send then return nil, L("WHISPER_UNAVAILABLE") end
    local ok = pcall(send, message, "WHISPER", nil, name)
    if not ok then return nil, L("WHISPER_REJECTED") end
    GB.model.data.invites[id] = GB.model.data.invites[id] or {}
    invite = invite or { name = name, code = code }
    invite.sent = GB.Now()
    GB.model.data.invites[id][Core.PlayerKey(name)] = invite
    if not GB.model:GetSignup(id, name) then GB.model:SetManual(id, name, "DAMAGER", "INVITED", "", "MANUAL") end
    sendRecord("I", code, e, name)
    GB.UI.Refresh()
    return invite, L("INVITE_SENT")
end
function G.Inbox()
    local result = {}
    for id, item in pairs(GB.model.data.inbox) do
        if open(item.event) then result[#result + 1] = item else GB.model.data.inbox[id] = nil end
    end
    table.sort(result, function(a, b) return a.event.start < b.event.start end)
    return result
end
function G.Accept(id)
    local item = GB.model.data.inbox[id]
    if not item or not open(item.event) then return nil, L("INVITE_CLOSED") end
    if not GB.commsReady then return nil, L("COMMS_UNAVAILABLE") end
    GB.model:Merge(item.event, item.owner, false)
    GB.model.data.accepted[id] = { owner = item.owner, code = item.code }
    GB.model.data.inbox[id] = nil
    GB.Enqueue({ "J", "DIRECT", item.code, id }, item.owner)
    GB.UI.selected, GB.UI.filter, GB.UI.search = id, "ALL", ""
    if GB.UI.searchBox then GB.UI.searchBox:SetText("") end
    GB.UI.Refresh()
    return true
end
function G.Publish(r)
    local e = r.kind == "E" and r or GB.model:GetEvent(r.event)
    if not e then return end
    if mine(e) then
        for _, invite in pairs(GB.model.data.invites[e.event] or {}) do
            if invite.addon then sendRecord("V", e.event, r, invite.name) end
        end
    elseif r.kind == "S" and Core.SamePlayer(r.author, GB.actor) and GB.model.data.accepted[e.event] then
        sendRecord("W", e.event, r, e.author)
    end
end
function G.RequestSync()
    for id, accepted in pairs(GB.model.data.accepted) do
        local e = GB.model:GetEvent(id)
        if e and e.start >= GB.Now() - 30 * 86400 then
            -- Repeating the acceptance repairs a dropped handshake after login.
            GB.Enqueue({ "J", "DIRECT", accepted.code, id }, accepted.owner)
            local s = GB.model:GetSignup(id, GB.actor)
            if s and s.kind == "S" then sendRecord("W", id, s, accepted.owner) end
            GB.Enqueue({ "P", "DIRECT", accepted.code, id }, accepted.owner)
        end
    end
    -- The organizer can reconnect to already accepted guests after a restart.
    for id, guests in pairs(GB.model.data.invites) do
        local e = GB.model:GetEvent(id)
        if e and mine(e) and e.start >= GB.Now() - 30 * 86400 then
            for _, invite in pairs(guests) do if invite.addon then snapshot(id, invite.name) end end
        end
    end
end
function G.Receive(fields, sender)
    if not GB.model then return end
    local kind, token = fields[1], fields[3]
    if type(token) ~= "string" or #token > 160 then return end
    local now, key = GetTime(), Core.PlayerKey(sender)
    if kind == "I" then
        local e = recordFrom(fields)
        if not token:match("^%x%x%x%x%x%x$") or not e or e.kind ~= "E" or not Core.Validate(e, GB.Now()) or not open(e)
            or not Core.SamePlayer(e.author, sender) then return end
        if cooldown["I" .. key] and now - cooldown["I" .. key] < 3 then return end
        cooldown["I" .. key] = now
        local accepted = GB.model.data.accepted[e.event]
        if accepted then
            accepted.code = token
            GB.model:Merge(e, sender, false)
            GB.Enqueue({ "J", "DIRECT", token, e.event }, sender)
        else
            if #G.Inbox() >= 50 and not GB.model.data.inbox[e.event] then return end
            GB.model.data.inbox[e.event] = { event = e, owner = sender, code = token }
            GB.Print(L("INVITE_RECEIVED", sender, e.title))
        end
    elseif kind == "J" or kind == "P" then
        if #fields ~= 4 then return end
        local id, invite = fields[4], invitation(fields[4], sender)
        local e = GB.model:GetEvent(id)
        if not mine(e) or not invite or invite.code ~= token then return end
        if kind == "P" and not invite.addon then return end
        invite.addon = true
        local limitKey = "P" .. key .. id
        if not cooldown[limitKey] or now - cooldown[limitKey] >= 10 then snapshot(id, sender); cooldown[limitKey] = now end
    elseif kind == "V" then
        local accepted = GB.model.data.accepted[token]
        if not accepted or not Core.SamePlayer(accepted.owner, sender) then return end
        local r = recordFrom(fields)
        if not r or r.event ~= token or not Core.SamePlayer(Core.Owner(token), sender) then return end
        GB.model:Merge(r, sender, true)
    elseif kind == "W" then
        local e, invite = GB.model:GetEvent(token), invitation(token, sender)
        if not mine(e) or not invite or not invite.addon then return end
        local r = recordFrom(fields)
        if not r or r.kind ~= "S" or r.event ~= token or not Core.SamePlayer(r.author, sender) then return end
        if GB.model:Merge(r, sender, false) then GB.BroadcastRecord(r, false) end
    else return end
    GB.lastContact = GB.Now()
    GB.UI.Refresh()
end
local replyTypes = { accept = "YES", ja = "YES", zusage = "YES", maybe = "MAYBE", vielleicht = "MAYBE", decline = "NO", nein = "NO", absage = "NO" }
local replyRoles = { tank = "TANK", healer = "HEALER", heiler = "HEALER", heal = "HEALER", dd = "DAMAGER", dps = "DAMAGER" }
function G.Whisper(message, sender)
    if type(message) ~= "string" or not sender or #message > 255 then return end
    local words = {}
    for word in Core.Trim(message):lower():gmatch("%S+") do words[#words + 1] = word end
    local response = replyTypes[words[1]]
    if not response or #words > 3 then return end
    local code, role
    for i = 2, #words do
        local word = words[i]
        if replyRoles[word] and not role then role = replyRoles[word]
        elseif word:match("^%x%x%x%x%x%x$") and not code then code = word:upper()
        else return end
    end
    local matches = {}
    for id, guests in pairs(GB.model.data.invites) do
        local invite, e = guests[Core.PlayerKey(sender)], GB.model:GetEvent(id)
        if invite and mine(e) and open(e) and (not code or invite.code == code) then matches[#matches + 1] = id end
    end
    if #matches ~= 1 then
        if #matches > 1 then GB.Print(L("REPLY_AMBIGUOUS", sender)) end
        return
    end
    local id, old = matches[1], GB.model:GetSignup(matches[1], sender)
    local record = GB.model:SetManual(id, sender, role or (old and old.role) or "DAMAGER", response, old and old.note or "", "WHISPER")
    if record then GB.Print(L("REPLY_RECORDED", sender, GB.model:GetEvent(id).title)) end
end
