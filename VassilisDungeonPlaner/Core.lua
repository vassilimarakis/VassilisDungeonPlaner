local _, GB = ...
local L = GB.L
GB.VERSION = "0.4.0"
GB.NAME = "Vassilis DungeonPlaner"
GB.Core = {}
local Core = GB.Core
local floor, concat = math.floor, table.concat
local roles = { TANK = true, HEALER = true, DAMAGER = true }
local responses = { YES = true, MAYBE = true, NO = true }
local decisions = { CONFIRMED = true, BENCH = true, PENDING = true }
local activities = { RAID = true, DUNGEON = true, OTHER = true }
Core.schemas = {
    E = { "kind", "author", "event", "rev", "stamp", "title", "activity", "start", "capacity", "note", "cancelled", "scope" },
    S = { "kind", "author", "event", "rev", "stamp", "role", "response", "note", "class", "level" },
    M = { "kind", "author", "event", "rev", "stamp", "player", "role", "response", "note", "class", "source", "level" },
    D = { "kind", "author", "event", "rev", "stamp", "player", "signupRev", "decision", "signupKind" },
}
local numeric = { rev = true, stamp = true, start = true, capacity = true, cancelled = true, signupRev = true, level = true }

function Core.Clean(value, limit)
    value = tostring(value or ""):gsub("|", ""):gsub("[%z\1-\8\11-\31\127]", "")
    if #value <= limit then return value end
    local cut = limit
    -- Do not cut through a UTF-8 code point.
    while cut > 0 and value:byte(cut + 1) and value:byte(cut + 1) >= 128 and value:byte(cut + 1) < 192 do cut = cut - 1 end
    return value:sub(1, cut)
end

function Core.Trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
local fold = {}
local upper, lower = {}, {}
for ch in ("ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞŸŒŠŽĄĆĘŁŃŚŹŻАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"):gmatch("[%z\1-\127\194-\244][\128-\191]*") do upper[#upper + 1] = ch end
-- Map explicitly; WoW's Lua string.lower is ASCII-only on many clients.
for ch in ("àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿœšžąćęłńśźżабвгдеёжзийклмнопрстуфхцчшщъыьэюя"):gmatch("[%z\1-\127\194-\244][\128-\191]*") do lower[#lower + 1] = ch end
for i, ch in ipairs(upper) do fold[ch] = lower[i] end
function Core.PlayerKey(name)
    local value = tostring(name or ""):gsub("[ \t\r\n]", ""):gsub("[A-Z]", string.lower)
    return value:gsub("[%z\1-\127\194-\244][\128-\191]*", function(ch) return fold[ch] or ch end)
end
function Core.SamePlayer(a, b) return Core.PlayerKey(a) == Core.PlayerKey(b) end
function Core.Player(r) return r.kind == "M" and r.player or r.author end
function Core.Owner(id) return type(id) == "string" and id:match("^([^@]+)@%d+%.%d+%.%d+$") end
local function text(value, limit, nonempty)
    return type(value) == "string" and #value <= limit and (not nonempty or #Core.Trim(value) > 0)
        and not value:find("[%z\1-\8\11-\31\127|]")
end
local function integer(value, low, high)
    return type(value) == "number" and value == floor(value) and value >= low and value <= high
end
function Core.Key(r)
    if r.kind == "E" then return "E/" .. r.event end
    return r.kind .. "/" .. r.event .. "/" .. Core.PlayerKey(r.kind == "S" and r.author or r.player)
end
function Core.Copy(r)
    local out = {}
    for _, key in ipairs(Core.schemas[r.kind] or {}) do out[key] = r[key] end
    return out
end
function Core.Canonical(r)
    local out = {}
    for _, key in ipairs(Core.schemas[r.kind] or {}) do
        local s = tostring(r[key])
        out[#out + 1] = #s .. ":" .. s
    end
    return concat(out)
end
function Core.ToFields(r)
    local out = {}
    for _, key in ipairs(Core.schemas[r.kind] or {}) do out[#out + 1] = tostring(r[key]) end
    return out
end
function Core.FromFields(fields)
    local schema = Core.schemas[fields[1]]
    if not schema or #fields ~= #schema then return nil end
    local r = {}
    for i, key in ipairs(schema) do
        r[key] = numeric[key] and tonumber(fields[i]) or fields[i]
        if numeric[key] and type(r[key]) ~= "number" then return nil end
    end
    return r
end
function Core.Validate(r, now)
    if type(r) ~= "table" or not Core.schemas[r.kind] then return false end
    if not text(r.author, 100, true) or not r.author:find("-", 1, true) or r.author:find("[@/\t\n]") then return false end
    if not text(r.event, 160, true) or not Core.Owner(r.event) then return false end
    if not integer(r.rev, 1, (now + 600) * 1000) or not integer(r.stamp, 1, now + 600) then return false end
    if r.kind == "E" then
        return Core.SamePlayer(Core.Owner(r.event), r.author) and text(r.title, 80, true) and activities[r.activity] == true
            and integer(r.start, now - 30 * 86400, now + 366 * 86400)
            and integer(r.capacity, 1, 40) and text(r.note, 500) and integer(r.cancelled, 0, 1) and text(r.scope, 160)
    elseif r.kind == "S" or r.kind == "M" then
        if r.kind == "M" and (not Core.SamePlayer(Core.Owner(r.event), r.author) or not text(r.player, 100, true)
            or not r.player:find("-", 1, true) or r.player:find("[@/\t\n]")
            or (r.source ~= "MANUAL" and r.source ~= "WHISPER")) then return false end
        return roles[r.role] == true and (responses[r.response] == true or (r.kind == "M" and r.response == "INVITED")) and text(r.note, 120)
            and text(r.class, 20, true) and r.class:match("^[A-Z]+$") ~= nil and integer(r.level, 0, 255)
    else
        return Core.SamePlayer(Core.Owner(r.event), r.author) and text(r.player, 100, true) and r.player:find("-", 1, true) ~= nil
            and not r.player:find("[@/\t\n]") and integer(r.signupRev, 1, (now + 600) * 1000)
            and decisions[r.decision] == true and (r.signupKind == "S" or r.signupKind == "M")
    end
end

function Core.New(db, actor, guild, clock)
    db.guilds = db.guilds or {}
    db.guilds[guild] = db.guilds[guild] or { records = {}, counter = 0 }
    local data = db.guilds[guild]
    data.records = data.records or {}
    data.counter = tonumber(data.counter) or 0
    data.accepted, data.invites, data.inbox = data.accepted or {}, data.invites or {}, data.inbox or {}
    local self = { data = data, actor = actor, guild = guild, scope = guild, clock = clock, size = 0 }
    setmetatable(self, { __index = Core })
    local expired = {}
    for _, r in pairs(data.records) do
        if type(r) == "table" and r.kind == "E" and type(r.event) == "string" and type(r.start) == "number" and r.start < clock() - 30 * 86400 then expired[r.event] = true end
    end
    for key, r in pairs(data.records) do
        -- Saved 0.1/0.2 signups have no level. Preserve their revisions so
        -- existing confirmations remain attached after the upgrade.
        if type(r) == "table" and (r.kind == "S" or r.kind == "M") and r.level == nil then r.level = 0 end
        if not Core.Validate(r, clock()) or expired[r.event] or Core.Key(r) ~= key then data.records[key] = nil else self.size = self.size + 1 end
    end
    return self
end
function Core:GetEvent(id) return self.data.records["E/" .. id] end
function Core:GetSignup(id, player)
    local key = id .. "/" .. Core.PlayerKey(player)
    local s, m = self.data.records["S/" .. key], self.data.records["M/" .. key]
    if m and (not s or m.rev > s.rev) then return m end
    return s
end
function Core:GetDecision(id, player) return self.data.records["D/" .. id .. "/" .. Core.PlayerKey(player)] end
function Core:Visible(e)
    return Core.SamePlayer(e.author, self.actor) or (e.scope ~= "" and e.scope == self.scope) or self.data.accepted[e.event] ~= nil
end

-- Cached records are relayed inside one trusted guild. Direct writes are bound
-- to the transport sender. Relays cannot provide cryptographic author identity.
function Core:Merge(r, sender, relay)
    if not Core.Validate(r, self.clock()) then return false, "invalid" end
    if not relay and not Core.SamePlayer(r.author, sender) then return false, "author" end
    local key = Core.Key(r)
    local old = self.data.records[key]
    if old and (r.rev < old.rev or (r.rev == old.rev and Core.Canonical(r) <= Core.Canonical(old))) then return false, "old" end
    if not old and self.size >= 6000 then return false, "limit" end
    self.data.records[key] = Core.Copy(r)
    if not old then self.size = self.size + 1 end
    return true
end
function Core:Commit(r)
    local old = self.data.records[Core.Key(r)]
    r.stamp = self.clock()
    r.rev = math.max(r.stamp * 1000, old and old.rev + 1 or 1)
    if r.kind == "S" or r.kind == "M" then
        local effective = self:GetSignup(r.event, Core.Player(r))
        r.rev = math.max(r.rev, effective and effective.rev + 1 or 1)
    end
    local ok, why = self:Merge(r, self.actor, false)
    if not ok then return nil, L("SAVE_FAILED", why) end
    if self.onWrite then self.onWrite(r) end
    return r
end
function Core:SaveEvent(id, title, activity, start, capacity, note, scope)
    local previous = id and self:GetEvent(id)
    if id and (not previous or not Core.SamePlayer(previous.author, self.actor)) then return nil, L("OWNER_EDIT_ONLY") end
    if not start or start < self.clock() - 3600 then return nil, L("FUTURE_REQUIRED") end
    if previous and previous.cancelled == 1 then return nil, L("ALREADY_CANCELLED") end
    if previous and capacity and capacity < self:Counts(id).confirmed then return nil, L("CAPACITY_TOO_SMALL") end
    if not id then
        self.data.counter = self.data.counter + 1
        id = self.actor .. "@" .. self.clock() .. "." .. math.random(100000, 999999) .. "." .. self.data.counter
    end
    local r = { kind = "E", author = self.actor, event = id, title = Core.Trim(Core.Clean(title, 80)),
        activity = activity, start = start, capacity = capacity, note = Core.Clean(note, 500), cancelled = 0,
        scope = previous and previous.scope or scope or self.scope or "" }
    return self:Commit(r)
end
function Core:Cancel(id)
    local e = self:GetEvent(id)
    if not e or not Core.SamePlayer(e.author, self.actor) then return nil, L("OWNER_CANCEL_ONLY") end
    local r = Core.Copy(e)
    r.cancelled = 1
    return self:Commit(r)
end
function Core:SignUp(id, role, response, note, class, level)
    local e = self:GetEvent(id)
    if not e or not self:Visible(e) or e.cancelled == 1 or e.start < self.clock() then return nil, L("EVENT_CLOSED") end
    note, class = Core.Clean(note, 120), class or "UNKNOWN"
    local old = self:GetSignup(id, self.actor)
    level = level or (old and old.level) or 0
    if old and old.kind == "S" and old.role == role and old.response == response and old.note == note and old.class == class and old.level == level then return old end
    return self:Commit({ kind = "S", author = self.actor, event = id, role = role, response = response,
        note = note, class = class, level = level })
end
function Core:SetManual(id, player, role, response, note, source, level)
    local e = self:GetEvent(id)
    if not e or not Core.SamePlayer(e.author, self.actor) then return nil, L("OWNER_ADD_ONLY") end
    if e.cancelled == 1 or e.start < self.clock() then return nil, L("EVENT_CLOSED") end
    local previous = self:GetSignup(id, player)
    note = Core.Clean(note, 120)
    level = level or (previous and previous.level) or 0
    if previous and previous.role == role and previous.response == response and previous.note == note and previous.level == level then return previous end
    return self:Commit({ kind = "M", author = self.actor, event = id, player = player, role = role, response = response,
        note = note, class = previous and previous.class or "UNKNOWN", source = source or "MANUAL", level = level })
end
function Core:Status(id, player)
    local s = self:GetSignup(id, player)
    if not s then return "NONE" end
    if s.response ~= "YES" then return s.response end
    local d = self:GetDecision(id, player)
    if d and d.signupRev == s.rev and d.signupKind == s.kind then return d.decision end
    return "PENDING"
end
function Core:Decide(id, player, decision)
    local e, s = self:GetEvent(id), self:GetSignup(id, player)
    if not e or not Core.SamePlayer(e.author, self.actor) then return nil, L("OWNER_CONFIRM_ONLY") end
    if e.cancelled == 1 or e.start < self.clock() then return nil, L("EVENT_CLOSED") end
    if not s or s.response ~= "YES" then return nil, L("NOT_ACCEPTED") end
    if decision == "CONFIRMED" and self:Status(id, player) ~= "CONFIRMED" and self:Counts(id).confirmed >= e.capacity then
        return nil, L("CAPACITY_FULL")
    end
    return self:Commit({ kind = "D", author = self.actor, event = id, player = player, signupRev = s.rev, signupKind = s.kind, decision = decision })
end
function Core:Participants(id)
    local out, seen = {}, {}
    local order = { CONFIRMED = 1, PENDING = 2, BENCH = 3, MAYBE = 4, INVITED = 5, NO = 6 }
    for _, r in pairs(self.data.records) do
        if (r.kind == "S" or r.kind == "M") and r.event == id then
            local player = Core.Player(r)
            if not seen[Core.PlayerKey(player)] then out[#out + 1] = self:GetSignup(id, player); seen[Core.PlayerKey(player)] = true end
        end
    end
    table.sort(out, function(a, b)
        local x, y = order[self:Status(id, Core.Player(a))], order[self:Status(id, Core.Player(b))]
        if x ~= y then return x < y end
        if a.role ~= b.role then return a.role < b.role end
        return Core.PlayerKey(Core.Player(a)) < Core.PlayerKey(Core.Player(b))
    end)
    return out
end
function Core:Counts(id)
    local out = { yes = 0, confirmed = 0, TANK = 0, HEALER = 0, DAMAGER = 0 }
    for _, s in ipairs(self:Participants(id)) do
        if s.response == "YES" then
            out.yes = out.yes + 1
            out[s.role] = out[s.role] + 1
        end
        if self:Status(id, Core.Player(s)) == "CONFIRMED" then out.confirmed = out.confirmed + 1 end
    end
    return out
end
function Core:Events(filter, search, history)
    local out = {}
    search = string.lower(search or "")
    for _, r in pairs(self.data.records) do
        if r.kind == "E" and self:Visible(r) and (history or (r.cancelled == 0 and r.start >= self.clock() - 3 * 3600))
            and (filter == "ALL" or filter == r.activity or (filter == "MINE" and (Core.SamePlayer(r.author, self.actor) or self:GetSignup(r.event, self.actor))))
            and (search == "" or string.lower(r.title):find(search, 1, true)) then out[#out + 1] = r end
    end
    table.sort(out, function(a, b) if a.start ~= b.start then return a.start < b.start end return a.event < b.event end)
    return out
end
