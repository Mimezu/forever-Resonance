local _, R = ...
local UI = {}
R.UI = UI
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"

-- One grid for every style. Window inner edges (inside the native border):
-- x 16..width-8, y -16..-(height-12). Content keeps 12px from those edges.
-- The native border draws a title bar from -16 to a line at -39: the title
-- sits centred in it, the tagline and toolbar in the band below it.
local TITLE_Y = -27.5        -- centre of the title bar
local HEADER = 76            -- band under the title bar ends here
local BAND_Y = -57.5         -- centre of that band (-39..-76)
local TOP = -90              -- content starts here
local LEFT = 28
local GAP = 8                -- between controls in a row or column
local GUTTER = 22            -- scroll bar lane, reserved only while scrolling
local MAIN_W, MAIN_H = 1040, 708
local LIST_W = 248           -- left column: 28..276
local EDITOR_X, EDITOR_W, EDITOR_H = 292, 728, 562 -- 292..1020, down to -644
local PAD = 20               -- editor inner margin
local ROW_STEP, SECTION_STEP = 48, 30
local LAYER_STEP, CARD_TOP, CARD_BOTTOM, CARD_GAP = 48, 62, 12, 12

local function singleLine(label)
    label:SetWordWrap(false)
    label:SetMaxLines(1)
end
local function frame(parent, width, height, style, name)
    local f = CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(width, height)
    R.Theme:Surface(f, style)
    -- Panel changes can close UISpecialFrames, including while opening the
    -- spellbook to drag an action. Handle Escape locally instead.
    if name then
        f:EnableKeyboard(true)
        -- SetPropagateKeyboardInput is blocked for addons in combat.
        local function propagate(self)
            if not (InCombatLockdown and InCombatLockdown()) then self:SetPropagateKeyboardInput(true) end
        end
        propagate(f)
        f:SetScript("OnShow", propagate)
        f:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown and InCombatLockdown() then return end
            self:SetPropagateKeyboardInput(key ~= "ESCAPE")
            if key == "ESCAPE" then
                self:Hide()
                -- Consume only this Escape. Left at false, a window reopened in
                -- combat (where OnShow cannot reset it) would swallow every key.
                if C_Timer and C_Timer.After then C_Timer.After(0, function() propagate(self) end) end
            end
        end)
    end
    return f
end
local function text(parent, value, x, y, width, font)
    local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    t:SetPoint("TOPLEFT", x, y)
    if width then t:SetWidth(width) end
    t:SetJustifyH("LEFT")
    t:SetText(value)
    if font == "GameFontDisableSmall" then t:SetTextColor(R.Theme:Color("muted")) end
    return t
end
local function button(parent, value, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 25)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(value)
    local label = b:GetFontString()
    label:ClearAllPoints()
    label:SetPoint("LEFT", 8, 0)
    label:SetPoint("RIGHT", -8, 0)
    singleLine(label)
    R.Theme:Button(b)
    b:SetScript("OnClick", callback)
    return b
end
local function closeButton(parent, callback)
    local b = R.Theme:CloseButton(parent)
    b:SetScript("OnClick", callback)
    return b
end
-- x and width describe the visible box; InputBoxTemplate draws its left cap
-- 5px outside the frame.
local function edit(parent, x, y, width, value)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width - 5, 25)
    e:SetPoint("TOPLEFT", x + 5, y)
    e:SetAutoFocus(false)
    e:SetMaxLetters(200)
    e:SetText(value or "")
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    R.Theme:Edit(e)
    return e
end
local function tooltip(owner, message)
    owner:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(message) == "function" and message() or message, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local function placeholder(field, label)
    local hint = text(field, label, 3, -7, field:GetWidth() - 10, "GameFontDisableSmall")
    singleLine(hint)
    field:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
    hint:SetShown(field:GetText() == "")
end
local function dialogHeading(owner, title, subtitle)
    -- Native border art is on a child frame. Keep titles above it like the main header.
    local heading = CreateFrame("Frame", nil, owner)
    heading:SetPoint("TOPLEFT")
    heading:SetPoint("TOPRIGHT")
    heading:SetHeight(HEADER)
    heading:SetFrameLevel(owner:GetFrameLevel() + 3)
    heading:EnableMouse(false)
    local label = heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", heading, "TOP", 4, TITLE_Y)
    label:SetText(title)
    heading.subtitle = heading:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    heading.subtitle:SetPoint("LEFT", heading, "TOPLEFT", LEFT, BAND_Y)
    heading.subtitle:SetWidth(owner:GetWidth() - 2 * LEFT)
    heading.subtitle:SetJustifyH("LEFT")
    heading.subtitle:SetTextColor(R.Theme:Color("muted"))
    heading.subtitle:SetText(subtitle)
    singleLine(heading.subtitle)
    return heading
end
local function scroll(parent, x, y, width, height, step)
    local s = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetSize(width, height)
    local child = CreateFrame("Frame", nil, s)
    child:SetSize(width, 1)
    s:SetScrollChild(child)
    s.content, s.fullWidth = child, width
    R.Theme:Scroll(s, step)
    return s, child
end
local function clampScroll(s)
    s:SetVerticalScroll(math.min(s:GetVerticalScroll(), math.max(0, s:GetVerticalScrollRange())))
end
-- Content uses the full width until it overflows; then the scroll bar takes
-- its lane on the right. Returns the content width.
local function fitScroll(s, contentHeight)
    local width = s.fullWidth
    if contentHeight > s:GetHeight() + 0.5 then width = width - GUTTER end
    s:SetWidth(width)
    s.content:SetSize(width, math.max(1, contentHeight))
    clampScroll(s)
    return width
end

-- Popup list under (or above) a button. `current` marks the active value.
function UI:Menu(anchor, entries, selected, current, above)
    if not self.menu then
        local m = frame(UIParent, 235, 260, "menu")
        m:SetFrameStrata("TOOLTIP")
        m:EnableMouse(true)
        m:EnableMouseWheel(true)
        m.rows = {}
        for i = 1, 9 do
            local b = button(m, "", 6, -6 - (i - 1) * 27, 223, function(self)
                local entry = m.entries[m.offset + self.index]
                m:Hide()
                if entry then m.callback(entry.value) end
            end)
            b:GetFontString():SetJustifyH("LEFT")
            b:GetFontString():SetPoint("RIGHT", -26, 0)
            b.check = b:CreateTexture(nil, "OVERLAY")
            b.check:SetSize(18, 18)
            b.check:SetPoint("RIGHT", -6, 0)
            b.check:SetTexture(CHECK)
            b.index = i
            m.rows[i] = b
        end
        function m:Refresh()
            for i, row in ipairs(self.rows) do
                local entry = self.entries[self.offset + i]
                row:SetShown(entry ~= nil)
                if entry then
                    row:SetText(entry.label)
                    row.check:SetShown(self.current ~= nil and entry.value == self.current)
                end
            end
            self:SetHeight(math.min(9, #self.entries) * 27 + 12)
        end
        m:SetScript("OnMouseWheel", function(self, delta)
            self.offset = math.max(0, math.min(math.max(0, #self.entries - 9), self.offset - delta))
            self:Refresh()
        end)
        self.menu = m
    end
    local m = self.menu
    m.entries, m.callback, m.current, m.offset = entries, selected, current, 0
    for index, entry in ipairs(entries) do
        -- Open scrolled so the current choice is visible.
        if current ~= nil and entry.value == current then m.offset = math.max(0, math.min(index - 1, #entries - 9)) end
    end
    m:ClearAllPoints()
    if above then m:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 2)
    else m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2) end
    m:SetClampedToScreen(true)
    m:Refresh()
    m:Show()
end

-- Footer line: a transient message for a few seconds, otherwise the active profile.
function UI:UpdateFooter()
    if not self.status then return end
    if self.message then
        self.status:SetText(self.message)
        self.status:SetTextColor(1, 1, 1)
    else
        self.status:SetText("Active profile: “" .. (R.Profile.activeSetName or "Default") .. "” · Save updates this profile · Autosave on")
        self.status:SetTextColor(R.Theme:Color("muted"))
    end
end

function R:Status(message)
    if message == "" then message = nil end
    UI.message = message
    if UI.messageTimer then UI.messageTimer:Cancel(); UI.messageTimer = nil end
    if message and C_Timer and C_Timer.NewTimer then
        UI.messageTimer = C_Timer.NewTimer(6, function()
            UI.messageTimer, UI.message = nil, nil
            UI:UpdateFooter()
        end)
    end
    UI:UpdateFooter()
    if self.UI.libraryStatus and self.UI.library and self.UI.library:IsShown() then
        self.UI.libraryStatus:SetText(message or "")
    end
end

function UI:UpdateModal()
    local open = (self.library and self.library:IsShown()) or (self.sets and self.sets:IsShown())
    if open and not self.modalShield then
        local shield = CreateFrame("Frame", nil, self.main)
        shield:SetAllPoints()
        shield:SetFrameLevel(self.main:GetFrameLevel() + 20)
        shield:EnableMouse(true)
        shield:EnableMouseWheel(true)
        local dim = shield:CreateTexture(nil, "BACKGROUND")
        -- Match the window's leather fill; its outer frame bounds include
        -- transparent native-border padding that must not darken the world.
        dim:SetPoint("TOPLEFT", 16, -16)
        dim:SetPoint("BOTTOMRIGHT", -8, 12)
        dim:SetColorTexture(0, 0, 0, 0.22)
        self.modalShield = shield
    end
    if self.modalShield then self.modalShield:SetShown(open and true or false) end
end

local function rankEntries(card)
    local entries = {}
    for id, rank in pairs(card.ranks) do
        entries[#entries + 1] = { value = id, label = (rank.label ~= "" and rank.label or "Spell") .. " · " .. id,
            order = tonumber(rank.label:match("%d+")) or 0 }
    end
    table.sort(entries, function(a, b) return a.order == b.order and a.value < b.value or a.order < b.order end)
    table.insert(entries, 1, { value = false, label = "Shared sounds (all ranks)" })
    return entries
end

function UI:ActionRow(index)
    local row = self.actionRows[index]
    if row then return row end
    row = CreateFrame("Button", nil, self.actionContent)
    row:SetSize(LIST_W - 8, 46)
    row:SetHighlightTexture(WHITE)
    row:GetHighlightTexture():SetVertexColor(0.25, 0.5, 0.6, 0.18)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.12, 0.21, 0.27, 0.9)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(32, 32)
    row.icon:SetPoint("LEFT", 7, 0)
    R.Theme:Action(row)
    row.title = text(row, "", 48, -7)
    row.title:SetPoint("TOPRIGHT", -8, -7)
    singleLine(row.title)
    row.detail = text(row, "", 48, -25, nil, "GameFontDisableSmall")
    row.detail:SetPoint("TOPRIGHT", -8, -25)
    singleLine(row.detail)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self) UI.dragging = self.card end)
    row:SetScript("OnDragStop", function()
        local moving = UI.dragging
        UI.dragging = nil
        if not moving then return end
        for _, target in ipairs(UI.actionRows) do
            if target:IsShown() and MouseIsOver(target) then R:MoveCard(moving, target.card); return end
        end
        for _, target in ipairs(UI.sectionRows) do
            if target:IsShown() and MouseIsOver(target) then moving.section = target.section; R:RefreshUI(); return end
        end
    end)
    row:SetScript("OnReceiveDrag", function(self)
        if UI.dragging then R:MoveCard(UI.dragging, self.card); UI.dragging = nil
        else R:DropAction(self.card.section) end
    end)
    row:SetScript("OnMouseUp", function(self)
        if UI.dragging and UI.dragging ~= self.card then
            R:MoveCard(UI.dragging, self.card); UI.dragging = nil
        end
    end)
    row:SetScript("OnClick", function(self)
        if GetCursorInfo() then R:DropAction(self.card.section); return end
        R.selected, R.selectedRank = self.card, nil
        UI.editorScroll:SetVerticalScroll(0)
        R:RefreshUI()
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.card.kind == "item" then GameTooltip:SetItemByID(self.card.itemID)
        else GameTooltip:SetSpellByID(self.card.spellID) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.actionRows[index] = row
    return row
end

-- Layer controls are anchored from the right, so the row follows its card's width.
function UI:LayerRow(index)
    local row = self.layerRows[index]
    if row then return row end
    row = frame(self.editorContent, 640, 44, "row")
    row.remove = button(row, "Remove", 0, -9, 76, function()
        table.remove(R:GetConfig(row.card, row.rank, true)[row.moment], row.layerIndex)
        R:RefreshUI()
    end)
    row.remove:ClearAllPoints()
    row.remove:SetPoint("TOPRIGHT", -8, -9)
    row.toggle = button(row, "On", 0, -9, 52, function()
        local layer = R:GetConfig(row.card, row.rank, true)[row.moment][row.layerIndex]
        layer.enabled = layer.enabled == false
        R:RefreshUI()
    end)
    row.toggle:ClearAllPoints()
    row.toggle:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
    tooltip(row.toggle, "Turn this layer on or off without removing it.")
    local unit = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    unit:SetText("ms")
    unit:SetTextColor(R.Theme:Color("muted"))
    unit:SetWidth(16)
    unit:SetJustifyH("LEFT")
    unit:SetPoint("RIGHT", row.toggle, "LEFT", -10, 0)
    row.delay = edit(row, 0, -9, 56)
    row.delay:ClearAllPoints()
    row.delay:SetPoint("RIGHT", unit, "LEFT", -4, 0)
    row.delay:SetMaxLetters(5)
    row.delay:SetNumeric(true)
    row.delay:SetJustifyH("CENTER")
    tooltip(row.delay, "Delay before this layer plays, in milliseconds (0–30000).")
    local function commit(self, userInput)
        if not userInput then return end
        local value = tonumber(self:GetText())
        if not value or value < 0 or value > 30000 then
            R:Status("Delay must be between 0 and 30000 ms.")
            return
        end
        local layers = R:GetConfig(row.card, row.rank, true)[row.moment]
        if layers[row.layerIndex] then layers[row.layerIndex].delay = math.floor(value) end
    end
    row.delay:SetScript("OnTextChanged", commit)
    row.delay:SetScript("OnEditFocusLost", function(self)
        local layer = R:GetConfig(row.card, row.rank)[row.moment][row.layerIndex]
        if layer then self:SetText(tostring(layer.delay)) end
    end)
    row.delay:SetScript("OnEnterPressed", function(self) self:ClearFocus(); R:RefreshUI() end)
    row.preview = button(row, "Play", 0, -9, 56, function()
        local layer = R:GetConfig(row.card, row.rank)[row.moment][row.layerIndex]
        R:Preview(layer.sound)
    end)
    row.preview:ClearAllPoints()
    -- 5px input cap + the usual 6px gap.
    row.preview:SetPoint("RIGHT", row.delay, "LEFT", -11, 0)
    row.sound = button(row, "", 8, -9, 300, function(self)
        local target, rank, moment, index = row.card, row.rank, row.moment, row.layerIndex
        UI:OpenLibrary(function(sound)
            local config = R:GetConfig(target, rank, true)
            if config[moment][index] then config[moment][index].sound = sound.key end
            R:RefreshUI()
        end)
    end)
    row.sound:SetPoint("RIGHT", row.preview, "LEFT", -6, 0)
    row.sound:GetFontString():SetJustifyH("LEFT")
    tooltip(row.sound, function()
        local layer = R:GetConfig(row.card, row.rank)[row.moment][row.layerIndex]
        return R:SoundLabel(layer and layer.sound) .. "\nClick to change this sound."
    end)
    self.layerRows[index] = row
    return row
end

function UI:MomentCard(moment)
    local header = self.momentHeaders[moment]
    if header then return header end
    header = CreateFrame("Frame", nil, self.editorContent)
    header:SetSize(EDITOR_W - 2 * PAD, CARD_TOP + CARD_BOTTOM)
    R.Theme:ChallengeCard(header)
    local title = text(header, R.MomentLabels[moment], 14, -14, 200, "GameFontNormalLarge")
    title:SetTextColor(R.Theme:Color("cardTitle"))
    local description = text(header, moment == "cast" and "When the action succeeds"
        or moment == "casting" and "While casting; stops when the cast ends."
        or "While channeling; stops when the channel ends.", 14, -39, 420, "GameFontDisableSmall")
    description:SetTextColor(R.Theme:Color("cardText"))
    local add = button(header, "+ Sound", 0, -12, 100, function()
        local target, targetRank = R.selected, R.selectedRank
        if #R:GetConfig(target, targetRank)[moment] >= 16 then R:Status("Use up to 16 layers per moment."); return end
        UI:OpenLibrary(function(sound)
            table.insert(R:GetConfig(target, targetRank, true)[moment], { sound = sound.key, delay = 0, enabled = true })
            R:RefreshUI()
        end)
    end)
    add:ClearAllPoints()
    add:SetPoint("TOPRIGHT", -14, -12)
    header.play = button(header, "Play layers", 0, -12, 100, function()
        R:StopPreview()
        R.previewGroup = R:PlayLayers(R:GetConfig(R.selected, R.selectedRank)[moment])
    end)
    header.play:ClearAllPoints()
    header.play:SetPoint("RIGHT", add, "LEFT", -6, 0)
    self.momentHeaders[moment] = header
    return header
end

function UI:CreateMain()
    R.Theme:Use(R.DB.skin)
    local f = frame(UIParent, MAIN_W, MAIN_H, "window", "ResonanceForeverEditor")
    R.Theme:Header(f, HEADER)
    R.Theme:Divider(f, LEFT + LIST_W + 3, TOP, EDITOR_H)
    self.main = f
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetScale(math.min(1, UIParent:GetWidth() / 1080, UIParent:GetHeight() / 740))
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER)
    header:SetFrameLevel(f:GetFrameLevel() + 3)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relative, x, y = f:GetPoint()
        R.DB.window = { point, relative, x, y }
    end)
    if R.DB.window then
        local p = R.DB.window
        f:ClearAllPoints(); f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", header, "TOP", 4, TITLE_Y)
    title:SetText("Resonance")
    local tagline = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tagline:SetPoint("LEFT", header, "TOPLEFT", LEFT, BAND_Y)
    tagline:SetTextColor(R.Theme:Color("muted"))
    tagline:SetText("Your actions. Your sounds.")
    closeButton(header, function() f:Hide() end)
    -- Toolbar: centred in the band under the title bar, ending on the editor's edge.
    self.enable = button(header, "", 0, 0, 108, function()
        R.Profile.enabled = not R.Profile.enabled
        if not R.Profile.enabled then R:StopAll() end
        R:RefreshUI()
    end)
    tooltip(self.enable, "Turn all Resonance sounds on or off.")
    local libraryButton = button(header, "Sound library", 0, 0, 122, function() UI:OpenLibrary() end)
    local setsButton = button(header, "Sound sets", 0, 0, 108, function() UI:OpenSets() end)
    local stopButton = button(header, "Stop", 0, 0, 64, function() R:StopAll() end)
    tooltip(stopButton, "Stop sounds Resonance is playing.")
    stopButton:ClearAllPoints()
    stopButton:SetPoint("TOPRIGHT", -(MAIN_W - EDITOR_X - EDITOR_W), BAND_Y + 12.5)
    local neighbor = stopButton
    for _, control in ipairs({ setsButton, libraryButton, self.enable }) do
        control:ClearAllPoints()
        control:SetPoint("RIGHT", neighbor, "LEFT", -6, 0)
        neighbor = control
    end

    -- Left column: drop slot, search, action list, new section.
    local drop = frame(f, LIST_W, 66)
    drop:SetPoint("TOPLEFT", LEFT, TOP)
    drop:EnableMouse(true)
    text(drop, "+  Drop an action here", 14, -15, LIST_W - 28, "GameFontNormal")
    text(drop, "Spell · ability · usable item", 14, -38, LIST_W - 28, "GameFontDisableSmall")
    drop:SetScript("OnReceiveDrag", function() R:DropAction() end)
    drop:SetScript("OnMouseUp", function() if GetCursorInfo() then R:DropAction() end end)
    self.search = edit(f, LEFT, TOP - 74, LIST_W)
    self.search:SetScript("OnTextChanged", function() R:RefreshUI() end)
    placeholder(self.search, "Search actions…")
    tooltip(self.search, "Filter your actions by name or section.")
    local listWell = frame(f, LIST_W, 422)
    listWell:SetPoint("TOPLEFT", LEFT, TOP - 107)
    listWell:SetFrameLevel(f:GetFrameLevel())
    self.actionScroll, self.actionContent = scroll(f, LEFT + 4, TOP - 111, LIST_W - 8, 414, ROW_STEP)
    self.actionScroll:SetFrameLevel(f:GetFrameLevel() + 3)
    self.actionRows, self.sectionRows, self.layerRows, self.momentHeaders = {}, {}, {}, {}
    self.sectionName = edit(f, LEFT, TOP + 25 - EDITOR_H, 156)
    self.sectionName:SetMaxLetters(48)
    placeholder(self.sectionName, "New section name")
    button(f, "+ Section", LEFT + 164, TOP + 25 - EDITOR_H, LIST_W - 164, function()
        local ok, err = R:AddSection(UI.sectionName:GetText())
        if ok then UI.sectionName:SetText(""); UI.sectionName:ClearFocus() else R:Status(err) end
    end)

    -- Editor.
    self.editor = frame(f, EDITOR_W, EDITOR_H)
    self.editor:SetPoint("TOPLEFT", EDITOR_X, TOP)
    local right = EDITOR_W - PAD
    self.empty = CreateFrame("Frame", nil, self.editor)
    self.empty:SetPoint("TOPLEFT", PAD, -18)
    self.empty:SetSize(EDITOR_W - 2 * PAD, 200)
    self.emptyTitle = text(self.empty, "Build your first action", 0, 0, 570, "GameFontNormalLarge")
    self.emptyBody = text(self.empty, "", 0, -34, 560, "GameFontHighlight")
    self.emptyBody:SetSpacing(6)
    text(self.empty, "Changes save automatically.", 0, -86, 560, "GameFontDisableSmall")
    self.title = text(self.editor, "", PAD, -18, 540, "GameFontNormalLarge")
    singleLine(self.title)
    self.cardEnable = button(self.editor, "", right - 116, -14, 116, function()
        R.selected.enabled = not R.selected.enabled
        R:StopAll(); R:RefreshUI()
    end)
    tooltip(self.cardEnable, "Turn this action's sounds on or off.")
    self.metadata = text(self.editor, "", PAD, -46, EDITOR_W - 2 * PAD, "GameFontDisableSmall")
    -- Two rows of three columns: 210 | 262 | rest, 8px apart.
    local col2, col3 = PAD + 210 + GAP, PAD + 210 + GAP + 262 + GAP
    local col3W = right - col3
    self.mode = button(self.editor, "", PAD, -70, 210, function(self)
        UI:Menu(self, {
            { label = "Automatic detection", value = "auto" }, { label = "Instant", value = "instant" },
            { label = "Cast time", value = "casting" }, { label = "Channel", value = "channel" },
        }, function(value) R.selected.mode = value; R:RefreshUI() end, R.selected.mode)
    end)
    tooltip(self.mode, "How this action is cast. Automatic detection reads it from the spell.")
    self.section = button(self.editor, "", col2, -70, 262, function(self)
        local entries = {}
        for _, section in ipairs(R.Profile.sections) do entries[#entries + 1] = { label = section, value = section } end
        UI:Menu(self, entries, function(value) R.selected.section = value; R:RefreshUI() end, R.selected.section)
    end)
    self.delete = button(self.editor, "Remove action", col3, -70, col3W, function()
        UI.removed = R.selected
        R.selected, R.selectedRank = nil, nil
        R:RemoveCard(UI.removed)
    end)
    self.perRank = button(self.editor, "", PAD, -103, 210, function()
        R.selected.perRank = not R.selected.perRank
        R.selectedRank = nil
        R:RefreshUI()
    end)
    tooltip(self.perRank, "Customize individual ranks. Disabling this uses shared sounds and preserves your overrides.")
    self.rank = button(self.editor, "", col2, -103, 262, function(self)
        UI:Menu(self, rankEntries(R.selected), function(value) R.selectedRank = value or nil; R:RefreshUI() end,
            R.selectedRank or false)
    end)
    self.resetRank = button(self.editor, "Reset to shared", col3, -103, col3W, function()
        R.selected.overrides[R.selectedRank] = nil
        R:RefreshUI()
    end)
    self.inheritance = text(self.editor, "", PAD, -138, EDITOR_W - 2 * PAD, "GameFontDisableSmall")
    self.editorScroll, self.editorContent = scroll(self.editor, PAD, -160, EDITOR_W - 2 * PAD, 390, LAYER_STEP)

    -- Footer: status or active profile on the left; Undo (when available) and style on the right.
    local footerY = TOP - EDITOR_H - 20
    self.style = button(f, "", MAIN_W - 20 - 150, footerY + 11, 150, function(self)
        local entries = {}
        for _, skin in ipairs(R.Theme.Skins) do entries[#entries + 1] = { label = skin.label, value = skin.id } end
        UI:Menu(self, entries, function(value) UI:SetSkin(value) end, R.Theme.skin, true)
    end)
    self.style:SetHeight(22)
    tooltip(self.style, "Choose the window style. Your actions and sounds are not affected.")
    self.undo = button(f, "Undo removal", MAIN_W - 20 - 150 - 6 - 130, footerY + 11, 130, function()
        if UI.removed then
            local current = R.BySpell[UI.removed.spellID]
            if current and current.kind == UI.removed.kind then R:Status("That action already exists."); return end
            table.insert(R.Profile.cards, UI.removed)
            R.selected, UI.removed = UI.removed, nil
            R:Changed()
        end
    end)
    self.undo:SetHeight(22)
    self.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.status:SetPoint("LEFT", f, "TOPLEFT", LEFT, footerY)
    self.status:SetWidth(MAIN_W - 20 - 150 - 6 - 130 - 16 - LEFT)
    self.status:SetJustifyH("LEFT")
    singleLine(self.status)
    f:SetScript("OnHide", function()
        R:StopPreview()
        if UI.menu then UI.menu:Hide() end
        if UI.library then UI.library:Hide() end
        if UI.sets then UI.sets:Hide() end
    end)
end

-- Switching style rebuilds the windows; the old frames stay hidden.
function UI:SetSkin(id)
    R.DB.skin = R.Theme:Use(id)
    local shown = self.main and self.main:IsShown()
    if self.main then self.main:Hide() end
    if self.menu then self.menu:Hide() end
    self.main, self.library, self.sets, self.menu, self.modalShield = nil, nil, nil, nil, nil
    self:CreateMain()
    if shown then
        self.main:Show()
        R:RefreshUI()
    end
end

function R:RefreshUI()
    if not UI.main or not UI.main:IsShown() then return end
    UI.enable:SetText(self.Profile.enabled and "Sounds: on" or "Sounds: off")
    UI.undo:SetShown(UI.removed ~= nil)
    UI.undo:SetEnabled(UI.removed ~= nil)
    UI.style:SetText("Style: " .. R.Theme:Label(R.Theme.skin))
    UI:UpdateFooter()
    local query = UI.search:GetText():lower()
    local y, rowIndex = 0, 0
    for _, row in ipairs(UI.actionRows) do row:Hide() end
    for _, row in ipairs(UI.sectionRows) do row:Hide() end
    for sectionIndex, section in ipairs(self.Profile.sections) do
        local heading = UI.sectionRows[sectionIndex]
        if not heading then
            heading = CreateFrame("Button", nil, UI.actionContent)
            heading:SetSize(LIST_W - 8, 28)
            R.Theme:Section(heading)
            heading.label = text(heading, "", 8, -8, nil, "GameFontNormalSmall")
            heading.label:SetPoint("TOPRIGHT", -8, -8)
            singleLine(heading.label)
            heading:SetScript("OnReceiveDrag", function(self)
                if UI.dragging then UI.dragging.section = self.section; UI.dragging = nil; R:RefreshUI()
                else R:DropAction(self.section) end
            end)
            UI.sectionRows[sectionIndex] = heading
        end
        heading.section = section
        heading:SetPoint("TOPLEFT", 0, -y)
        heading.label:SetText(section)
        heading:Show()
        y = y + SECTION_STEP
        for _, card in ipairs(self.Profile.cards) do
            if card.section == section and (query == "" or (card.name .. " " .. section):lower():find(query, 1, true)) then
                rowIndex = rowIndex + 1
                local row = UI:ActionRow(rowIndex)
                local selected = card == self.selected
                row.card = card
                row:SetPoint("TOPLEFT", 0, -y)
                row.icon:SetTexture(card.icon)
                row.icon:SetDesaturated(not card.enabled)
                row.title:SetText(card.name)
                row.detail:SetText((card.enabled and "" or "Muted · ") .. (card.kind == "item" and "Item" or card.perRank and "Per-rank sounds" or "Shared sounds"))
                row.bg:SetShown(selected)
                if row.accent then row.accent:SetShown(selected) end
                row:Show()
                y = y + ROW_STEP
            end
        end
    end
    local listWidth = fitScroll(UI.actionScroll, y)
    for _, row in ipairs(UI.actionRows) do row:SetWidth(listWidth) end
    for _, heading in ipairs(UI.sectionRows) do heading:SetWidth(listWidth) end
    local card = self.selected
    local hasActions = #self.Profile.cards > 0
    UI.empty:SetShown(card == nil)
    UI.emptyTitle:SetText(hasActions and "Choose an action" or "Build your first action")
    UI.emptyBody:SetText(hasActions and "Select an action on the left to edit its sounds.\nYou can also drag in another spell, ability, or usable item."
        or "Drag a spell, ability, or usable item into the slot on the left.\nThen add sounds to its Cast, Casting, or Channeling moments.")
    for _, key in ipairs({ "title", "cardEnable", "metadata", "mode", "section", "delete", "perRank", "rank", "resetRank", "inheritance", "editorScroll" }) do
        UI[key]:SetShown(card ~= nil)
    end
    if not card then return end
    UI.title:SetText(card.name)
    UI.cardEnable:SetText(card.enabled and "Action: on" or "Action: off")
    local rankCount = 0
    for _ in pairs(card.ranks) do rankCount = rankCount + 1 end
    UI.metadata:SetText(card.kind == "item" and "Usable item · Sounds follow its activation spell"
        or ("Spell · " .. rankCount .. (rankCount == 1 and " rank available" or " ranks available")))
    local detected = self:GetMode(card, self.selectedRank)
    local labels = { instant = "Instant", casting = "Cast time", channel = "Channel" }
    UI.mode:SetText((card.mode == "auto" and "Auto: " or "Type: ") .. (labels[detected] or "Instant"))
    UI.section:SetText("Section: " .. card.section)
    UI.perRank:SetShown(card.kind == "spell")
    UI.perRank:SetText(card.perRank and "Customize ranks: on" or "Customize ranks: off")
    UI.rank:SetShown(card.kind == "spell" and card.perRank)
    local rank = self.selectedRank and card.ranks[self.selectedRank]
    UI.rank:SetText(rank and ((rank.label ~= "" and rank.label or "Spell") .. " · " .. self.selectedRank) or "Shared sounds (all ranks)")
    UI.resetRank:SetShown(card.perRank and self.selectedRank ~= nil)
    UI.resetRank:SetEnabled(self.selectedRank ~= nil and card.overrides[self.selectedRank] ~= nil)
    UI.inheritance:SetText(self.selectedRank and (card.overrides[self.selectedRank] and "This rank has its own sounds." or "Inheriting shared sounds. Editing creates an override.")
        or (card.kind == "spell" and "Shared across ranks. Enable rank customization to make exceptions." or "Plays when the item's activation spell is cast."))
    for _, row in ipairs(UI.layerRows) do row:Hide() end
    for _, header in pairs(UI.momentHeaders) do header:Hide() end
    local config = self:GetConfig(card, self.selectedRank)
    y, rowIndex = 0, 0
    for _, moment in ipairs(self.Moments) do
        if moment == "cast" or moment == detected then
            local header = UI:MomentCard(moment)
            header:SetPoint("TOPLEFT", 0, -y)
            header:SetHeight(CARD_TOP + CARD_BOTTOM + #config[moment] * LAYER_STEP)
            header.play:SetEnabled(#config[moment] > 0)
            header:Show()
            local rowY = y + CARD_TOP
            for layerIndex, layer in ipairs(config[moment]) do
                rowIndex = rowIndex + 1
                local row = UI:LayerRow(rowIndex)
                local on = layer.enabled ~= false
                row.card, row.rank, row.moment, row.layerIndex = card, self.selectedRank, moment, layerIndex
                row:SetPoint("TOPLEFT", 14, -rowY)
                row.sound:SetText(self:SoundLabel(layer.sound))
                row.sound:SetAlpha(on and 1 or 0.5)
                row.delay:SetText(tostring(layer.delay))
                row.toggle:SetText(on and "On" or "Off")
                row:Show()
                rowY = rowY + LAYER_STEP
            end
            y = rowY + CARD_BOTTOM + CARD_GAP
        end
    end
    local cardWidth = fitScroll(UI.editorScroll, math.max(0, y - CARD_GAP))
    for _, header in pairs(UI.momentHeaders) do header:SetWidth(cardWidth) end
    for _, row in ipairs(UI.layerRows) do row:SetWidth(cardWidth - 28) end
end

-- Library grid: content 28..880; rows 852 wide.
local LIB_W, LIB_H, LIB_RIGHT = 900, 652, 880
local LIB_ROWS, LIB_ROW_STEP = 8, 48
local STATE_COLORS = { Played = { 0.55, 0.82, 0.50 }, ["No playback"] = { 0.90, 0.48, 0.36 } }

function UI:CreateLibrary()
    local f = frame(self.main, LIB_W, LIB_H, "window", "ResonanceForeverLibrary")
    R.Theme:Header(f, HEADER)
    self.library = f
    f:SetPoint("CENTER")
    f:SetFrameLevel(self.main:GetFrameLevel() + 30)
    f:EnableMouse(true)
    self.libraryHeading = dialogHeading(f, "Sound library", "Browse sounds, preview them, and save your favorites.")
    closeButton(self.libraryHeading, function() f:Hide() end)
    self.librarySearch = edit(f, LEFT, TOP, 320)
    self.librarySearch:SetScript("OnTextChanged", function() UI.libraryPage = 0; UI:RefreshLibrary() end)
    placeholder(self.librarySearch, "Search sounds…")
    self.categoryButton = button(f, "All categories", 356, TOP, 224, function(self)
        local entries = { { label = "All categories", value = "all" }, { label = "Custom", value = "custom" } }
        for _, cat in ipairs(R.SoundCategories) do
            if cat.id ~= "favorites" then entries[#entries + 1] = { label = cat.label, value = cat.id } end
        end
        UI:Menu(self, entries, function(value)
            UI.category, UI.libraryPage = value, 0
            UI.categoryButton:SetText(value == "all" and "All categories" or value == "custom" and "Custom" or R.SoundCategoryByID[value].label)
            UI:RefreshLibrary()
        end, UI.category or "all")
    end)
    self.favoriteFilter = button(f, "Favorites: off", 588, TOP, 130, function(self)
        UI.favoritesOnly = not UI.favoritesOnly; UI.libraryPage = 0
        self:SetText(UI.favoritesOnly and "Favorites: on" or "Favorites: off")
        UI:RefreshLibrary()
    end)
    tooltip(self.favoriteFilter, "Show only sounds you saved as favorites.")
    self.playableFilter = button(f, "Played only: off", 726, TOP, LIB_RIGHT - 726, function(self)
        UI.playableOnly = not UI.playableOnly; UI.libraryPage = 0
        self:SetText(UI.playableOnly and "Played only: on" or "Played only: off")
        UI:RefreshLibrary()
    end)
    tooltip(self.playableFilter, "Show only sounds that played on this client build.")
    self.soundRows = {}
    for i = 1, LIB_ROWS do
        local row = frame(f, LIB_RIGHT - LEFT, 44, "row")
        row:SetPoint("TOPLEFT", LEFT, TOP - 35 - (i - 1) * LIB_ROW_STEP)
        row.label = text(row, "", 10, -7, 480)
        row.detail = text(row, "", 10, -25, 480, "GameFontDisableSmall")
        singleLine(row.label)
        singleLine(row.detail)
        row:EnableMouse(true)
        tooltip(row, function() return row.sound.label .. "\n" .. (row.sound.detail or "") .. "\n" .. row.sound.key end)
        row.choose = button(row, "Choose", 0, -10, 100, function()
            if UI.onChooseSound then local callback = UI.onChooseSound; f:Hide(); callback(row.sound) end
        end)
        row.choose:ClearAllPoints()
        row.choose:SetPoint("TOPRIGHT", -10, -10)
        row.preview = button(row, "Play", 0, -10, 64, function() R:Preview(row.sound.key); UI:RefreshLibrary() end)
        row.star = button(row, "", 0, -10, 84, function()
            R.DB.favorites[row.sound.key] = not R.DB.favorites[row.sound.key] or nil
            UI:RefreshLibrary()
        end)
        row.star:ClearAllPoints()
        row.star:SetPoint("RIGHT", row.preview, "LEFT", -6, 0)
        tooltip(row.star, "Save or remove this sound from your favorites.")
        row.state = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.state:SetWidth(84)
        row.state:SetJustifyH("CENTER")
        row.state:SetPoint("RIGHT", row.star, "LEFT", -10, 0)
        singleLine(row.state)
        self.soundRows[i] = row
    end
    self.libraryEmpty = text(f, "No sounds match these filters.\nTry a different search or turn off a filter.", 60, -240, 780, "GameFontHighlight")
    self.libraryEmpty:SetJustifyH("CENTER")
    self.libraryEmpty:SetSpacing(8)
    local pagerY = TOP - 35 - LIB_ROWS * LIB_ROW_STEP - 6
    self.libraryCount = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.libraryCount:SetPoint("LEFT", f, "TOPLEFT", LEFT, pagerY - 12.5)
    self.libraryCount:SetTextColor(R.Theme:Color("muted"))
    self.previousPage = button(f, "Previous", LIB_RIGHT - 84 * 3 - 16, pagerY, 84, function() UI.libraryPage = math.max(0, UI.libraryPage - 1); UI:RefreshLibrary() end)
    self.nextPage = button(f, "Next", LIB_RIGHT - 84 * 2 - 8, pagerY, 84, function() UI.libraryPage = UI.libraryPage + 1; UI:RefreshLibrary() end)
    local stop = button(f, "Stop", LIB_RIGHT - 84, pagerY, 84, function() R:StopPreview() end)
    tooltip(stop, "Stop the sound preview.")
    -- Add your own sound.
    R.Theme:Line(f, LEFT, pagerY - 37, LIB_RIGHT - LEFT)
    local fieldY = pagerY - 61
    text(f, "Sound type", LEFT, fieldY + 16, 88, "GameFontDisableSmall")
    text(f, "Sound ID", 124, fieldY + 16, 106, "GameFontDisableSmall")
    text(f, "Name (optional)", 238, fieldY + 16, 470, "GameFontDisableSmall")
    self.customType = button(f, "File ID", LEFT, fieldY, 88, function(self)
        UI.customKind = UI.customKind == "kit" and "file" or "kit"
        self:SetText(UI.customKind == "kit" and "Kit ID" or "File ID")
    end)
    tooltip(self.customType, "Switch between a FileDataID and a SoundKit ID.")
    self.customID = edit(f, 124, fieldY, 106)
    self.customID:SetNumeric(true)
    self.customID:SetMaxLetters(10)
    self.customName = edit(f, 238, fieldY, 482)
    placeholder(self.customID, "123456")
    placeholder(self.customName, "Name your sound")
    tooltip(self.customID, "Add a client FileDataID or SoundKit ID to your library.")
    tooltip(self.customName, "A name for your custom sound.")
    button(f, "Add to library", 728, fieldY, LIB_RIGHT - 728, function()
        local sound, err = R:AddCustomSound(UI.customKind or "file", UI.customID:GetText(), UI.customName:GetText())
        if not sound then R:Status(err); return end
        UI.category, UI.favoritesOnly, UI.playableOnly, UI.libraryPage = "all", false, false, 0
        UI.categoryButton:SetText("All categories")
        UI.favoriteFilter:SetText("Favorites: off")
        UI.playableFilter:SetText("Played only: off")
        UI.librarySearch:SetText(tostring(sound.id))
        UI.customID:ClearFocus(); UI.customName:ClearFocus()
        UI:RefreshLibrary()
    end)
    self.libraryStatus = text(f, "", LEFT, fieldY - 37, LIB_RIGHT - LEFT, "GameFontHighlightSmall")
    singleLine(self.libraryStatus)
    f:SetScript("OnHide", function()
        R:StopPreview()
        if UI.menu then UI.menu:Hide() end
        UI:UpdateModal()
    end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        UI.libraryPage = math.max(0, UI.libraryPage - delta); UI:RefreshLibrary()
    end)
end

function UI:RefreshLibrary()
    if not self.library then return end
    local results = R:SoundResults(self.librarySearch:GetText(), self.category, self.favoritesOnly, self.playableOnly)
    local pages = math.max(1, math.ceil(#results / LIB_ROWS))
    local choosing = self.onChooseSound ~= nil
    self.libraryPage = math.min(self.libraryPage or 0, pages - 1)
    self.libraryEmpty:SetShown(#results == 0)
    self.previousPage:SetEnabled(self.libraryPage > 0)
    self.nextPage:SetEnabled(self.libraryPage < pages - 1)
    for i, row in ipairs(self.soundRows) do
        local sound = results[self.libraryPage * LIB_ROWS + i]
        row:SetShown(sound ~= nil)
        if sound then
            row.sound = sound
            row.label:SetText(sound.label)
            row.detail:SetText(sound.detail or sound.category or "")
            local check = R.DB.soundChecks[sound.key]
            local state = check and check.build == R.build and (check.played and "Played" or "No playback") or "Untried"
            row.state:SetText(state)
            if STATE_COLORS[state] then row.state:SetTextColor(unpack(STATE_COLORS[state]))
            else row.state:SetTextColor(R.Theme:Color("muted")) end
            row.star:SetText(R.DB.favorites[sound.key] and "Saved" or "Favorite")
            row.choose:SetEnabled(choosing)
            row.choose:SetShown(choosing)
            -- Browse mode drops Choose; the other controls close up to the edge.
            row.preview:ClearAllPoints()
            if choosing then row.preview:SetPoint("RIGHT", row.choose, "LEFT", -6, 0)
            else row.preview:SetPoint("TOPRIGHT", -10, -10) end
            local width = LIB_RIGHT - LEFT - 10 - 64 - 6 - 84 - 10 - 84 - 10 - (choosing and 106 or 0) - 10
            row.label:SetWidth(width)
            row.detail:SetWidth(width)
        end
    end
    self.libraryCount:SetText(#results .. " sounds · page " .. (self.libraryPage + 1) .. "/" .. pages)
end

function UI:OpenLibrary(callback)
    if self.sets then self.sets:Hide() end
    if not self.library then self:CreateLibrary() end
    self.onChooseSound = callback
    self.library:Show()
    self:UpdateModal()
    self.libraryHeading.subtitle:SetText(callback and "Preview a sound, then choose it for this layer."
        or "Browse and preview sounds. Use + Sound on an action to assign one.")
    self.libraryStatus:SetText("Untried sounds have not been previewed on this client build.")
    self:RefreshLibrary()
end

function UI:RefreshSetIdentity()
    local name = R.Profile.activeSetName or "Default"
    self.setName:SetText(name)
    self.activeSetLabel:SetText("Active profile: “" .. name .. "” · Save updates this profile · Autosave on")
    self:UpdateFooter()
end

-- Sound sets grid: content 28..820.
local SETS_W, SETS_H, SETS_RIGHT = 840, 508, 820

function UI:OpenSets()
    if self.library then self.library:Hide() end
    if not self.sets then
        local f = frame(self.main, SETS_W, SETS_H, "window", "ResonanceForeverSets")
        R.Theme:Header(f, HEADER)
        self.sets = f
        f:SetPoint("CENTER")
        f:SetFrameLevel(self.main:GetFrameLevel() + 30)
        f:EnableMouse(true)
        local heading = dialogHeading(f, "Your sound sets", "Save updates the active set. Save as uses the name below. Edits also autosave.")
        closeButton(heading, function() f:Hide() end)
        self.setName = edit(f, LEFT, TOP, 360)
        self.setName:SetMaxLetters(48)
        placeholder(self.setName, "Sound set name")
        button(f, "Save", 396, TOP, 90, function()
            local ok, err = R:SaveActiveSet()
            if ok then UI:RefreshSetIdentity() end
            UI.setStatus:SetText(ok and ("Saved to “" .. R.Profile.activeSetName .. "”.") or err)
            UI.setName:ClearFocus()
            R:RefreshUI()
        end)
        button(f, "Save as", 494, TOP, 120, function()
            local ok, err = R:SaveSet(UI.setName:GetText())
            if ok then UI:RefreshSetIdentity() end
            UI.setStatus:SetText(ok and ("Saved to “" .. R.Profile.activeSetName .. "”. This is now the active set.") or err)
            UI.setName:ClearFocus()
            R:RefreshUI()
        end)
        button(f, "Load saved set", 622, TOP, SETS_RIGHT - 622, function(self)
            local entries = {}
            for name in pairs(R.Profile.sets) do entries[#entries + 1] = { label = name, value = name } end
            table.sort(entries, function(a, b) return a.label < b.label end)
            if #entries == 0 then UI.setStatus:SetText("No saved sets yet."); return end
            UI:Menu(self, entries, function(name)
                local ok, err = R:ApplySet(R.Profile.sets[name], name)
                if ok then UI:RefreshSetIdentity() end
                UI.setStatus:SetText(ok and ("Loaded “" .. name .. "”. Previous setup kept in ‘Before last load’.") or err)
            end, R.Profile.activeSetName)
        end)
        self.activeSetLabel = text(f, "", LEFT, TOP - 37, SETS_RIGHT - LEFT, "GameFontHighlightSmall")
        text(f, "Export or paste a shared set below", LEFT, TOP - 59, SETS_RIGHT - LEFT, "GameFontNormal")
        local box = frame(f, SETS_RIGHT - LEFT, 244)
        box:SetPoint("TOPLEFT", LEFT, TOP - 80)
        local s = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        s:SetPoint("TOPLEFT", 8, -8); s:SetSize(SETS_RIGHT - LEFT - 16 - GUTTER, 228)
        local e = CreateFrame("EditBox", nil, s)
        e:SetWidth(SETS_RIGHT - LEFT - 16 - GUTTER - 6); e:SetHeight(228); e:SetMultiLine(true); e:SetAutoFocus(false)
        e:SetFontObject(ChatFontNormal); e:SetMaxLetters(300020)
        e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        s:SetScrollChild(e)
        R.Theme:Scroll(s, 14)
        self.shareText = e
        local actionsY = TOP - 80 - 244 - 10
        button(f, "Export current", LEFT, actionsY, 145, function()
            UI.shareText:SetText(R:ExportSet()); UI.shareText:SetFocus(); UI.shareText:HighlightText()
            UI.setStatus:SetText("Copy this text to share your current setup.")
        end)
        button(f, "Import as saved set", LEFT + 145 + GAP, actionsY, 180, function()
            local source, err = R:ReadImport(UI.shareText:GetText())
            local name = UI.setName:GetText():match("^%s*(.-)%s*$")
            if not source then UI.setStatus:SetText(err); return end
            if name == "" or name == "Before last load" then UI.setStatus:SetText("Enter a name above for the imported set."); return end
            if name == R.Profile.activeSetName then UI.setStatus:SetText("Choose another import name to keep your active edits."); return end
            R.Profile.sets[name] = source
            UI.setStatus:SetText("Imported. Choose ‘Load saved set’ to use it.")
            UI.shareText:ClearFocus()
        end)
        self.setStatus = text(f, "Loading a set keeps an automatic backup of your previous setup.", LEFT, actionsY - 38, SETS_RIGHT - LEFT, "GameFontHighlightSmall")
        singleLine(self.setStatus)
        f:SetScript("OnHide", function()
            if UI.menu then UI.menu:Hide() end
            UI:UpdateModal()
        end)
    end
    self.sets:Show()
    self:RefreshSetIdentity()
    self.setStatus:SetText("Save updates “" .. (R.Profile.activeSetName or "Default") .. "”. Use Save as to save under the name above.")
    self:UpdateModal()
end

function R:ToggleUI()
    if not UI.main then UI:CreateMain() end
    if UI.main:IsShown() and UI.opened then UI.main:Hide(); return end
    UI.opened = true
    if not self.selected and #self.Profile.cards > 0 then
        self.selected, self.selectedRank = self.Profile.cards[1], nil
    end
    UI.main:Show()
    self:RefreshUI()
end
