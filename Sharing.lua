local _, R = ...
-- Length-prefixed data, never executable Lua. Parser is bounded before validation.
local function encode(value)
    local kind = type(value)
    if kind == "boolean" then return value and "T" or "F" end
    if kind == "number" then return "N" .. tostring(value) .. ";" end
    if kind == "string" then return "S" .. #value .. ":" .. value end
    if kind == "table" then
        local result = { "{" }
        for key, item in pairs(value) do
            result[#result + 1] = encode(key)
            result[#result + 1] = encode(item)
        end
        result[#result + 1] = "}"
        return table.concat(result)
    end
    error("Unsupported value")
end

local function decode(text)
    assert(#text <= 300000, "Set is too large")
    local pos, nodes = 1, 0
    local function read(depth)
        nodes = nodes + 1
        assert(depth <= 12 and nodes <= 40000, "Set is too complex")
        local tag = text:sub(pos, pos)
        pos = pos + 1
        if tag == "T" then return true elseif tag == "F" then return false end
        if tag == "N" or tag == "S" then
            local finish = text:find(tag == "N" and ";" or ":", pos, true)
            assert(finish and finish - pos <= 24, "Invalid value")
            local number = tonumber(text:sub(pos, finish - 1))
            assert(number and number == number and math.abs(number) < math.huge, "Invalid number")
            pos = finish + 1
            if tag == "N" then return number end
            assert(number >= 0 and number % 1 == 0 and number <= 10000 and pos + number - 1 <= #text, "Invalid string")
            local value = text:sub(pos, pos + number - 1)
            pos = pos + number
            return value
        end
        assert(tag == "{", "Invalid token")
        local value = {}
        while text:sub(pos, pos) ~= "}" do
            assert(pos <= #text, "Truncated set")
            local key = read(depth + 1)
            assert(type(key) == "string" or type(key) == "number", "Invalid key")
            assert(value[key] == nil, "Duplicate key")
            value[key] = read(depth + 1)
        end
        pos = pos + 1
        return value
    end
    local result = read(0)
    assert(pos == #text + 1, "Trailing data")
    return result
end

local function stringValue(value, limit)
    assert(type(value) == "string" and #value > 0 and #value <= limit, "Invalid text")
    return value
end
local function integer(value)
    assert(type(value) == "number" and value > 0 and value <= 2147483647 and value % 1 == 0, "Invalid ID")
    return value
end
local function mode(value)
    assert(value == "auto" or value == "instant" or value == "casting" or value == "channel", "Invalid action type")
    return value
end
local function config(value)
    assert(type(value) == "table", "Missing sounds")
    local result = R.EmptyConfig()
    for _, moment in ipairs(R.Moments) do
        assert(type(value[moment]) == "table" and #value[moment] <= 16, "Too many layers")
        for _, layer in ipairs(value[moment]) do
            local sound = stringValue(layer.sound, 40)
            local kind, id = sound:match("^(%a+):(%d+)$")
            assert(kind == "file" or kind == "kit", "Invalid sound type")
            integer(tonumber(id))
            assert(type(layer.delay) == "number" and layer.delay >= 0 and layer.delay <= 30000, "Invalid delay")
            table.insert(result[moment], { sound = sound, delay = layer.delay, enabled = layer.enabled ~= false })
        end
    end
    return result
end

function R:ValidateSet(source)
    assert(type(source) == "table" and source.version == 1, "Unsupported set version")
    assert(source.class == self.Profile.class, "This set belongs to another class")
    assert(type(source.cards) == "table" and #source.cards <= 200, "Too many actions")
    assert(type(source.sections) == "table" and #source.sections > 0 and #source.sections <= 40, "Invalid sections")
    local clean = { version = 1, class = source.class, cards = {}, sections = {} }
    local sections, keys, rankNames, spellIDs = {}, {}, {}, {}
    for _, name in ipairs(source.sections) do
        stringValue(name, 48)
        assert(not sections[name], "Duplicate section")
        sections[name] = true
        table.insert(clean.sections, name)
    end
    for _, card in ipairs(source.cards) do
        assert(card.kind == "spell" or card.kind == "item", "Invalid action")
        local c = { kind = card.kind, spellID = integer(card.spellID), name = stringValue(card.name, 200),
            section = card.section, enabled = card.enabled ~= false, ranked = card.ranked == true,
            mode = mode(card.mode), perRank = card.perRank == true, ranks = {}, overrides = {}, config = config(card.config) }
        if c.kind == "item" then c.itemID = integer(card.itemID); c.ranked = false; c.perRank = false end
        c.key = c.kind .. ":" .. tostring(c.itemID or c.spellID)
        assert(not keys[c.key] and sections[c.section], "Duplicate action or unknown section")
        keys[c.key] = true
        if c.ranked then assert(not rankNames[c.name], "Duplicate spell family"); rankNames[c.name] = true end
        if type(card.icon) == "number" then c.icon = integer(card.icon) else c.icon = 134400 end
        assert(type(card.ranks) == "table" and type(card.overrides) == "table", "Missing ranks")
        local count = 0
        for id, rank in pairs(card.ranks) do
            integer(id); count = count + 1
            assert(not spellIDs[id], "Two actions share the same activation spell")
            spellIDs[id] = true
            assert(count <= 100 and type(rank) == "table", "Invalid ranks")
            assert(type(rank.label) == "string" and #rank.label <= 100, "Invalid rank label")
            c.ranks[id] = { label = rank.label, mode = mode(rank.mode) }
            if card.overrides[id] then c.overrides[id] = config(card.overrides[id]) end
        end
        assert(c.ranks[c.spellID], "Missing primary rank")
        table.insert(clean.cards, c)
    end
    return clean
end

function R:Snapshot()
    return self.Copy({ version = 1, class = self.Profile.class, cards = self.Profile.cards, sections = self.Profile.sections })
end

function R:ExportSet()
    return "RESONANCE-FOREVER-1:" .. encode(self:Snapshot())
end

function R:ReadImport(text)
    if type(text) ~= "string" or #text > 300020 then return nil, "Set is too large." end
    text = text:match("^%s*(.-)%s*$")
    local payload = text:match("^RESONANCE%-FOREVER%-1:(.+)$")
    if not payload then return nil, "Paste a Resonance Forever sound set." end
    local ok, clean = pcall(function() return self:ValidateSet(decode(payload)) end)
    if not ok then return nil, "Cannot import: " .. tostring(clean):gsub("^.-:%d+: ", "") end
    return clean
end

function R:ApplySet(source, name)
    -- Capture the target before detaching the old active set or replacing backups.
    if name and (name ~= "Before last load") and self.Profile.sets[name] ~= source then
        return nil, "That saved set is no longer available."
    end
    local ok, clean = pcall(function() return self:ValidateSet(source) end)
    if not ok then return nil, tostring(clean) end
    self:StopAll()
    self:DetachActiveSet()
    self.Profile.sets["Before last load"] = self:Snapshot()
    self.Profile.cards, self.Profile.sections = clean.cards, clean.sections
    self.Profile.activeSetName = name ~= "Before last load" and name or nil
    self:SyncActiveSet()
    self.selected, self.selectedRank = nil, nil
    self:Reindex()
    self:DiscoverRanks()
    self:Changed()
    return true
end

function R:SaveActiveSet()
    local name = self.Profile.activeSetName or "Default"
    return self:SaveSet(name)
end

function R:SaveSet(name)
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 48 or name == "Before last load" then return nil, "Choose a name of 1–48 characters." end
    self:DetachActiveSet()
    self.Profile.activeSetName = name
    self:SyncActiveSet()
    return true
end
