local _, R = ...

function R.Safe(value)
    return not (issecretvalue and issecretvalue(value))
end

function R.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if not ok then return nil end
    if not R.Safe(a) or not R.Safe(b) or not R.Safe(c) then return nil end
    return a, b, c, d, e, f, g, h, i, j
end

-- Name and rank only: cheap enough for every cast and spellbook scan.
-- Returns name, rank, ranked, icon, castTime.
function R:SpellIdentity(id)
    if not self.Safe(id) or type(id) ~= "number" or id <= 0 then return end
    local info = self.Call(C_Spell and C_Spell.GetSpellInfo, id)
    local name, rank, icon, castTime
    if info and self.Safe(info) then
        name, icon, castTime = info.name, info.iconID, info.castTime
        rank = self.Call(C_Spell.GetSpellSubtext, id)
    else
        name, rank, icon, castTime = self.Call(GetSpellInfo, id)
    end
    if not self.Safe(name) or not self.Safe(icon) or not self.Safe(castTime)
        or type(name) ~= "string" then return end
    rank = self.Safe(rank) and type(rank) == "string" and rank or ""
    -- Rank metadata, not GetBaseSpell (which describes overrides, not rank chains).
    return name, rank, rank:match("%d+") ~= nil, icon, castTime
end

-- Full action details, including the channel check that needs tooltip data.
function R:SpellInfo(id)
    local name, rank, ranked, icon, castTime = self:SpellIdentity(id)
    if not name then return end
    local mode = (tonumber(castTime) or 0) > 0 and "casting" or "instant"
    local tooltip = self.Call(C_TooltipInfo and C_TooltipInfo.GetSpellByID, id)
    local channelLabel = SPELL_CAST_CHANNELED or "Channeled"
    if tooltip and self.Safe(tooltip) and tooltip.lines then
        for _, line in ipairs(tooltip.lines) do
            for _, field in ipairs({ "leftText", "rightText" }) do
                local text = line[field]
                if self.Safe(text) and type(text) == "string" and text:find(channelLabel, 1, true) then
                    mode = "channel"
                end
            end
        end
    end
    return { kind = "spell", spellID = id, name = name, icon = icon or 134400,
        rank = rank, ranked = ranked, mode = mode }
end

function R:ItemAction(id)
    local item = C_Item or {}
    local name, _, _, _, _, _, _, _, _, icon = self.Call(item.GetItemInfo or GetItemInfo, id)
    if not name then
        self.Call(item.RequestLoadItemDataByID, id)
        return nil, "Item details are still loading. Drop it again in a moment."
    end
    local _, spellID = self.Call(item.GetItemSpell or GetItemSpell, id)
    if not spellID then return nil, "This item has no identifiable use spell. Passive items cannot trigger a sound." end
    local spell = self:SpellInfo(spellID)
    if not spell then return nil, "The item's use spell is not available yet. Try dropping it again." end
    return { kind = "item", itemID = id, spellID = spellID, name = name,
        icon = self.Safe(icon) and icon or spell.icon, mode = spell.mode, rank = "", ranked = false }
end

function R:CursorAction()
    local kind, id, subtype, extra = self.Call(GetCursorInfo)
    if not self.Safe(extra) then return nil, "That action is protected." end
    if kind == "spell" then
        local spellID = tonumber(extra)
        -- Older spell cursors carry a spellbook slot, not a spell ID.
        if not spellID and type(subtype) == "string" then
            local _, legacyID = self.Call(GetSpellBookItemInfo, id, subtype)
            spellID = legacyID
        end
        spellID = spellID or tonumber(id)
        local info = self:SpellInfo(spellID)
        if not info then return nil, "Spell details are unavailable. Try dropping it again." end
        if self.Call(C_Spell and C_Spell.IsSpellPassive or IsPassiveSpell, spellID) then
            return nil, "Passive abilities have no cast to attach sounds to. Drop an active ability."
        end
        return info
    elseif kind == "item" or kind == "toy" then
        id = tonumber(id) or (type(subtype) == "string" and tonumber(subtype:match("item:(%d+)")))
        if id then return self:ItemAction(id) end
    elseif kind == "mount" or kind == "summonmount" then
        local _, spellID = self.Call(C_MountJournal and C_MountJournal.GetMountInfoByID, id)
        return self:SpellInfo(spellID)
    end
    return nil, "Drag a spell, active ability, mount, or usable item here. Macros are not supported."
end

function R:DiscoverRanks()
    if not self.Profile then return end
    -- Most spellbook entries belong to no ranked card; identify them cheaply and
    -- read tooltip data only for a new rank of a configured spell family.
    local function visit(id)
        if type(id) ~= "number" then return end
        local name, rank, ranked = self:SpellIdentity(id)
        local card = ranked and self.RankedNames[name]
        if not card then return end
        local known = card.ranks[id]
        if known and known.mode then
            known.label = rank
            return
        end
        local info = self:SpellInfo(id)
        if info then card.ranks[id] = { label = info.rank, mode = info.mode } end
    end
    local book = C_SpellBook
    if book and book.GetNumSpellBookSkillLines then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        for index = 1, self.Call(book.GetNumSpellBookSkillLines) or 0 do
            local line = self.Call(book.GetSpellBookSkillLineInfo, index)
            if line then
                for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local entry = self.Call(book.GetSpellBookItemInfo, slot, bank)
                    if entry then visit(entry.spellID) end
                end
            end
        end
    elseif GetNumSpellTabs then
        for index = 1, self.Call(GetNumSpellTabs) or 0 do
            local _, _, offset, count = self.Call(GetSpellTabInfo, index)
            for slot = (offset or 0) + 1, (offset or 0) + (count or 0) do
                local _, id = self.Call(GetSpellBookItemInfo, slot, BOOKTYPE_SPELL or "spell")
                visit(id)
            end
        end
    end
    self:Reindex()
end

function R:DropAction(section)
    local action, err = self:CursorAction()
    if not action then self:Status(err or "That action is unavailable."); return end
    local card, added, addError = self:AddAction(action)
    if not card then self:Status(addError); return end
    if added and section then card.section = section end
    self:DiscoverRanks()
    ClearCursor()
    self.selected, self.selectedRank = card, nil
    self:RefreshUI()
    self:Status(added and "Action added. Choose a sound to begin." or "Selected the existing action; ranks share sounds by default.")
end
