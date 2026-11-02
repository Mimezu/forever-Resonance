local _, R = ...
R.jobs, R.groups, R.activeCasts, R.seenSuccess = {}, {}, {}, {}
local audioTimer, audioDeadline, ticking

-- One wakeup at the next actual deadline; no idle or per-frame scheduler.
function R:ScheduleAudio()
    if ticking then return end
    local deadline
    local function include(at) deadline = math.min(deadline or at, at) end
    for _, job in ipairs(self.jobs) do include(job.at) end
    for group in pairs(self.groups) do include(group.expires) end
    for _, time in pairs(self.seenSuccess) do include(time + 60) end
    if audioTimer and deadline == audioDeadline then return end
    if audioTimer then audioTimer:Cancel(); audioTimer = nil end
    audioDeadline = deadline
    if deadline and C_Timer then
        audioTimer = C_Timer.NewTimer(math.max(0, deadline - GetTime()), function()
            audioTimer, audioDeadline = nil, nil
            self:Tick()
        end)
    end
end

function R:StopGroup(group)
    if not group then return end
    group.cancelled = true
    for _, handle in ipairs(group.handles) do self.Call(StopSound, handle) end
    group.handles = {}
    self.groups[group] = nil
    for index = #self.jobs, 1, -1 do
        if self.jobs[index].group == group then table.remove(self.jobs, index) end
    end
    group.pending = 0
    self:ScheduleAudio()
end

function R:StopAll()
    for group in pairs(self.groups) do self:StopGroup(group) end
    self.jobs, self.activeCasts = {}, {}
    self.seenSuccess = {}
    self:StopPreview()
    self:ScheduleAudio()
end

function R:PlayLayers(layers)
    local group = { handles = {}, pending = 0, expires = GetTime() + 120 }
    if not layers or #layers == 0 then self:ScheduleAudio(); return group end
    self.groups[group] = true
    for _, layer in ipairs(layers) do
        if layer.sound and layer.enabled ~= false then
            local delay = math.max(0, math.min(30000, tonumber(layer.delay) or 0)) / 1000
            if delay == 0 then
                local _, handle = self:PlayKey(layer.sound)
                if handle then group.handles[#group.handles + 1] = handle end
            else
                self.jobs[#self.jobs + 1] = { at = GetTime() + delay, sound = layer.sound, group = group }
                group.pending = group.pending + 1
            end
        end
    end
    if #group.handles == 0 and group.pending == 0 then self.groups[group] = nil end
    self:ScheduleAudio()
    return group
end

function R:Tick()
    ticking = true
    local now = GetTime()
    for index = #self.jobs, 1, -1 do
        local job = self.jobs[index]
        if job.group.cancelled or now >= job.at then
            if not job.group.cancelled then
                local _, handle = self:PlayKey(job.sound)
                if handle then table.insert(job.group.handles, handle) end
            end
            job.group.pending = job.group.pending - 1
            table.remove(self.jobs, index)
        end
    end
    for group in pairs(self.groups) do
        if now >= group.expires then self:StopGroup(group) end
    end
    for guid, time in pairs(self.seenSuccess) do
        if now >= time + 60 then self.seenSuccess[guid] = nil end
    end
    ticking = false
    self:ScheduleAudio()
end

function R:StopCast(moment, guid, spellID)
    local active = self.activeCasts[moment]
    if active and (not guid or not active.guid or guid == active.guid) and active.spellID == spellID then
        self:StopGroup(active.group)
        self.activeCasts[moment] = nil
    end
end

function R:OnSpellEvent(event, unit, guid, spellID)
    if not self.Safe(unit) or not self.Safe(guid) or not self.Safe(spellID)
        or unit ~= "player" or type(spellID) ~= "number" or not self.Profile then return end
    if event == "UNIT_SPELLCAST_STOP" then
        self:StopCast("casting", guid, spellID)
        return
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        self:StopCast("channel", guid, spellID)
        return
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_FAILED_QUIET" then
        self:StopCast("casting", guid, spellID)
        self:StopCast("channel", guid, spellID)
        return
    end
    if not self.Profile.enabled then return end
    local card = self:FindCard(spellID)
    if not card or not card.enabled then return end
    local moment
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if guid and self.seenSuccess[guid] then return end
        if guid then self.seenSuccess[guid] = GetTime() end
        moment = "cast"
    elseif event == "UNIT_SPELLCAST_START" then moment = "casting"
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then moment = "channel"
    else return end
    if moment ~= "cast" then
        if card.mode == "auto" then
            local previous = card.ranks[spellID].mode
            card.ranks[spellID].mode = moment
            if previous ~= moment and self.RefreshUI then self:RefreshUI() end
        end
        if self:GetMode(card, spellID) ~= moment then return end
        local active = self.activeCasts[moment]
        if active then self:StopGroup(active.group) end
    end
    local config = self:GetConfig(card, spellID)
    local group = self:PlayLayers(config[moment])
    if moment ~= "cast" then
        self.activeCasts[moment] = { guid = guid, spellID = spellID, group = group }
    end
end
