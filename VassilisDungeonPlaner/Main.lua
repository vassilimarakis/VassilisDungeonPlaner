local addonName, GB = ...
local L = GB.L
local Core, Wire = GB.Core, GB.Wire
local PREFIX = "GuildBoard3"
local queue, first, serial = {}, 1, 0
local members, cooldowns, offers, incomingRequests = {}, {}, {}, {}
local reassembly = Wire.New(GetTime)
local session = tostring(math.random(100000, 999999))
local sync, lastHello, sendDelay, reminderTick = nil, -1000, 0, 0
GB.lastContact = nil

function GB.Print(message) print("|cffe4bd74" .. GB.NAME .. "|r  " .. message) end
function GB.Now() return GetServerTime() end
function GB.Name(name)
    if not name then return nil end
    name = Core.Trim(name)
    if name:find("-", 1, true) then return name:gsub(" ", "") end
    return name .. "-" .. (GetNormalizedRealmName() or GetRealmName()):gsub(" ", "")
end
local function actorName()
    local name, realm = UnitFullName("player")
    return GB.Name(name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName()))
end
local function isMember(name)
    if Core.SamePlayer(name, GB.actor) or members[Core.PlayerKey(name)] then return true end
    if C_GuildInfo and C_GuildInfo.MemberExistsByName then
        local ok, found = pcall(C_GuildInfo.MemberExistsByName, name)
        if ok and found then return true end
    end
    return false
end
local function resetTransport()
    queue, first, offers, incomingRequests, cooldowns, sync = {}, 1, {}, {}, {}, nil
    reassembly = Wire.New(GetTime)
    GB.lastContact = nil
end
local function refreshMembers()
    members = {}
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name then members[Core.PlayerKey(GB.Name(name))] = true end
    end
end
function GB.RefreshContext()
    if not GB.ready then return end
    local guild, _, _, realm = GetGuildInfo("player")
    local key = guild and ((GetCurrentRegion() or 0) .. ":" .. guild .. "@" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName()):gsub(" ", ""))
    if key ~= GB.guildKey or not GB.model then
        resetTransport()
        GB.guildKey, GB.guildName, GB.actor = key, guild, actorName()
        GB.profileKey = "player:" .. (GetCurrentRegion() or 0) .. ":" .. Core.PlayerKey(GB.actor)
        GB.model = Core.New(GuildBoardDB, GB.actor, GB.profileKey, GB.Now)
        GB.Loot.Init()
        GB.model.scope = key or ""
        -- Import 0.1 guild records once, preserving the untouched old buckets.
        local imported = GB.model.data.importedGuilds or {}
        GB.model.data.importedGuilds = imported
        for oldKey, oldData in pairs(GuildBoardDB.guilds) do
            if not oldKey:match("^player:") and not imported[oldKey] then
                for _, old in pairs(oldData.records or {}) do
                    local owner = type(old) == "table" and Core.Owner(old.event)
                    if owner and (oldKey == key or Core.SamePlayer(owner, GB.actor)) then
                        local r = Core.Copy(old)
                        if r.kind == "E" then r.scope = r.scope or oldKey end
                        if r.kind == "D" then r.signupKind = r.signupKind or "S" end
                        if r.kind == "S" or r.kind == "M" then r.level = r.level or 0 end
                        GB.model:Merge(r, r.author, true)
                    end
                end
                if oldKey == key then imported[oldKey] = true end
            end
        end
        GB.model.onWrite = function(record)
            GB.BroadcastRecord(record, false)
            GB.UI.Refresh()
        end
        GB.UI.Reset()
        C_Timer.After(4, function() if GB.guildKey == key then GB.RequestSync() end end)
    end
    refreshMembers()
    GB.UI.Refresh()
end
local function enqueueBatch(messages, target)
    if not GB.model or not GB.commsReady or (not target and not GB.guildKey) then return false end
    local batch = {}
    for _, fields in ipairs(messages) do
        serial = serial + 1
        local packets = Wire.Packets(Wire.Encode(fields), session .. tostring(serial))
        if not packets or (#queue - first + 1 + #batch + #packets) > 8000 then
            GB.commError = "SYNC_BUSY"
            return false
        end
        for _, packet in ipairs(packets) do
            batch[#batch + 1] = { packet = packet, target = target, guild = GB.guildKey, retries = 0,
                direct = fields[2] == "DIRECT" or fields[2] == "LOOT1" }
        end
    end
    for _, item in ipairs(batch) do queue[#queue + 1] = item end
    return true
end
GB.EnqueueBatch = enqueueBatch
local function enqueue(fields, target) return enqueueBatch({ fields }, target) end
GB.Enqueue = enqueue
function GB.BroadcastRecord(r, relay, target, request)
    local e = r.kind == "E" and r or GB.model:GetEvent(r.event)
    if not relay then GB.Guests.Publish(r) end
    if not GB.guildKey or not e or e.scope ~= GB.guildKey then return end
    local fields = { relay and "R" or (Core.SamePlayer(r.author, GB.actor) and "U" or "T"), GB.guildKey, request or "" }
    for _, field in ipairs(Core.ToFields(r)) do fields[#fields + 1] = field end
    return enqueue(fields, target)
end
local function digest()
    local sum, count = 0, 0
    if not GB.model then return "0", 0 end
    for _, r in pairs(GB.model.data.records) do
        local e = GB.model:GetEvent(r.event)
        if GB.guildKey and e and e.scope == GB.guildKey then
            local value, hash = Core.Canonical(r), 0
            for i = 1, #value do hash = (hash * 33 + value:byte(i)) % 2147483647 end
            sum, count = (sum + hash) % 2147483647, count + 1
        end
    end
    return tostring(count) .. "." .. tostring(sum), count
end
function GB.RequestSync()
    if not GB.model then return end
    if not GB.commsReady then GB.Print(L("COMMS_CLIENT_UNAVAILABLE")); return end
    if GetTime() - lastHello < 15 then return end
    lastHello = GetTime()
    GB.Guests.RequestSync()
    if not GB.guildKey then GB.UI.Refresh(); return end
    serial = serial + 1
    local id = session .. tostring(serial)
    offers = {}
    sync = { id = id, at = GetTime(), tried = {}, sources = 0 }
    local hash = digest()
    enqueue({ "H", GB.guildKey, id, hash })
    GB.UI.Refresh()
end
local function offerNext()
    if not sync or sync.peer or GetTime() - sync.at < 5 then return end
    if sync.sources >= 5 then sync = nil; return end
    local ownHash, chosen, largest = digest(), nil, -1
    for peer, offer in pairs(offers) do
        if not sync.tried[peer] and offer.hash ~= ownHash and offer.count > largest then chosen, largest = peer, offer.count end
    end
    if not chosen then sync = nil; return end
    sync.tried[chosen], sync.peer, sync.waiting = true, chosen, GetTime()
    sync.sources = sync.sources + 1
    enqueue({ "Q", GB.guildKey, sync.id }, chosen)
end
local function receive(body, sender, channel)
    local fields = Wire.Decode(body)
    if not fields then return end
    if fields[2] == "LOOT1" then
        if channel == "WHISPER" then GB.Loot.Receive(fields, sender) end
        return
    end
    if fields[2] == "DIRECT" then
        if channel == "WHISPER" then GB.Guests.Receive(fields, sender) end
        return
    end
    if not GB.guildKey or fields[2] ~= GB.guildKey or not isMember(sender) then return end
    local kind, request = fields[1], fields[3]
    if not request or #request > 32 then return end
    if kind == "U" or kind == "R" or kind == "T" then
        if kind == "R" and (not sync or sync.id ~= request or sync.peer ~= sender) then return end
        local data = {}
        for i = 4, #fields do data[#data + 1] = fields[i] end
        local record = Core.FromFields(data)
        local e = record and (record.kind == "E" and record or GB.model:GetEvent(record.event))
        if kind == "T" and (not e or not Core.SamePlayer(e.author, sender)) then return end
        if record and e and e.scope == GB.guildKey and GB.model:Merge(record, sender, kind ~= "U") then
            if Core.SamePlayer(e.author, GB.actor) then GB.Guests.Publish(record) end
            GB.UI.Refresh()
        end
        if kind == "R" then sync.waiting = GetTime() end
    elseif kind == "H" and #fields == 4 then
        if cooldowns[sender] and GetTime() - cooldowns[sender] < 15 then return end
        cooldowns[sender] = GetTime()
        incomingRequests[sender] = { id = request, at = GetTime() }
        local guild = GB.guildKey
        C_Timer.After(math.random() * 3, function()
            if GB.guildKey ~= guild then return end
            local hash, count = digest()
            enqueue({ "O", guild, request, hash, tostring(count) }, sender)
        end)
    elseif kind == "O" and #fields == 5 and sync and sync.id == request then
        local count = tonumber(fields[5])
        if count and count >= 0 and count <= 6000 and #fields[4] <= 40 then offers[sender] = { hash = fields[4], count = count } end
    elseif kind == "Q" and #fields == 3 then
        local offered = incomingRequests[sender]
        if not offered or offered.id ~= request or GetTime() - offered.at > 900 or offered.sent then return end
        offered.sent = true
        local records = {}
        for _, r in pairs(GB.model.data.records) do
            local e = GB.model:GetEvent(r.event)
            if e and e.scope == GB.guildKey then records[#records + 1] = r end
        end
        -- Events precede signups and decisions; merge itself also accepts reordering.
        local order = { E = 1, M = 2, S = 3, D = 4 }
        table.sort(records, function(a, b) return order[a.kind] < order[b.kind] end)
        for _, r in ipairs(records) do
            if not GB.BroadcastRecord(r, true, sender, request) then break end
        end
        enqueue({ "X", GB.guildKey, request }, sender)
    elseif kind == "X" and #fields == 3 and sync and sync.id == request and sync.peer == sender then
        sync.peer = nil
        offerNext()
    else return end
    GB.lastContact = GB.Now()
end
local function blocked()
    return InCombatLockdown() or (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
        or (C_ChatInfo.AreOutgoingAddonChatMessagesRestricted and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted())
end
function GB.SyncStatus()
    if not GB.commsReady then return L("SYNC_UNAVAILABLE") end
    if GB.commError then return L(GB.commError) end
    local waiting = #queue - first + 1
    if waiting > 0 and blocked() then return L("SYNC_BLOCKED") end
    if waiting > 0 then return L("SYNC_PENDING", waiting) end
    if sync then return L("SYNC_RUNNING") end
    if GB.lastContact then return L("SYNC_CONTACT", date("%H:%M", GB.lastContact)) end
    return GB.guildKey and L("SYNC_WAITING") or L("SYNC_SOLO")
end
local function sendOne()
    if first > #queue then queue, first = {}, 1; return end
    if blocked() then return end
    local item = queue[first]
    if item.guild ~= GB.guildKey or (item.target and not item.direct and not isMember(item.target)) then first = first + 1; return end
    local send = C_ChatInfo.SendAddonMessageLogged or C_ChatInfo.SendAddonMessage
    local ok, result = pcall(send, PREFIX, item.packet, item.target and "WHISPER" or "GUILD", item.target)
    local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
    if ok and (result == success or result == true or result == nil) then
        first, GB.commError = first + 1, nil
    else
        item.retries = item.retries + 1
        sendDelay = -2
        if item.retries >= 5 then
            first = first + 1
            GB.commError = "SYNC_FAILED"
        end
    end
end
local reminded = {}
local function reminders()
    if not GB.model then return end
    for _, e in ipairs(GB.model:Events("ALL", "", false)) do
        local remaining, status = e.start - GB.Now(), GB.model:Status(e.event, GB.actor)
        local key = e.event .. ":" .. e.start
        if remaining > 0 and remaining <= 900 and not reminded[key]
            and (status == "PENDING" or status == "CONFIRMED" or status == "MAYBE" or status == "BENCH") then
            reminded[key] = true
            GB.Print(L("REMINDER", e.title, math.ceil(remaining / 60)))
        end
    end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        if GuildBoardDB and GuildBoardDB.schema and GuildBoardDB.schema > 3 then
            GB.Print(L("NEWER_DATA", GB.NAME))
            return
        end
        GuildBoardDB = GuildBoardDB or {}
        GuildBoardDB.schema = 3
        GuildBoardDB.language = GB.Locale.Preference()
        GB.ready = true
        GB.actor = actorName()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
            GB.commsReady = ok and (result == true or result == 0 or (C_ChatInfo.IsAddonMessagePrefixRegistered and C_ChatInfo.IsAddonMessagePrefixRegistered(PREFIX)))
        end
        SLASH_GUILDBOARD1, SLASH_GUILDBOARD2 = "/gb", "/guildboard"
        SLASH_GUILDBOARD3, SLASH_GUILDBOARD4 = "/vdp", "/dungeonplaner"
        SlashCmdList.GUILDBOARD = function(command)
            if Core.Trim(command) == "sync" then GB.RequestSync()
            elseif Core.Trim(command) == "invites" then GB.UI.Create(); GB.UI.frame:Show(); GB.UI.OpenInvites()
            else GB.UI.Toggle() end
        end
        GB.UI.CreateLauncher()
    elseif event == "PLAYER_LOGIN" and GB.ready then
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        GB.RefreshContext()
        GB.Loot.CheckInstance()
        GB.Print(L("READY"))
    elseif (event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE") and GB.ready then
        GB.RefreshContext()
    elseif event == "CHAT_MSG_WHISPER" and GB.model then
        local message, sender = ...
        if not issecretvalue or (not issecretvalue(message) and not issecretvalue(sender)) then GB.Guests.Whisper(message, GB.Name(sender)) end
    elseif (event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED") and GB.model then
        local prefix, message, channel, sender = ...
        if issecretvalue and (issecretvalue(prefix) or issecretvalue(message) or issecretvalue(channel) or issecretvalue(sender)) then return end
        if prefix ~= PREFIX or (channel ~= "GUILD" and channel ~= "WHISPER") then return end
        sender = GB.Name(sender)
        if not sender or Core.SamePlayer(sender, GB.actor) then return end
        local body = reassembly:Receive(sender, message)
        if body then receive(body, sender, channel) end
    end
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    if not GB.ready then return end
    sendDelay, reminderTick = sendDelay + elapsed, reminderTick + elapsed
    if sendDelay >= 0.3 then
        sendDelay = 0
        if GB.commsReady and GB.model then sendOne() end
        if sync and sync.peer and GetTime() - sync.waiting > 45 then sync.peer = nil end
        offerNext()
    end
    if reminderTick >= 15 then
        reminderTick = 0
        reminders()
        GB.Loot.Tick()
        GB.UI.Refresh()
        if GB.model and not sync and #queue < first and GetTime() - lastHello >= 180 then GB.RequestSync() end
    end
end)

-- Accessible to the offline integration harness; no extra in-game globals.
GB.Transport = { frame = frame, receive = receive, digest = digest }
