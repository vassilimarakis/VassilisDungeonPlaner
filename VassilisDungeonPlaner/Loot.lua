local _, GB = ...
local L, Core, Wire = GB.L, GB.Core, GB.Wire
local Loot = { offers = {}, outgoing = {}, incoming = {} }
GB.Loot = Loot
local MAX_RUNS, MAX_ITEMS, TTL = 250, 1000, 1800
local seen, pending, offerTimes = {}, {}, {}
local tokenSerial = 0
local session = tostring(math.random(100000, 999999))

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = copy(v) end
    return result
end

local function public(value) return not issecretvalue or not issecretvalue(value) end
local function integer(value, low, high)
    local n = tonumber(value)
    return n and n == math.floor(n) and n >= low and n <= high and n or nil
end
local function plain(value, limit)
    return type(value) == "string" and #value <= limit and not value:find("[%z\1-\31\127|]")
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function refresh() if GB.UI then GB.UI.Refresh() end end
local function notice(key, ...)
    local message = L(key, ...)
    if GB.UI then GB.UI.Notify(message) end
    GB.Print(message)
end
local function send(kind, token, target)
    return GB.Enqueue({ kind, "LOOT1", token }, target)
end
local function entryFields(e)
    return { e.at, e.itemID, e.itemString, e.quality, e.quantity, e.player, e.name }
end
local function fingerprint(run)
    local hash = 0
    local function add(fields)
        local s = Wire.Encode(fields) .. "\n"
        for i = 1, #s do hash = (hash * 33 + s:byte(i)) % 2147483647 end
    end
    add({ run.id, run.recorder, run.name, run.kind, run.map, run.difficulty, run.started, run.finished, #run.items })
    for _, e in ipairs(run.items) do add(entryFields(e)) end
    return tostring(hash)
end

function Loot.Init()
    if Loot.profile == GB.profileKey then return end
    GuildBoardDB.lootProfiles = GuildBoardDB.lootProfiles or {}
    local profiles = GuildBoardDB.lootProfiles
    profiles[GB.profileKey] = profiles[GB.profileKey] or { runs = {}, serial = 0 }
    Loot.profile, Loot.data = GB.profileKey, profiles[GB.profileKey]
    Loot.offers, Loot.incoming, Loot.outgoing = {}, {}, {}
    Loot.data.pending = Loot.data.pending or {}
    seen, pending, offerTimes = {}, Loot.data.pending, {}
end

local function instance()
    if not GetInstanceInfo then return end
    local name, kind, difficulty, _, _, _, _, map = GetInstanceInfo()
    if not public(name) or not public(kind) or not public(map) or not public(difficulty) then return end
    if (kind ~= "party" and kind ~= "raid") or not plain(name, 160) then return end
    return { name = name, kind = kind, map = map or 0, difficulty = difficulty or 0 }
end
function Loot.CheckInstance(forceNew)
    if not Loot.data then return end
    local data, here, now = Loot.data, instance(), GB.Now()
    local current = data.active and data.runs[data.active]
    if current and (not here or forceNew or current.map ~= here.map or current.difficulty ~= here.difficulty
        or current.kind ~= here.kind or now - (data.seenAt or now) > 7200) then
        current.finished = data.seenAt or now
        data.recent, data.active = current.id, nil
        current = nil
    end
    if here and not current then
        local recent = not forceNew and data.recent and data.runs[data.recent]
        if recent and recent.map == here.map and recent.kind == here.kind and recent.difficulty == here.difficulty
            and recent.finished and now - recent.finished <= 600 then
            current = recent; current.finished = nil
        elseif count(data.runs) < MAX_RUNS then
            data.serial = data.serial + 1
            current = { id = Core.PlayerKey(GB.actor) .. ":" .. now .. ":" .. data.serial,
                recorder = GB.actor, name = here.name, kind = here.kind, map = here.map,
                difficulty = here.difficulty, started = now, items = {} }
            data.runs[current.id] = current
        elseif not Loot.fullNotified then
            Loot.fullNotified = true; notice("LOOT_STORAGE_FULL")
        end
        data.active = current and current.id
    end
    if current then data.seenAt = now end
    return current
end
function Loot.NewRun()
    if not instance() then return nil, L("LOOT_INSTANCE_REQUIRED") end
    local run = Loot.CheckInstance(true)
    refresh()
    return run
end
function Loot.Runs(search, kind)
    local list = {}
    search = (search or ""):lower()
    for _, run in pairs(Loot.data and Loot.data.runs or {}) do
        if (not kind or kind == "ALL" or run.kind == kind)
            and (run.name:lower():find(search, 1, true) or run.recorder:lower():find(search, 1, true)) then list[#list + 1] = run end
    end
    table.sort(list, function(a, b) if a.started == b.started then return a.id > b.id end; return a.started > b.started end)
    return list
end
function Loot.Delete(id)
    if not Loot.data or Loot.data.active == id then return false end
    Loot.data.runs[id] = nil
    if Loot.data.recent == id then Loot.data.recent = nil end
    Loot.fullNotified = nil
    refresh()
    return true
end

-- Match the client's own localized loot formats, independent of addon language.
-- Only actual loot receipts are accepted, not crafted items or roll announcements.
local function captures(format, message)
    if type(format) ~= "string" then return end
    local pattern, order, cursor, sequential = "^", {}, 1, 0
    while cursor <= #format do
        local a, b, position, kind = format:find("%%(%d+)%$([sd])", cursor)
        local c, d, simple = format:find("%%([sd])", cursor)
        if c and (not a or c < a) then a, b, position, kind = c, d, nil, simple end
        if not a then
            pattern = pattern .. format:sub(cursor):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            break
        end
        pattern = pattern .. format:sub(cursor, a - 1):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        sequential = sequential + 1
        order[#order + 1] = tonumber(position) or sequential
        pattern = pattern .. (kind == "d" and "(%d+)" or "(.-)")
        cursor = b + 1
    end
    local values = { message:match(pattern .. "$") }
    if #values == 0 then return end
    local out = {}; for i, value in ipairs(values) do out[order[i]] = value end
    return out
end
function Loot.Parse(message)
    if not public(message) or type(message) ~= "string" then return end
    for _, spec in ipairs({ { "LOOT_ITEM_SELF_MULTIPLE", true, true }, { "LOOT_ITEM_SELF", true },
        { "LOOT_ITEM_MULTIPLE", false, true }, { "LOOT_ITEM", false } }) do
        local values = captures(_G[spec[1]], message)
        if values then
            local linkIndex = spec[2] and 1 or 2
            local link = values[linkIndex] or ""
            local itemString = link:match("|H(item:[^|]+)|h")
            local id = itemString and tonumber(itemString:match("^item:(%d+)"))
            local player = spec[2] and GB.actor or GB.Guests.ValidName(values[1])
            local quantity = 1
            if spec[3] then quantity = integer(values[linkIndex + 1], 1, 100000) end
            if not quantity then return end
            if id and player and quantity and #itemString <= 512 and itemString:match("^item:[%d:%-]+$") then
                return { itemID = id, itemString = itemString, player = player, quantity = quantity,
                    name = Core.Clean(link:match("|h%[(.-)%]|h") or ("Item " .. id), 200) }
            end
        end
    end
end
local function itemInfo(item)
    local getter = C_Item and C_Item.GetItemInfo or GetItemInfo
    if getter then return getter(item) end
end
function Loot.Link(e)
    local name, link, _, _, _, _, _, _, _, icon = itemInfo(e.itemString)
    if not public(name) or not public(link) or not public(icon) then name, link, icon = nil, nil, nil end
    local color = e.quality == 4 and "ffa335ee" or "ff0070dd"
    return link or ("|c" .. color .. "|H" .. e.itemString .. "|h[" .. e.name .. "]|h|r"), icon or 134400, name or e.name
end
local function resolve(entry, run)
    local name, _, quality = itemInfo(entry.itemString)
    if not public(quality) or not public(name) then return false end
    if quality == nil then return false end
    if quality == 3 or quality == 4 then
        if #run.items >= MAX_ITEMS then
            if not run.full then run.full = true; notice("LOOT_RUN_FULL") end
            return true
        end
        entry.quality = quality
        if name then entry.name = Core.Clean(name, 200) end
        run.items[#run.items + 1] = entry
        table.sort(run.items, function(a, b) if a.at == b.at then return a.order < b.order end; return a.at < b.at end)
    end
    return true
end
function Loot.OnLoot(message, lineID)
    local run = Loot.CheckInstance()
    if not run then return end
    local entry = Loot.Parse(message)
    if not entry then return end
    if public(lineID) and type(lineID) == "number" and lineID > 0 then
        if seen[lineID] then return end
        seen[lineID] = GB.Now()
    end
    run.sequence = (run.sequence or #run.items) + 1
    entry.at, entry.order = GB.Now(), run.sequence
    if not resolve(entry, run) and #pending < MAX_ITEMS then
        pending[#pending + 1] = { entry = entry, runID = run.id, at = GB.Now() }
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(entry.itemID) end
    end
    refresh()
end
function Loot.ResolvePending()
    for i = #pending, 1, -1 do
        local p = pending[i]
        local run = Loot.data.runs[p.runID]
        if not run or resolve(p.entry, run) then table.remove(pending, i)
        elseif GB.Now() - p.at > 300 then
            table.remove(pending, i); notice("LOOT_ITEM_UNAVAILABLE", p.entry.name)
        end
    end
end

local function offerKey(sender, token) return Core.PlayerKey(sender) .. ":" .. token end
local function header(fields, sender)
    if #fields ~= 13 or not plain(fields[4], 160) or not plain(fields[5], 100) or not plain(fields[6], 160)
        or not Core.SamePlayer(fields[5], sender) or (fields[7] ~= "raid" and fields[7] ~= "party") then return end
    local prefix = Core.PlayerKey(sender) .. ":"
    if fields[4]:sub(1, #prefix) ~= prefix or not fields[4]:sub(#prefix + 1):match("^%d+:%d+$") then return end
    local map, difficulty = integer(fields[8], 0, 1000000), integer(fields[9], 0, 10000)
    local started, finished = integer(fields[10], 1, GB.Now() + 300), integer(fields[11], 1, GB.Now() + 300)
    local size = integer(fields[12], 0, MAX_ITEMS)
    if not map or not difficulty or not started or not finished or finished < started or not size
        or not integer(fields[13], 0, 2147483646) then return end
    return { id = fields[4], recorder = fields[5], name = fields[6], kind = fields[7], map = map,
        difficulty = difficulty, started = started, finished = finished, size = size, hash = fields[13], items = {} }
end
function Loot.Share(id, raw)
    local run = Loot.data and Loot.data.runs[id]
    local target = GB.Guests.ValidName(raw)
    if not run or not run.finished or run.receivedFrom then return nil, L("LOOT_SHARE_FINISHED") end
    if not target or Core.SamePlayer(target, GB.actor) then return nil, L("INVALID_NAME") end
    if not GB.commsReady then return nil, L("COMMS_UNAVAILABLE") end
    for _, p in ipairs(pending) do if p.runID == run.id then return nil, L("LOOT_LOADING") end end
    for _, outgoing in pairs(Loot.outgoing) do
        if Core.SamePlayer(outgoing.target, target) and GB.Now() - outgoing.at < 15 then return nil, L("INVITE_COOLDOWN") end
    end
    if count(Loot.outgoing) >= 10 then return nil, L("SYNC_BUSY") end
    local snapshot = copy(run)
    tokenSerial = tokenSerial + 1
    local token = session .. tostring(tokenSerial)
    local fields = { "O", "LOOT1", token, snapshot.id, snapshot.recorder, snapshot.name, snapshot.kind, snapshot.map,
        snapshot.difficulty, snapshot.started, snapshot.finished, #snapshot.items, fingerprint(snapshot) }
    if not GB.Enqueue(fields, target) then return nil, L("SYNC_BUSY") end
    Loot.outgoing[token] = { run = snapshot, target = target, at = GB.Now() }
    return true, L("LOOT_OFFER_SENT", target)
end
function Loot.Inbox()
    local list = {}
    for key, offer in pairs(Loot.offers) do list[#list + 1] = { key = key, offer = offer } end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end
function Loot.Accept(key)
    local offer = Loot.offers[key]
    if not offer or Loot.incoming[key] then return nil, L("LOOT_TRANSFER_UNAVAILABLE") end
    if not Loot.data.runs[offer.run.id] and count(Loot.data.runs) >= MAX_RUNS then return nil, L("LOOT_STORAGE_FULL") end
    if count(Loot.incoming) >= 4 then return nil, L("SYNC_BUSY") end
    if not send("Q", offer.token, offer.sender) then return nil, L("COMMS_UNAVAILABLE") end
    Loot.incoming[key] = { run = copy(offer.run), sender = offer.sender, token = offer.token, count = 0, at = GB.Now() }
    refresh()
    return true
end
function Loot.Dismiss(key)
    local offer = Loot.offers[key]
    if offer then send("N", offer.token, offer.sender) end
    Loot.offers[key], Loot.incoming[key] = nil, nil
    refresh()
end
local function complete(key, transfer)
    local run = transfer.run
    if not transfer.ended or transfer.count ~= run.size then return end
    if fingerprint(run) ~= run.hash then
        Loot.incoming[key], Loot.offers[key] = nil, nil
        notice("LOOT_TRANSFER_INVALID"); return
    end
    local old = Loot.data.runs[run.id]
    if old and (not old.receivedFrom or not Core.SamePlayer(old.receivedFrom, transfer.sender)) then return end
    if not old and count(Loot.data.runs) >= MAX_RUNS then
        Loot.incoming[key], Loot.offers[key] = nil, nil
        notice("LOOT_STORAGE_FULL"); return
    end
    -- Repeated imports update the same source recording, never the user's own run.
    if not old or (run.finished >= old.finished and #run.items >= #old.items) then
        run.receivedFrom, run.receivedAt = transfer.sender, GB.Now()
        run.size, run.hash = nil, nil
        Loot.data.runs[run.id] = run
    end
    send("A", transfer.token, transfer.sender)
    Loot.incoming[key], Loot.offers[key] = nil, nil
    notice("LOOT_RECEIVED", run.name, transfer.sender)
end
function Loot.Receive(fields, sender)
    if not Loot.data or not GB.Guests.ValidName(sender) then return end
    local kind, token = fields[1], fields[3]
    if type(token) ~= "string" or #token > 32 or not token:match("^%d+$") then return end
    local key, now = offerKey(sender, token), GB.Now()
    if kind == "O" then
        local run = header(fields, sender)
        if not run or Loot.offers[key] or count(Loot.offers) >= 20 then return end
        local peer = Core.PlayerKey(sender)
        if offerTimes[peer] and now - offerTimes[peer] < 15 then return end
        offerTimes[peer] = now
        Loot.offers[key] = { run = run, sender = sender, token = token, at = now }
        notice("LOOT_OFFER_RECEIVED", sender, run.name)
    elseif kind == "Q" and #fields == 3 then
        local out = Loot.outgoing[token]
        if not out or out.sent or not Core.SamePlayer(out.target, sender) or now - out.at > TTL then return end
        local messages = {}
        for i, entry in ipairs(out.run.items) do
            local f = { "I", "LOOT1", token, i }
            for _, value in ipairs(entryFields(entry)) do f[#f + 1] = value end
            messages[#messages + 1] = f
        end
        messages[#messages + 1] = { "E", "LOOT1", token }
        if GB.EnqueueBatch(messages, sender) then out.sent, out.at = true, now
        else send("N", token, sender); notice("SYNC_BUSY") end
    elseif kind == "I" then
        local transfer = Loot.incoming[key]
        if not transfer or #fields ~= 11 then return end
        local run = transfer.run
        local index = integer(fields[4], 1, run.size)
        local at, itemID = integer(fields[5], run.started, run.finished + 300), integer(fields[6], 1, 10000000)
        local quality, quantity = integer(fields[8], 3, 4), integer(fields[9], 1, 100000)
        local itemString = fields[7]
        local player = GB.Guests.ValidName(fields[10])
        if not index or not at or not itemID or not quality or not quantity or not player or not plain(fields[11], 200)
            or #itemString > 512 or not itemString:match("^item:[%d:%-]+$")
            or tonumber(itemString:match("^item:(%d+)")) ~= itemID then return end
        if not run.items[index] then
            run.items[index] = { at = at, itemID = itemID, itemString = itemString, quality = quality,
                quantity = quantity, player = player, name = fields[11] }
            transfer.count = transfer.count + 1
        end
        transfer.at = now
        complete(key, transfer)
    elseif kind == "E" and #fields == 3 and Loot.incoming[key] then
        Loot.incoming[key].ended = true
        complete(key, Loot.incoming[key])
    elseif kind == "A" and #fields == 3 then
        local out = Loot.outgoing[token]
        if out and out.sent and Core.SamePlayer(out.target, sender) then
            Loot.outgoing[token] = nil; notice("LOOT_DELIVERED", sender)
        end
    elseif kind == "N" and #fields == 3 then
        local out = Loot.outgoing[token]
        if out and Core.SamePlayer(out.target, sender) then Loot.outgoing[token] = nil; notice("LOOT_DECLINED", sender) end
        if Loot.incoming[key] then Loot.incoming[key], Loot.offers[key] = nil, nil; notice("LOOT_TRANSFER_UNAVAILABLE") end
    end
    refresh()
end
function Loot.Tick()
    if not Loot.data then return end
    Loot.CheckInstance()
    Loot.ResolvePending()
    local now = GB.Now()
    for id, at in pairs(seen) do if now - at > 300 then seen[id] = nil end end
    for key, offer in pairs(Loot.offers) do
        local incoming = Loot.incoming[key]
        if now - (incoming and incoming.at or offer.at) > TTL then
            Loot.offers[key], Loot.incoming[key] = nil, nil
            if incoming then notice("LOOT_TIMEOUT") end
        end
    end
    for token, out in pairs(Loot.outgoing) do
        if now - out.at > TTL then Loot.outgoing[token] = nil; notice("LOOT_TIMEOUT") end
    end
    for sender, at in pairs(offerTimes) do if now - at > TTL then offerTimes[sender] = nil end end
end

local frame = CreateFrame("Frame")
Loot.frame = frame
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_LOGOUT", "CHAT_MSG_LOOT", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, ...)
    if not Loot.data then return end
    if event == "CHAT_MSG_LOOT" then Loot.OnLoot((...), select(11, ...))
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then Loot.ResolvePending(); refresh()
    else Loot.CheckInstance(); refresh() end
end)
