local _, R = ...
R.Library, R.SoundByKey = {}, {}

function R.SoundKey(sound)
    return (sound.kind or "file") .. ":" .. tostring(sound.id)
end

function R:BuildLibrary()
    self.Library, self.SoundByKey = {}, {}
    for _, source in ipairs({ self.SoundCatalog or {}, self.DB.customSounds }) do
        for _, sound in ipairs(source) do
            local key = self.SoundKey(sound)
            if not self.SoundByKey[key] then
                sound.key = key
                sound.searchText = ((sound.label or "") .. " " .. (sound.detail or "") .. " "
                    .. (sound.category or "") .. " " .. tostring(sound.id)):lower()
                self.Library[#self.Library + 1] = sound
                self.SoundByKey[key] = sound
            end
        end
    end
    table.sort(self.Library, function(a, b) return a.label < b.label end)
end

function R:SoundLabel(key)
    local sound = self.SoundByKey[key]
    return sound and sound.label or key or "Choose sound"
end

function R:SoundResults(query, category, favoritesOnly, playableOnly)
    query = (query or ""):lower()
    local result = {}
    for _, sound in ipairs(self.Library) do
        local check = self.DB.soundChecks[sound.key]
        if (not category or category == "all" or sound.category == category)
            and (not favoritesOnly or self.DB.favorites[sound.key])
            and (not playableOnly or (check and check.build == self.build and check.played))
            and (query == "" or sound.searchText:find(query, 1, true)) then
            result[#result + 1] = sound
        end
    end
    return result
end

function R:AddCustomSound(kind, id, label)
    id = tonumber(id)
    label = (label or ""):match("^%s*(.-)%s*$")
    if (kind ~= "file" and kind ~= "kit") or not id or id < 1 or id > 2147483647 or id % 1 ~= 0 then
        return nil, "Enter a positive FileDataID or SoundKit ID."
    end
    local sound = { kind = kind, id = id, label = label ~= "" and label:sub(1, 100) or (kind .. " #" .. id),
        category = "custom", detail = "Added by you" }
    local key = self.SoundKey(sound)
    if not self.SoundByKey[key] then
        table.insert(self.DB.customSounds, sound)
        self:BuildLibrary()
    end
    return self.SoundByKey[key]
end

function R:PlayKey(key)
    local kind, id
    if type(key) == "string" then kind, id = key:match("^(%a+):(%d+)$") end
    id = tonumber(id)
    if not id then return false end
    local played, handle
    if kind == "kit" then played, handle = self.Call(PlaySound, id, self.DB.channel, false)
    elseif kind == "file" then played, handle = self.Call(PlaySoundFile, id, self.DB.channel)
    else return false end
    -- Runs on every cast: record the result only when it changed.
    local check = self.DB.soundChecks[key]
    if not check or check.build ~= self.build or check.played ~= (played == true) then
        self.DB.soundChecks[key] = { build = self.build, played = played == true }
    end
    return played == true, handle
end

function R:Preview(key)
    self:StopPreview()
    local played, handle = self:PlayKey(key)
    self.previewHandle = handle
    self:Status(played and "Preview playing." or "The client did not play this sound. Try another entry.")
    return played
end

function R:StopPreview()
    if self.previewHandle then self.Call(StopSound, self.previewHandle) end
    self.previewHandle = nil
    if self.previewGroup and self.StopGroup then self:StopGroup(self.previewGroup) end
    self.previewGroup = nil
end
