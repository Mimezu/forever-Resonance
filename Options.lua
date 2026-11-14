local _, R = ...
-- Toggle key, minimap button and the page in the game's Settings (Esc > Options > AddOns).
local BIND = "RESONANCEFOREVER_TOGGLE"
R.TOGGLE_BINDING = BIND
BINDING_HEADER_RESONANCEFOREVER = "Resonance"
BINDING_NAME_RESONANCEFOREVER_TOGGLE = "Open Resonance"
local ICON = "Interface\\AddOns\\Resonance\\Assets\\ResonanceIcon"
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }

function R:OpenUI()
    if not (self.UI.main and self.UI.main:IsShown() and self.UI.opened) then self:ToggleUI() end
end

-- Keys --------------------------------------------------------------------
function R:ToggleKeyText()
    local key = GetBindingKey and GetBindingKey(BIND)
    if not key then return "Not set" end
    return GetBindingText and GetBindingText(key) or key
end

-- key nil clears. Returns ok, and the name of what the key did before.
function R:BindToggleKey(key)
    if (InCombatLockdown and InCombatLockdown()) or not SetBinding then
        print("Resonance: keys can't change in combat.")
        return false
    end
    for _, old in ipairs({ GetBindingKey(BIND) }) do SetBinding(old) end
    local replaced
    if key then
        local previous = GetBindingAction and GetBindingAction(key)
        SetBinding(key, BIND)
        if previous and previous ~= "" and previous ~= BIND then
            replaced = _G["BINDING_NAME_" .. previous] or previous
            print("Resonance: " .. ((GetBindingText and GetBindingText(key)) or key) .. " no longer does \"" .. replaced .. "\".")
        end
    end
    if SaveBindings then SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1) end
    self:RefreshKeys()
    return true, replaced
end

local keycaps, capture = {}, nil
function R:RefreshKeys()
    for button in pairs(keycaps) do
        button:SetText(capture == button and "Press a key…" or self:ToggleKeyText())
    end
end
local function stopCapture()
    local button = capture
    if not button then return end
    capture = nil
    button:SetScript("OnKeyDown", nil)
    button:EnableKeyboard(false)
    R:RefreshKeys()
end
R.StopKeyCapture = stopCapture

-- Listens for the next key: modifiers combine, Escape cancels.
function R:CaptureToggleKey(button)
    if InCombatLockdown and InCombatLockdown() then print("Resonance: keys can't change in combat."); return end
    local same = capture == button
    stopCapture()
    if same then return end
    capture = button
    button:EnableKeyboard(true)
    button:SetPropagateKeyboardInput(false)
    button:SetScript("OnKeyDown", function(_, key)
        if MODIFIERS[key] then return end
        if key ~= "ESCAPE" then
            local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
                .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
            R:BindToggleKey(combo)
        end
        stopCapture()
    end)
    self:RefreshKeys()
end

-- Turns any button into the toggle key's keycap. Right-click clears.
function R:Keycap(button)
    keycaps[button] = true
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then stopCapture(); R:BindToggleKey(nil)
        else R:CaptureToggleKey(self) end
    end)
    button:HookScript("OnHide", function(self) if capture == self then stopCapture() end end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Right-click clears", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetText(self:ToggleKeyText())
    return button
end

-- Minimap button ----------------------------------------------------------
local minimapToggles = {}
function R:MinimapShown() return not (self.DB.minimap and self.DB.minimap.hide) end

local function placeMinimapButton(b)
    local angle = math.rad(R.DB.minimap.angle or 205)
    local radius = (Minimap:GetWidth() / 2) + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function R:CreateMinimapButton()
    if self.minimapButton or not Minimap then return self.minimapButton end
    local b = CreateFrame("Button", "ResonanceForeverMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local background = b:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(ICON)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    b:SetScript("OnClick", function() R:ToggleUI() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Resonance", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local atan2 = math.atan2 or math.atan
            R.DB.minimap.angle = math.deg(atan2(py / scale - my, px / scale - mx)) % 360
            placeMinimapButton(self)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    self.minimapButton = b
    placeMinimapButton(b)
    return b
end

function R:SetMinimapShown(shown)
    self.DB.minimap.hide = not shown or nil
    if shown then self:CreateMinimapButton() end
    if self.minimapButton then self.minimapButton:SetShown(shown and true or false) end
    for refresh in pairs(minimapToggles) do refresh() end
end
-- Controls showing the minimap setting register a refresh function here.
function R:OnMinimapChanged(refresh) minimapToggles[refresh] = true; refresh() end

-- Settings page -----------------------------------------------------------
function R:RegisterSettingsPage()
    if self.settingsCategory or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText("Resonance")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(140, 26)
    open:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
    open:SetText("Open")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        -- After Settings has finished closing, so its hide can't take the window with it.
        if C_Timer and C_Timer.After then C_Timer.After(0, function() R:OpenUI() end) else R:OpenUI() end
    end)
    local slash = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    slash:SetPoint("LEFT", open, "RIGHT", 12, 0)
    slash:SetText("/res")
    local keyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    keyLabel:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -22)
    keyLabel:SetText("Open Resonance")
    local key = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    key:SetSize(160, 26)
    key:SetPoint("LEFT", keyLabel, "LEFT", 150, 0)
    self:Keycap(key)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", -4, -16)
    local checkLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkLabel:SetPoint("LEFT", check, "RIGHT", 4, 0)
    checkLabel:SetText("Minimap icon")
    check:SetScript("OnClick", function(self) R:SetMinimapShown(self:GetChecked() and true or false) end)
    self:OnMinimapChanged(function() check:SetChecked(R:MinimapShown()) end)
    panel:SetScript("OnShow", function() R:RefreshKeys(); check:SetChecked(R:MinimapShown()) end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Resonance")
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory, self.settingsPanel = category, panel
end

function R:InitOptions()
    self.DB.minimap = type(self.DB.minimap) == "table" and self.DB.minimap or {}
    if self:MinimapShown() then self:CreateMinimapButton() end
    pcall(self.RegisterSettingsPage, self)
    if self.EventFrame then self.EventFrame:RegisterEvent("UPDATE_BINDINGS") end
end
