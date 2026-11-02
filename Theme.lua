local _, R = ...
local T = {}
R.Theme = T

-- Styles change artwork only. Every style shares the geometry in UI.lua.
--   A  Classic: native Forever art (Legacy reward-track leather, red panel buttons).
--   B  Legacy:  the Legacy window used by Forever Names and Petal (challenge
--               leather, bronze plate buttons, minimal scroll bars).
--   C  Flat:    dark panels with thin borders; no client atlases.
-- Native art: Blizzard_LegacyRewardTrack.xml, Blizzard_LegacyChallenges.xml,
-- and SharedUIPanelTemplates / NineSliceLayouts. No dependency on loading the Legacy UI.
T.Skins = {
    { id = "A", label = "A · Classic" },
    { id = "B", label = "B · Legacy" },
    { id = "C", label = "C · Flat" },
}
T.skin = "A"

local WHITE = "Interface\\Buttons\\WHITE8X8"
local LEATHER = "Legacy-Rewards-Tracker-background"
local CHALLENGE = "Legacy-Challenge-BG"
-- Legacy-Challenge-BG paints a header divider around rows 55-66. As in Frame
-- Gambit, rows 0-48 form the header band and rows 74+ the body. Below about
-- row 505 the art turns into vertical streaks, which a tall panel stretches
-- into view (the editor's lower fifth in-game), so leather stops at row 490.
local BAND_ROWS, BODY_ROW, LAST_ROW = 48, 74, 490
-- The native border's title bar runs from the window's inner top (-16) to a
-- line 23px lower; C draws the same line.
local TITLE_BAR = 39
local PALETTE = {
    A = { muted = { 0.66, 0.59, 0.46 }, cardTitle = { 0.72, 0.72, 0.68 }, cardText = { 0.62, 0.64, 0.62 } },
    B = { muted = { 0.70, 0.62, 0.48 }, cardTitle = { 1, 0.82, 0 }, cardText = { 0.78, 0.72, 0.60 } },
    C = { muted = { 0.60, 0.60, 0.64 }, cardTitle = { 0.95, 0.95, 0.95 }, cardText = { 0.62, 0.62, 0.66 } },
}

function T:Use(id)
    self.skin = PALETTE[id] and id or "A"
    return self.skin
end

function T:Label(id)
    for _, skin in ipairs(self.Skins) do
        if skin.id == id then return skin.label end
    end
end

function T:Color(key) return unpack(PALETTE[self.skin][key]) end

function T:Atlas(texture, atlas)
    if not C_Texture or not C_Texture.GetAtlasInfo or not C_Texture.GetAtlasInfo(atlas) then return false end
    texture:SetAtlas(atlas, false)
    return true
end

-- Show part of an atlas: whole columns minus `side` on each edge, rows
-- first..last (last defaults to the atlas bottom).
local function Crop(texture, atlas, first, last, side)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if not info then return false end
    local du, dv = info.rightTexCoord - info.leftTexCoord, info.bottomTexCoord - info.topTexCoord
    side = side or 0
    texture:SetTexture(info.file or info.filename)
    texture:SetTexCoord(info.leftTexCoord + du * side, info.rightTexCoord - du * side,
        info.topTexCoord + dv * first / info.height, info.topTexCoord + dv * (last or info.height) / info.height)
    return true
end

local function Fill(owner, layer, sublevel, r, g, b, a, left, top, right, bottom)
    local texture = owner:CreateTexture(nil, layer, nil, sublevel)
    texture:SetPoint("TOPLEFT", left or 0, -(top or 0))
    texture:SetPoint("BOTTOMRIGHT", -(right or 0), bottom or 0)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

-- Horizontal band of fixed height, inset from the owner's top.
local function Strip(owner, layer, sublevel, r, g, b, a, left, top, right, height)
    local texture = owner:CreateTexture(nil, layer, nil, sublevel)
    texture:SetPoint("TOPLEFT", left, -top)
    texture:SetPoint("TOPRIGHT", -right, -top)
    texture:SetHeight(height)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

-- One-pixel frame, inset from the owner's edges.
local function Outline(owner, r, g, b, a, left, top, right, bottom)
    left, top, right, bottom = left or 0, top or 0, right or 0, bottom or 0
    local function line(p1, x1, y1, p2, x2, y2, horizontal)
        local texture = owner:CreateTexture(nil, "BORDER")
        texture:SetPoint(p1, x1, y1)
        texture:SetPoint(p2, x2, y2)
        if horizontal then texture:SetHeight(1) else texture:SetWidth(1) end
        texture:SetColorTexture(r, g, b, a)
    end
    line("TOPLEFT", left, -top, "TOPRIGHT", -right, -top, true)
    line("BOTTOMLEFT", left, bottom, "BOTTOMRIGHT", -right, bottom, true)
    line("TOPLEFT", left, -top, "BOTTOMLEFT", left, bottom)
    line("TOPRIGHT", -right, -top, "BOTTOMRIGHT", -right, bottom)
end

-- Sliced atlas: fixed corners, rails stretched from the undecorated centre
-- texel (repeating the ornamented edge shows seams; see Frame Gambit/Petal).
local function Plate(frame, atlas)
    local art = { pieces = {} }
    function art:Update()
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
        if not info then return end
        local w, h = frame:GetSize()
        if not w or not h or w <= 0 or h <= 0 or (self.w == w and self.h == h) then return end
        self.w, self.h = w, h
        local x, y = math.min(5, w / 2, info.width / 2), math.min(5, h / 2, info.height / 2)
        local iw, ih = info.width, info.height
        local du, dv = info.rightTexCoord - info.leftTexCoord, info.bottomTexCoord - info.topTexCoord
        local sections = {
            { 0, 0, x, y, 0, 0, x, y }, { w - x, 0, x, y, iw - x, 0, x, y },
            { 0, h - y, x, y, 0, ih - y, x, y }, { w - x, h - y, x, y, iw - x, ih - y, x, y },
            { x, 0, w - 2 * x, y, math.floor(iw / 2), 0, 1, y },
            { x, h - y, w - 2 * x, y, math.floor(iw / 2), ih - y, 1, y },
            { 0, y, x, h - 2 * y, 0, math.floor(ih / 2), x, 1 },
            { w - x, y, x, h - 2 * y, iw - x, math.floor(ih / 2), x, 1 },
            { x, y, w - 2 * x, h - 2 * y, x, y, iw - 2 * x, ih - 2 * y },
        }
        for i, p in ipairs(sections) do
            local t = self.pieces[i] or frame:CreateTexture(nil, "BACKGROUND", nil, -2)
            self.pieces[i] = t
            t:SetTexture(info.file or info.filename)
            t:SetTexCoord(info.leftTexCoord + du * p[5] / iw, info.leftTexCoord + du * (p[5] + p[7]) / iw,
                info.topTexCoord + dv * p[6] / ih, info.topTexCoord + dv * (p[6] + p[8]) / ih)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", frame, "TOPLEFT", p[1], -p[2])
            t:SetSize(math.max(0.01, p[3]), math.max(0.01, p[4]))
        end
    end
    function art:Tint(shade)
        for _, t in ipairs(self.pieces) do t:SetVertexColor(shade, shade, shade, 1) end
    end
    frame:HookScript("OnSizeChanged", function() art:Update() end)
    art:Update()
    return art
end

local function NativeBorder(owner, layout, left, top, right, bottom)
    if not (NineSliceUtil and NineSliceUtil.ApplyLayoutByName) then return end
    local border = CreateFrame("Frame", nil, owner)
    border:EnableMouse(false)
    border:SetPoint("TOPLEFT", left, top)
    border:SetPoint("BOTTOMRIGHT", right, bottom)
    NineSliceUtil.ApplyLayoutByName(border, layout)
    owner.LegacyBorder = border
    return border
end

-- kind: "window", "inset" (wells and panels), "row", or "menu" (opaque popup).
function T:Surface(owner, kind)
    kind = kind or "inset"
    if owner.SetBackdrop then owner:SetBackdrop(nil) end
    if self.skin == "C" then
        if kind == "window" then
            -- Same inner rectangle the native border encloses in A and B.
            owner.LegacyBackground = Fill(owner, "BACKGROUND", 1, 0.055, 0.058, 0.066, 0.97, 16, 16, 8, 12)
            Outline(owner, 0.30, 0.30, 0.34, 1, 16, 16, 8, 12)
        elseif kind == "menu" then
            Fill(owner, "BACKGROUND", 1, 0.075, 0.078, 0.088, 0.98)
            Outline(owner, 0.30, 0.30, 0.34, 1)
        elseif kind == "row" then
            Fill(owner, "BACKGROUND", 1, 1, 1, 1, 0.035)
            Outline(owner, 1, 1, 1, 0.07)
        else
            Fill(owner, "BACKGROUND", 1, 0, 0, 0, 0.30)
            Outline(owner, 1, 1, 1, 0.08)
        end
        return
    end
    local background = owner:CreateTexture(nil, "BACKGROUND", nil, 1)
    -- The native corner atlases contain transparent outer padding. Anchor the
    -- fill to the visible metal's inside edge, not the enclosing frame bounds.
    if kind == "window" then
        background:SetPoint("TOPLEFT", 16, -16)
        background:SetPoint("BOTTOMRIGHT", -8, 12)
    else
        background:SetPoint("TOPLEFT", 3, -3)
        background:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    local art
    if self.skin == "B" then
        art = kind == "window" and Crop(background, CHALLENGE, BODY_ROW, LAST_ROW)
            or Crop(background, CHALLENGE, 115, LAST_ROW, 0.05)
        if art and kind ~= "window" then
            local shade = kind == "row" and 0.62 or 0.8
            background:SetVertexColor(shade, shade, shade)
        end
    else
        art = self:Atlas(background, LEATHER)
    end
    if not art then background:SetColorTexture(0.09, 0.06, 0.035, 1) end
    owner.LegacyBackground = background
    if kind ~= "window" and self.skin == "A" then
        local shade = owner:CreateTexture(nil, "BACKGROUND", nil, 2)
        shade:SetPoint("TOPLEFT", 3, -3)
        shade:SetPoint("BOTTOMRIGHT", -3, 3)
        shade:SetColorTexture(0, 0, 0, kind == "row" and 0.34 or 0.15)
    end
    local border
    if kind == "window" then
        -- Compensate the native non-portrait layout's exterior corner offsets.
        border = NativeBorder(owner, "ButtonFrameTemplateNoPortrait", 8, -16, -2, 8)
    else
        border = NativeBorder(owner, "InsetFrameTemplate", 0, 0, 0, 1)
        if border and self.skin == "B" then
            -- The stock inset bevel is silver; bring it into the bronze interior.
            for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
                "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }) do
                if border[key] then border[key]:SetVertexColor(0.72, 0.57, 0.36, 0.8) end
            end
        end
    end
    if not border then
        -- Fallback remains legible if the native border is absent in a later beta.
        if kind == "window" then Outline(owner, 0.40, 0.29, 0.13, 1, 16, 16, 8, 12)
        else Outline(owner, 0.40, 0.29, 0.13, 1) end
    end
end

function T:Rule(owner, x, y, width)
    local line = owner:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", x, y)
    line:SetSize(width, 8)
    if self:Atlas(line, "_UI-Frame-InnerTopTile") then
        line:SetHorizTile(true)
    else
        line:SetHeight(1)
        line:SetColorTexture(0.47, 0.34, 0.16, 0.8)
    end
    return line
end

-- Header band from the window's inner top edge down to `height`.
function T:Header(owner, height)
    if self.skin == "C" then
        Strip(owner, "BACKGROUND", 2, 1, 1, 1, 0.035, 16, 16, 8, TITLE_BAR - 16)
        Strip(owner, "BORDER", 0, 1, 1, 1, 0.09, 16, TITLE_BAR, 8, 1)
        Strip(owner, "BACKGROUND", 2, 1, 1, 1, 0.02, 16, TITLE_BAR + 1, 8, height - TITLE_BAR - 1)
        Strip(owner, "BORDER", 0, 1, 1, 1, 0.09, 16, height, 8, 1)
        return
    end
    local band = owner:CreateTexture(nil, "BACKGROUND", nil, 3)
    band:SetPoint("TOPLEFT", 16, -16)
    band:SetPoint("TOPRIGHT", -8, -16)
    if self.skin == "B" then
        band:SetHeight(height - 16)
        if not Crop(band, CHALLENGE, 0, BAND_ROWS) then band:SetColorTexture(0.10, 0.065, 0.03, 0.7) end
        if owner.LegacyBackground then
            owner.LegacyBackground:SetPoint("TOPLEFT", 16, -height)
        end
        -- A dark groove over a faint bronze catch-light, like the atlas line.
        Strip(owner, "BORDER", 0, 0, 0, 0, 0.6, 16, height, 8, 1)
        Strip(owner, "BORDER", 0, 0.62, 0.47, 0.26, 0.38, 16, height + 1, 8, 1)
        return
    end
    band:SetHeight(height - 18)
    if self:Atlas(band, "_UI-Frame-TitleTileBg") then
        band:SetHorizTile(true)
    else
        band:SetColorTexture(0.10, 0.065, 0.03, 0.7)
    end
    self:Rule(owner, 16, -height, owner:GetWidth() - 24)
end

-- Horizontal separator inside a window.
function T:Line(owner, x, y, width)
    local line = owner:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", x, y)
    line:SetSize(width, 1)
    if self.skin == "C" then line:SetColorTexture(1, 1, 1, 0.08)
    else line:SetColorTexture(0.47, 0.34, 0.16, 0.6) end
    return line
end

function T:Divider(owner, x, y, height)
    local divider = owner:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", x, y)
    divider:SetSize(10, height)
    if self.skin == "C" or not self:Atlas(divider, "Legacy-Tree-Frame-divider-Vertical") then
        divider:SetPoint("TOPLEFT", x + 4, y)
        divider:SetWidth(1)
        if self.skin == "C" then divider:SetColorTexture(1, 1, 1, 0.08)
        else divider:SetColorTexture(0.47, 0.34, 0.16, 0.85) end
    end
end

function T:Section(owner)
    local bg = owner:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 0, -1)
    bg:SetPoint("BOTTOMRIGHT", 0, 1)
    if self.skin == "C" then
        bg:SetColorTexture(1, 1, 1, 0.05)
        local line = owner:CreateTexture(nil, "BORDER")
        line:SetPoint("BOTTOMLEFT", 0, 1)
        line:SetPoint("BOTTOMRIGHT", 0, 1)
        line:SetHeight(1)
        line:SetColorTexture(1, 0.82, 0, 0.30)
    elseif not self:Atlas(bg, "Legacy-Challenge-Cards-Ribbon-Brown") then
        bg:SetColorTexture(0.16, 0.09, 0.025, 0.8)
    end
end

-- Action list row: hover, selection and icon frame.
function T:Action(owner)
    local highlight = owner:GetHighlightTexture()
    if self.skin == "C" then
        highlight:SetVertexColor(1, 1, 1, 0.05)
        owner.bg:SetColorTexture(1, 0.82, 0, 0.09)
        owner.accent = owner:CreateTexture(nil, "ARTWORK", nil, 1)
        owner.accent:SetPoint("TOPLEFT")
        owner.accent:SetPoint("BOTTOMLEFT")
        owner.accent:SetWidth(2)
        owner.accent:SetColorTexture(1, 0.82, 0, 0.9)
        return
    end
    if self.skin == "B" then
        highlight:SetVertexColor(1, 0.82, 0.3, 0.12)
        owner.bg:SetColorTexture(1, 0.65, 0.12, 0.18)
    else
        highlight:SetVertexColor(0.85, 0.63, 0.19, 0.12)
        owner.bg:SetColorTexture(0.50, 0.32, 0.055, 0.34)
    end
    local trim = owner:CreateTexture(nil, "OVERLAY")
    trim:SetPoint("CENTER", owner.icon, "CENTER", 0, 0)
    trim:SetSize(44, 44)
    trim:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    trim:SetVertexColor(0.88, 0.74, 0.48, 1)
end

-- Moment card (Cast, Casting, Channeling) that grows around its sound layers.
function T:ChallengeCard(owner)
    if self.skin == "C" then
        Fill(owner, "BACKGROUND", 0, 1, 1, 1, 0.035)
        Outline(owner, 1, 1, 1, 0.08)
        Strip(owner, "BACKGROUND", 1, 1, 1, 1, 0.03, 1, 1, 1, 50)
        return
    end
    -- Use the same expandable card art as LegacyChallengeTemplate. Fixed-height
    -- caps preserve the bevel; one continuous middle avoids seams at tile joins.
    -- A uses the darker incomplete-card art; B the regular card.
    local suffix = self.skin == "B" and "" or "-Disable"
    local names = {
        "Legacy-Challenge-Cards-tiled-top" .. suffix,
        "Legacy-Challenge-Cards-tiled-vertical" .. suffix,
        "Legacy-Challenge-Cards-tiled-bottom" .. suffix,
    }
    local info = {}
    for i, name in ipairs(names) do
        info[i] = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
    end
    if info[1] and info[2] and info[3] then
        local middle = owner:CreateTexture(nil, "BACKGROUND", nil, -1)
        self:Atlas(middle, names[2])
        -- This atlas has a visible break at repeated tile boundaries. Stretch
        -- its straight side rails instead, retaining fixed-size corner caps.
        middle:SetVertTile(false)
        middle:SetPoint("TOPLEFT", 0, -10)
        middle:SetPoint("BOTTOMRIGHT", 0, 10)
        local top = owner:CreateTexture(nil, "BACKGROUND")
        self:Atlas(top, names[1])
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        top:SetHeight(info[1].height)
        local bottom = owner:CreateTexture(nil, "BACKGROUND")
        self:Atlas(bottom, names[3])
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        bottom:SetHeight(info[3].height)
    else
        local background = owner:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        if not self:Atlas(background, "Legacy-Challenge-Cards" .. suffix) then
            background:SetColorTexture(0.065, 0.045, 0.03, 1)
        end
    end
    -- A: the account-wide blue ribbon of the reference. B: the brown ribbon.
    -- Purely visual; action enabled state is independent.
    local ribbon = owner:CreateTexture(nil, "BORDER")
    ribbon:SetPoint("TOPLEFT", 5, -4)
    ribbon:SetSize(440, 35)
    local ribbonAtlas = self.skin == "B" and "Legacy-Challenge-Cards-Ribbon-Brown" or "Legacy-Challenge-Cards-Ribbon-Blue-Disable"
    if not self:Atlas(ribbon, ribbonAtlas) then
        ribbon:SetColorTexture(0.025, 0.10, 0.105, 0.35)
    end
end

-- Panel buttons. A keeps the native red template art.
function T:Button(button)
    if self.skin == "A" then return end
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" }) do
        if button[key] then button[key]:Hide() end
    end
    for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local texture = button[key] and button[key](button)
        if texture then texture:SetAlpha(0) end
    end
    local pressed, update = false
    if self.skin == "B" then
        local art = Plate(button, "common-button-list-collapseExpand")
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetPoint("TOPLEFT", 4, -4)
        hover:SetPoint("BOTTOMRIGHT", -4, 4)
        hover:SetColorTexture(1, 0.7, 0.2, 0.12)
        update = function() art:Tint(not button:IsEnabled() and 0.45 or pressed and 0.7 or 1) end
    else
        local fill = Fill(button, "BACKGROUND", 0, 0.14, 0.145, 0.16, 1)
        Outline(button, 1, 1, 1, 0.13)
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.07)
        update = function()
            local shade = not button:IsEnabled() and 0.5 or pressed and 0.7 or 1
            fill:SetVertexColor(shade, shade, shade, 1)
        end
    end
    button:HookScript("OnMouseDown", function() pressed = true; update() end)
    button:HookScript("OnMouseUp", function() pressed = false; update() end)
    button:HookScript("OnHide", function() pressed = false; update() end)
    button:HookScript("OnEnable", update)
    button:HookScript("OnDisable", update)
end

-- Window close button. A and B use the native square; C draws a flat cross.
function T:CloseButton(parent)
    if self.skin ~= "C" then
        local close = CreateFrame("Button", nil, parent, "UIPanelCloseButtonNoScripts")
        close:SetSize(24, 24)
        -- Our own placement (border TOPRIGHT -2, 1). Forever 70532 moved the native
        -- Camelot close button to border TOPRIGHT (0, 3) at 28px; see the review notes.
        close:SetPoint("TOPRIGHT", -4, -15)
        return close
    end
    local close = CreateFrame("Button", nil, parent)
    close:SetSize(20, 20)
    -- Centred in the title bar (-16..-39), 8px from the inner right edge.
    close:SetPoint("TOPRIGHT", -16, -17.5)
    local hover = close:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.08)
    for _, angle in ipairs({ 45, -45 }) do
        local stroke = close:CreateTexture(nil, "ARTWORK")
        stroke:SetPoint("CENTER")
        stroke:SetSize(14, 2)
        stroke:SetColorTexture(0.82, 0.82, 0.86, 1)
        stroke:SetRotation(math.rad(angle))
    end
    return close
end

-- Single-line input fields (InputBoxTemplate). A and B keep native art.
function T:Edit(field)
    if self.skin ~= "C" then return end
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        if field[key] then field[key]:Hide() end
    end
    -- Match the native box footprint: 5px left of the frame, 20px tall.
    Fill(field, "BACKGROUND", 0, 0, 0, 0, 0.45, -5, 2, 0, 3)
    Outline(field, 1, 1, 1, 0.14, -5, 2, 0, 3)
end

-- UIPanelScrollFrameTemplate: hide the bar when the content fits and scroll
-- one row per wheel step. B and C draw Blizzard's MinimalScrollBar (as used by
-- LegacyChallengeCategoryList) in the same 22px gutter; the template bar stays
-- functional but invisible.
function T:Scroll(scroll, step)
    local template = scroll.ScrollBar
    if template then template.scrollStep = step end
    local bar
    if self.skin ~= "A" and template then
        local ok, created = pcall(CreateFrame, "EventFrame", nil, scroll:GetParent(), "MinimalScrollBar")
        if ok and created and created.RegisterCallback and created.SetScrollPercentage then bar = created end
    end
    if not bar then
        scroll.scrollBarHideable = true
        if template then template:Hide() end
        return
    end
    template:SetAlpha(0)
    for _, part in ipairs({ template, template.ScrollUpButton, template.ScrollDownButton }) do
        if part then part:EnableMouse(false) end
    end
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 10, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 10, 0)
    -- Above the well's inset border, which shares the scroll frame's parent.
    bar:SetFrameLevel(scroll:GetFrameLevel() + 2)
    local function sync()
        local range = math.max(0, scroll:GetVerticalScrollRange())
        local height = math.max(1, scroll:GetHeight())
        bar.syncing = true
        bar:SetVisibleExtentPercentage(height / (height + range))
        bar:SetPanExtentPercentage(range > 0 and math.min(1, step / range) or 1)
        bar:SetScrollPercentage(range > 0 and scroll:GetVerticalScroll() / range or 0)
        bar.syncing = false
        bar:SetShown(range > 0)
    end
    bar:RegisterCallback("OnScroll", function(_, percentage)
        if not bar.syncing then
            scroll:SetVerticalScroll(percentage * math.max(0, scroll:GetVerticalScrollRange()))
        end
    end, scroll)
    scroll:HookScript("OnScrollRangeChanged", sync)
    scroll:HookScript("OnVerticalScroll", sync)
    scroll:HookScript("OnShow", sync)
    scroll.MinimalBar = bar
    sync()
end
