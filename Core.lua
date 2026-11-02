local addon, R = ...
local events = CreateFrame("Frame")
R.EventFrame = events
events:RegisterEvent("ADDON_LOADED")
local scanQueued
local function QueueScan()
    R.pendingScan = true
    if scanQueued or not R.Profile or InCombatLockdown() then return end
    scanQueued = true
    C_Timer.After(0, function()
        scanQueued = nil
        if not R.pendingScan or InCombatLockdown() then return end
        R.pendingScan = nil
        R:DiscoverRanks()
        R:RefreshUI()
    end)
end
local function initialize()
    local name, realm = UnitFullName("player")
    realm = realm or GetRealmName()
    local _, class = UnitClass("player")
    R:Initialize(ResonanceForeverDB, name .. "-" .. realm, class)
    ResonanceForeverDB = R.DB
    local version, build = GetBuildInfo()
    R.build = tostring(version) .. ":" .. tostring(build)
    R:BuildLibrary()
    R:DiscoverRanks()
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET" }) do
        events:RegisterUnitEvent(event, "player")
    end
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_LOGOUT")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_DEAD")
    SLASH_RESONANCEFOREVER1, SLASH_RESONANCEFOREVER2 = "/res", "/resonance"
    SlashCmdList.RESONANCEFOREVER = function(message)
        message = (message or ""):lower():match("^%s*(.-)%s*$")
        if message == "stop" then R:StopAll()
        elseif message == "off" or message == "on" then
            R.Profile.enabled = message == "on"
            if not R.Profile.enabled then R:StopAll() end
            R:RefreshUI()
            print("Resonance sounds: " .. message)
        elseif message:match("^style") then
            local id = (message:match("^style%s+(%a)$") or ""):upper()
            if not R.Theme:Label(id) then print("Resonance: /res style a, b, or c (Classic, Legacy, Flat)."); return end
            if R.UI.main then R.UI:SetSkin(id) else R.DB.skin = R.Theme:Use(id) end
            print("Resonance style: " .. R.Theme:Label(id))
        elseif message == "help" then
            print("Resonance: /res opens the editor. Drag an action into the empty slot, add sounds, and customize ranks if desired. /res stop, /res on, /res off, /res style a|b|c.")
        else R:ToggleUI() end
    end
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == addon then
            events:UnregisterEvent("ADDON_LOADED")
            if UnitFullName("player") then initialize() else events:RegisterEvent("PLAYER_LOGIN") end
        end
    elseif event == "PLAYER_LOGIN" then events:UnregisterEvent(event); initialize()
    elseif event == "SPELLS_CHANGED" then
        QueueScan()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if R.pendingScan then QueueScan() end
    elseif event == "PLAYER_LOGOUT" then R:SyncActiveSet(); R:StopAll()
    elseif event == "PLAYER_DEAD" then R:StopAll()
    elseif event == "PLAYER_ENTERING_WORLD" then R:StopAll(); QueueScan()
    else R:OnSpellEvent(event, ...) end
end)
