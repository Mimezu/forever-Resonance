-- Run from client root: lua Interface/AddOns/Resonance/tests/Behavior.lua
local root = "Interface/AddOns/Resonance/"
local R, now, plays, stops, cursor = {}, 0, {}, {}, nil
local checked = 0
local function check(value, message)
    checked = checked + 1
    assert(value, message)
end
local spells = {
    [100] = { name = "Fireball", rank = "Rank 1", cast = 2000 },
    [101] = { name = "Fireball", rank = "Rank 2", cast = 2500 },
    [102] = { name = "Fireball", rank = "Rank 3", cast = 3000 },
    [110] = { name = "Fireball", rank = "", cast = 0 }, -- same-name unrelated spell
    [200] = { name = "Blink", rank = "", cast = 0 },
    [300] = { name = "Drain", rank = "Rank 1", cast = 0, channel = true },
    [400] = { name = "Potion", rank = "", cast = 0 },
    [500] = { name = "Passive", rank = "", cast = 0, passive = true },
}
GetTime = function() return now end
GetCursorInfo = function() if cursor then return unpack(cursor) end end
ClearCursor = function() cursor = nil end
C_Spell = {
    GetSpellInfo = function(id)
        local s = spells[id]
        if s then return { name = s.name, iconID = 134400, castTime = s.cast } end
    end,
    GetSpellSubtext = function(id) return spells[id] and spells[id].rank end,
    IsSpellPassive = function(id) return spells[id] and spells[id].passive end,
}
C_TooltipInfo = { GetSpellByID = function(id)
    return { lines = { { leftText = spells[id] and spells[id].channel and "Channeled" or "Instant" } } }
end }
C_Item = {
    GetItemInfo = function(id) if id ~= 99 then return "Item " .. id, nil, nil, nil, nil, nil, nil, nil, nil, 134400 end end,
    GetItemSpell = function(id) if id ~= 88 then return "Potion", 400 end end,
    RequestLoadItemDataByID = function() end,
}
Enum = { SpellBookSpellBank = { Player = 0 } }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 2 } end,
    GetSpellBookItemInfo = function(slot) return { spellID = slot == 1 and 100 or 101 } end,
}
PlaySoundFile = function(id, channel)
    plays[#plays + 1] = { id = id, channel = channel }
    if id == 999 then return false end
    return true, #plays
end
PlaySound = PlaySoundFile
StopSound = function(handle) stops[#stops + 1] = handle end
for _, file in ipairs({ "Model", "API", "Library", "Audio", "Sharing" }) do
    assert(loadfile(root .. file .. ".lua"))("Resonance", R)
end
R.RefreshUI = function() end
R.Status = function(self, message) self.status = message end
R:Initialize({}, "Tester-Realm", "MAGE")
R.build = "test:1"
R.SoundCatalog = { { id = 1, label = "Spark", category = "fire" }, { id = 1, label = "Duplicate", category = "fire" } }
R:BuildLibrary()
check(#R.Library == 1, "library deduplicates identifiers")
check(#R.Profile.cards == 0 and next(R.Profile.sets) == nil, "empty start, no presets")
local fire = R:AddAction(R:SpellInfo(100))
check(fire and #fire.config.cast == 0 and #fire.config.casting == 0, "new actions are silent")
check(R:GetMode(fire) == "casting", "cast time detected")
R:DiscoverRanks()
check(fire.ranks[101] and #R.Profile.cards == 1, "discover ranks without adding unrelated actions")
local duplicate, added = R:AddAction(R:SpellInfo(101))
check(duplicate == fire and not added, "rank drops reuse the existing action")
fire.config.cast[1] = { sound = "file:1", delay = 0, enabled = true }
fire.perRank = true
check(R:GetConfig(fire, 101) == fire.config, "rank inherits without an override")
local own = R:GetConfig(fire, 101, true)
own.cast[1].sound = "file:2"
check(fire.config.cast[1].sound == "file:1", "rank edit does not mutate shared sounds")
fire.perRank = false
check(R:GetConfig(fire, 101) == fire.config, "disabling rank mode uses shared sounds")
fire.perRank = true
check(R:GetConfig(fire, 101).cast[1].sound == "file:2", "rank settings survive toggling")
fire.overrides[101] = nil
check(R:GetConfig(fire, 101) == fire.config, "reset restores inheritance")
check(R:FindCard(102) == fire and fire.ranks[102], "newly encountered rank joins shared family")
check(R:FindCard(110) == nil, "unranked names do not match a ranked family")
cursor = { "spell", 1, "spell", 200 }
check(R:CursorAction().spellID == 200, "uses fourth cursor value rather than book slot")
cursor = { "spell", 1, "spell", 500 }
check(R:CursorAction() == nil, "reject passive spells")
cursor = { "macro", 1 }
check(R:CursorAction() == nil, "reject macros")
check(R:ItemAction(99) == nil, "uncached items request retry")
check(R:ItemAction(88) == nil, "items without use spells rejected")
local item = R:AddAction(R:ItemAction(77))
check(item.spellID == 400 and item.kind == "item", "item linked to its use spell")
local conflict, _, reason = R:AddAction(R:ItemAction(78))
check(not conflict and reason:find("same activation", 1, true), "ambiguous item activations explained")
local channel = R:AddAction(R:SpellInfo(300))
check(R:GetMode(channel) == "channel", "channel detected from localized tooltip metadata")
local instant = R:AddAction(R:SpellInfo(200))
check(R:GetMode(instant) == "instant", "instant detected")
fire.config.casting = { { sound = "file:3", delay = 0 }, { sound = "file:4", delay = 500 } }
plays, stops = {}, {}
R:OnSpellEvent("UNIT_SPELLCAST_START", "target", "other", 100)
check(#plays == 0, "other units ignored")
R:OnSpellEvent("UNIT_SPELLCAST_START", "player", "first", 100)
check(#plays == 1 and #R.jobs == 1, "casting starts immediate and delayed layers")
R:OnSpellEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "first", 100)
now = 1; R:Tick()
check(#plays == 1 and #stops == 1 and #R.jobs == 0, "interrupt cancels delayed and playing casting layers")
R:OnSpellEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "second", 100)
R:OnSpellEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "second", 100)
check(#plays == 2, "success GUID deduplicated")
fire.perRank = true
R:GetConfig(fire, 101, true).cast[1].sound = "file:5"
R:OnSpellEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "third", 101)
check(plays[#plays].id == 5, "event routes exact rank override")
R:OnSpellEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "fourth", 102)
check(plays[#plays].id == 1, "unoverridden rank uses shared sound")
channel.config.channel = { { sound = "file:6", delay = 0 }, { sound = "file:7", delay = 500 } }
R:OnSpellEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "ch", 300)
check(plays[#plays].id == 6, "channel starts its layers")
local before = #plays
R:OnSpellEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "ch", 300)
now = 2; R:Tick()
check(#plays == before, "channel stop cancels pending layers")
R:OnSpellEvent("UNIT_SPELLCAST_START", "player", "new", 100)
R:OnSpellEvent("UNIT_SPELLCAST_STOP", "player", "old", 100)
check(R.activeCasts.casting and R.activeCasts.casting.guid == "new", "late stop cannot stop a newer cast")
R:OnSpellEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "new", 100)
R:OnSpellEvent("UNIT_SPELLCAST_STOP", "player", "new", 100)
check(not R.activeCasts.casting, "success followed by stop cleans casting audio")
R:StopAll()
check(#R.jobs == 0 and next(R.groups) == nil, "stop cancels all runtime work")
R.Profile.enabled = false
before = #plays
R:OnSpellEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "disabled", 100)
check(#plays == before, "global disable respected")
R.Profile.enabled = true
fire.enabled = false
R:OnSpellEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "disabledcard", 100)
check(#plays == before, "action disable respected")
fire.enabled = true
local secret = {}
issecretvalue = function(v) return v == secret end
R:OnSpellEvent("UNIT_SPELLCAST_SUCCEEDED", "player", secret, 100)
check(#plays == before, "secret event values ignored")
check(R:Preview("file:999") == false, "failed sound previews recorded")
check(R.DB.soundChecks["file:999"].played == false, "failure not marked as successful")
local custom = R:AddCustomSound("kit", 8, "Custom hit")
check(custom and R:Preview(custom.key), "custom sound kit plays")
R.DB.favorites[custom.key] = true
check(#R:SoundResults("custom", "custom", true, true) == 1, "search, category, favorites and playback filters")
R.build = "test:2"
check(#R:SoundResults("custom", "custom", true, true) == 0, "sound checks scoped to client build")
local exported = R:ExportSet()
local imported, errorText = R:ReadImport(exported)
check(imported and #imported.cards == 4, errorText or "export/import round trip")
check(R:SaveSet("My set"), "save personal snapshot")
fire.config.cast[1].sound = "file:99"
check(R.Profile.sets["My set"].cards[1].config.cast[1].sound == "file:99", "active named set autosaves edits")
check(R:SaveSet("Second set"), "save as switches the active set")
fire.config.cast[1].sound = "file:98"
check(R.Profile.sets["My set"].cards[1].config.cast[1].sound == "file:99", "save as preserves the previous set independently")
check(R.Profile.sets["Second set"].cards[1].config.cast[1].sound == "file:98", "save as activates autosave for the new set")
check(R:ApplySet(imported), "load a validated set")
check(R.Profile.sets["Before last load"].cards[1].config.cast[1].sound == "file:98", "loading preserves previous setup")
local wrong = R.Copy(imported); wrong.class = "DRUID"
check(not pcall(function() R:ValidateSet(wrong) end), "cross-class imports rejected")
wrong = R.Copy(imported); wrong.cards[1].config.cast[1].delay = -1
check(not pcall(function() R:ValidateSet(wrong) end), "invalid delays rejected")
check(R:ReadImport("RESONANCE-FOREVER-1:" .. string.rep("{S1:x", 100)) == nil, "deep malformed data rejected")
check(R:ReadImport("RESONANCE-FOREVER-1:print('bad')") == nil, "imports never execute code")
check(R:ReadImport(exported .. "junk") == nil, "trailing data rejected")
check(R:ReadImport(exported:sub(1, #exported - 4)) == nil, "truncated data rejected")
local sameDB = R.DB
R:Initialize(sameDB, "Other-Realm", "MAGE")
check(#R.Profile.cards == 0, "separate character setup")
R:Initialize(sameDB, "Tester-Realm", "MAGE")
check(#R.Profile.cards == 4, "setup survives database reload")
check(R:ApplySet(R.Profile.sets["My set"], "My set"), "load named set activates autosave")
local liveCard = R.Profile.cards[1]
liveCard.config.cast[1].delay = 275
liveCard.enabled = false
liveCard.perRank = true
R:GetConfig(liveCard, 101, true).cast[1].sound = "kit:42"
check(R.Profile.sets["My set"].cards[1].config.cast[1].delay == 275, "delay edits autosave immediately without focus loss")
-- Copy simulates SavedVariables serialization losing shared table identity.
local disk = R.Copy(R.DB)
R:Initialize(disk, "Tester-Realm", "MAGE")
check(R.Profile.activeSetName == "My set" and not R.Profile.cards[1].enabled, "reload preserves active set and action state")
check(R.Profile.cards[1].overrides[101].cast[1].sound == "kit:42", "reload preserves rank overrides")
check(R.Profile.cards == R.Profile.sets["My set"].cards, "reload rebinds active set to authoritative working data")
R.Profile.cards[1].config.cast[1].delay = 350
check(R.Profile.sets["My set"].cards[1].config.cast[1].delay == 350, "autosave remains live after reload")
check(R:ApplySet(R.Profile.sets["Second set"], "Second set"), "switch to another named set")
check(R.Profile.sets["My set"].cards[1].config.cast[1].delay == 350, "switching preserves latest edits in previous set")
R.Profile.cards[1].config.cast[1].delay = 450
check(R.Profile.sets["My set"].cards[1].config.cast[1].delay == 350, "edits cannot leak across sets")
check(R:ApplySet(R.Profile.sets["Before last load"], "Before last load"), "backup can be restored")
check(R.Profile.activeSetName == nil, "recovery backup is not a live editable set")
-- Casting spells that belong to no action must not build tooltip data.
spells[600] = { name = "Frost Nova", rank = "Rank 1", cast = 0 }
local tooltipCalls, realTooltip = 0, C_TooltipInfo.GetSpellByID
C_TooltipInfo.GetSpellByID = function(id) tooltipCalls = tooltipCalls + 1; return realTooltip(id) end
R.Profile.enabled = true
for i = 1, 10 do R:OnSpellEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "nova" .. i, 600) end
check(tooltipCalls == 0, "unconfigured casts skip tooltip scans")
R:DiscoverRanks()
check(tooltipCalls == 0, "spellbook scan reads tooltips only for new ranks of configured families")
C_TooltipInfo.GetSpellByID = realTooltip
print("PASS: " .. checked .. " Resonance behavior checks")
