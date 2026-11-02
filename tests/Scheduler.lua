-- Run from the client root with Lua 5.1.
local R, now, timers, plays, combat, scans = {}, 0, {}, {}, false, 0
GetTime = function() return now end
InCombatLockdown = function() return combat end
StopSound = function() end
C_Timer = {}
function C_Timer.NewTimer(delay, callback)
    local timer = { at = now + delay, callback = callback }
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end
C_Timer.After = C_Timer.NewTimer
local function active()
    local count, deadline = 0
    for _, timer in ipairs(timers) do
        if not timer.cancelled then count = count + 1; deadline = math.min(deadline or timer.at, timer.at) end
    end
    return count, deadline
end
local function advance(to)
    for _ = 1, 100 do
        local selected
        for _, timer in ipairs(timers) do
            if not timer.cancelled and timer.at <= to and (not selected or timer.at < selected.at) then selected = timer end
        end
        if not selected then now = to; return end
        now, selected.cancelled = selected.at, true
        selected.callback()
    end
    error('timer did not settle')
end
R.Call = function(fn, ...) return fn(...) end
R.StopPreview = function() end
R.PlayKey = function(_, key) plays[#plays + 1] = { key = key, at = now }; return true, #plays end
assert(loadfile('Interface/AddOns/Resonance/Audio.lua'))('Resonance', R)
assert(active() == 0, 'idle audio must have no timer')
local a = R:PlayLayers({ { sound = 'late', delay = 500 } })
assert(active() == 1 and select(2, active()) == .5)
local b = R:PlayLayers({ { sound = 'early', delay = 100 } })
assert(active() == 1 and select(2, active()) == .1, 'earlier deadline replaces wakeup')
advance(.09); assert(#plays == 0)
advance(.1); assert(#plays == 1 and plays[1].key == 'early' and plays[1].at == .1)
advance(.5); assert(#plays == 2 and plays[2].key == 'late' and plays[2].at == .5)
assert(active() == 1 and select(2, active()) == 120, 'cleanup waits for expiry without polling')
advance(120); assert(active() == 0 and next(R.groups) == nil, 'expiry returns to sleep')
local cancelled = R:PlayLayers({ { sound = 'cancelled', delay = 500 } })
R:StopGroup(cancelled)
assert(active() == 0 and #R.jobs == 0, 'interrupt immediately cancels sole wakeup')
advance(121); assert(#plays == 2)
R.seenSuccess.guid = now; R:ScheduleAudio()
assert(active() == 1 and select(2, active()) == 181)
advance(181); assert(active() == 0 and next(R.seenSuccess) == nil)
R:PlayLayers({ { sound = 'stop', delay = 500 } }); R:StopAll()
assert(active() == 0, 'stop cancels deadlines')
R:PlayLayers({ { sound = 'disabled', enabled = false } })
assert(active() == 0, 'silent layers do not create cleanup work')

function CreateFrame()
    return { scripts = {}, RegisterEvent = function() end, RegisterUnitEvent = function() end,
        UnregisterEvent = function() end, SetScript = function(self, key, fn) self.scripts[key] = fn end }
end
UnitFullName = function() return 'Test', 'Realm' end
UnitClass = function() return 'Mage', 'MAGE' end
GetBuildInfo = function() return 'test', 1 end
SlashCmdList = {}
R.Initialize = function(self) self.DB = {}; self.Profile = { enabled = true } end
R.BuildLibrary = function() end
R.DiscoverRanks = function() scans = scans + 1 end
R.RefreshUI = function() end
assert(loadfile('Interface/AddOns/Resonance/Core.lua'))('Resonance', R)
local event = R.EventFrame.scripts.OnEvent
event(nil, 'ADDON_LOADED', 'Resonance')
assert(not R.EventFrame.scripts.OnUpdate and active() == 0)
event(nil, 'SPELLS_CHANGED'); event(nil, 'SPELLS_CHANGED')
assert(active() == 1, 'spell changes coalesce')
advance(now); assert(scans == 2 and active() == 0)
combat = true
event(nil, 'SPELLS_CHANGED'); advance(now + 30)
assert(scans == 2 and active() == 0, 'combat scan waits for event without polling')
combat = false; event(nil, 'PLAYER_REGEN_ENABLED'); advance(now)
assert(scans == 3 and active() == 0)
event(nil, 'SPELLS_CHANGED'); combat = true; advance(now)
assert(scans == 3 and active() == 0, 'combat beginning before callback defers scan')
combat = false; event(nil, 'PLAYER_REGEN_ENABLED'); advance(now)
assert(scans == 4 and active() == 0)
print('PASS: no idle polling, exact audio deadlines, cancellation, expiry, coalesced scans and combat wakeup')
