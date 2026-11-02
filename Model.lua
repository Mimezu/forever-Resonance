local _, R = ...
_G.ResonanceForever = R
R.VERSION = "2.0.0-forever.11"
R.Moments = { "cast", "casting", "channel" }
R.MomentLabels = { cast = "Cast", casting = "Casting", channel = "Channeling" }

function R.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = R.Copy(v) end
    return copy
end

function R.EmptyConfig()
    return { cast = {}, casting = {}, channel = {} }
end

function R:Initialize(db, characterKey, class)
    self.DB = type(db) == "table" and db or {}
    local d = self.DB
    d.version = 1
    d.characters = d.characters or {}
    d.favorites = d.favorites or {}
    d.customSounds = d.customSounds or {}
    d.soundChecks = d.soundChecks or {}
    d.channel = d.channel or "SFX"
    d.characters[characterKey] = d.characters[characterKey] or {
        class = class, cards = {}, sections = { "My actions" }, sets = {}, enabled = true,
    }
    self.Profile = d.characters[characterKey]
    self.Profile.class = class
    self.Profile.sets = self.Profile.sets or {}
    self.Profile.sections = self.Profile.sections or { "My actions" }
    self.Profile.cards = self.Profile.cards or {}
    self:SyncActiveSet()
    self:Reindex()
end

function R:SyncActiveSet()
    local p = self.Profile
    local name = p and p.activeSetName
    if type(name) ~= "string" or name == "" or name == "Before last load" then
        if p then p.activeSetName = nil end
        return
    end
    -- The working tables are authoritative, including after SavedVariables
    -- reloads (which deserialize repeated table references as separate tables).
    p.sets[name] = { version = 1, class = p.class, cards = p.cards, sections = p.sections }
end

function R:DetachActiveSet()
    local p = self.Profile
    if p.activeSetName then
        self:SyncActiveSet()
        p.sets[p.activeSetName] = self.Copy(p.sets[p.activeSetName])
        p.activeSetName = nil
    end
end

function R:Reindex()
    self.BySpell, self.ByItem, self.RankedNames = {}, {}, {}
    -- Spells already checked and found to belong to no card; valid until the cards change.
    self.NoCard = {}
    for _, card in ipairs(self.Profile.cards) do
        if card.kind == "item" then
            self.ByItem[card.itemID] = card
        elseif card.ranked then
            self.RankedNames[card.name] = card
        end
        for spellID in pairs(card.ranks) do
            -- A spell card is authoritative when an item shares its activation spell.
            local old = self.BySpell[spellID]
            if not old or card.kind == "spell" then self.BySpell[spellID] = card end
        end
    end
end

function R:Changed()
    self:Reindex()
    if self.RefreshUI then self:RefreshUI() end
end

function R:AddAction(action)
    local existing = action.kind == "item" and self.ByItem[action.itemID]
        or (action.kind == "spell" and self.BySpell[action.spellID])
    if existing and existing.kind ~= action.kind then existing = nil end
    if not existing and action.kind == "spell" and action.ranked then
        existing = self.RankedNames[action.name]
    end
    if not existing and self.BySpell[action.spellID] then
        return nil, false, "This uses the same activation spell as ‘" .. self.BySpell[action.spellID].name
            .. "’. Edit that action; the client cannot distinguish these activations."
    end
    if existing then
        local known = existing.ranks[action.spellID]
        existing.ranks[action.spellID] = { label = action.rank or "", mode = known and known.mode or action.mode }
        self:Changed()
        return existing, false
    end
    if #self.Profile.cards >= 200 then return nil, false, "This setup supports up to 200 actions." end
    local card = {
        key = action.kind .. ":" .. tostring(action.itemID or action.spellID),
        kind = action.kind, itemID = action.itemID, spellID = action.spellID,
        name = action.name, icon = action.icon, ranked = action.ranked == true,
        section = self.Profile.sections[1], enabled = true, mode = "auto",
        ranks = { [action.spellID] = { label = action.rank or "", mode = action.mode } },
        config = self.EmptyConfig(), overrides = {}, perRank = false,
    }
    table.insert(self.Profile.cards, card)
    self:Changed()
    return card, true
end

function R:GetConfig(card, rankID, edit)
    if card.perRank and rankID then
        if edit and not card.overrides[rankID] then
            card.overrides[rankID] = self.Copy(card.config)
        end
        return card.overrides[rankID] or card.config
    end
    return card.config
end

function R:GetMode(card, spellID)
    if card.mode ~= "auto" then return card.mode end
    local rank = card.ranks[spellID or card.spellID]
    return rank and rank.mode or "instant"
end

function R:FindCard(spellID)
    local card = self.BySpell[spellID]
    if card then return card end
    -- Casts of unconfigured spells arrive constantly. Remember misses, and read
    -- tooltip data only for a new rank of a configured spell family.
    local noCard = self.NoCard
    if noCard and noCard[spellID] then return end
    local name, _, ranked = self:SpellIdentity(spellID)
    card = ranked and self.RankedNames[name]
    if not card then
        if noCard then noCard[spellID] = true end
        return
    end
    local info = self:SpellInfo(spellID)
    if not info then return end
    card.ranks[spellID] = { label = info.rank, mode = info.mode }
    self.BySpell[spellID] = card
    return card
end

function R:RemoveCard(card)
    if self.StopAll then self:StopAll() end
    for i, candidate in ipairs(self.Profile.cards) do
        if candidate == card then table.remove(self.Profile.cards, i); break end
    end
    self:Changed()
end

function R:MoveCard(card, target)
    if card == target then return end
    local cards = self.Profile.cards
    for i, c in ipairs(cards) do if c == card then table.remove(cards, i); break end end
    for i, c in ipairs(cards) do
        if c == target then card.section = target.section; table.insert(cards, i, card); self:Changed(); return end
    end
    cards[#cards + 1] = card
    self:Changed()
end

function R:AddSection(name)
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 48 then return nil, "Use a section name of 1–48 characters." end
    for _, existing in ipairs(self.Profile.sections) do
        if existing == name then return nil, "That section already exists." end
    end
    if #self.Profile.sections >= 40 then return nil, "This setup supports up to 40 sections." end
    table.insert(self.Profile.sections, name)
    self:Changed()
    return true
end
