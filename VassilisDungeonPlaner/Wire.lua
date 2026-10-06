local _, GB = ...
local Wire = {}
GB.Wire = Wire
local concat = table.concat

function Wire.Encode(fields)
    local out = {}
    for i, value in ipairs(fields) do
        out[i] = tostring(value):gsub("[%%~|%c%z]", function(c) return string.format("%%%02X", c:byte()) end)
    end
    return concat(out, "~")
end
function Wire.Decode(body)
    if type(body) ~= "string" or #body > 4096 then return nil end
    local out = {}
    for field in (body .. "~"):gmatch("(.-)~") do
        if #out >= 20 or field:gsub("%%[0-9A-Fa-f][0-9A-Fa-f]", ""):find("%%") then return nil end
        out[#out + 1] = field:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    end
    return out
end
function Wire.Packets(body, id)
    if #body > 4096 then return nil end
    local out, chunks, start = {}, {}, 1
    repeat
        local finish = math.min(#body, start + 179)
        -- Logged addon messages must remain printable, valid UTF-8 per packet.
        while finish >= start and body:byte(finish + 1) and body:byte(finish + 1) >= 128 and body:byte(finish + 1) < 192 do finish = finish - 1 end
        if finish < start then return nil end
        chunks[#chunks + 1] = body:sub(start, finish)
        start = finish + 1
    until start > #body
    for i, chunk in ipairs(chunks) do out[i] = "1:" .. id .. ":" .. i .. ":" .. #chunks .. ":" .. chunk end
    return out
end
function Wire.New(clock)
    return setmetatable({ pending = {}, clock = clock }, { __index = Wire })
end
function Wire:Receive(sender, packet)
    if type(packet) ~= "string" or #packet > 255 then return nil end
    local id, index, total, chunk = packet:match("^1:([%w]+):(%d+):(%d+):(.*)$")
    index, total = tonumber(index), tonumber(total)
    if not id or #id > 32 or not index or not total or total < 1 or total > 24 or index < 1 or index > total or #chunk > 180 then return nil end
    local now, count, senderCount = self.clock(), 0, 0
    for key, p in pairs(self.pending) do
        if now - p.at > 30 then self.pending[key] = nil
        else count = count + 1; if p.sender == sender then senderCount = senderCount + 1 end end
    end
    local key = sender .. ":" .. id
    local p = self.pending[key]
    if not p then
        if count >= 64 or senderCount >= 4 then return nil end
        p = { total = total, at = now, parts = {}, count = 0, sender = sender }
        self.pending[key] = p
    end
    if p.total ~= total or (p.parts[index] and p.parts[index] ~= chunk) then self.pending[key] = nil; return nil end
    if not p.parts[index] then p.parts[index] = chunk; p.count = p.count + 1 end
    if p.count == total then
        self.pending[key] = nil
        local body = concat(p.parts)
        if #body <= 4096 then return body end
    end
end
