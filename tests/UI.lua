-- Mocked frame integration: catches construction, callbacks and pooled-row regressions.
local root, R, frames = "Interface/AddOns/Resonance/", {}, {}
local Methods = {}
local function make(kind, parent)
    local f = setmetatable({ kind = kind, parent = parent, scripts = {}, shown = true, value = "", points = {} }, { __index = Methods })
    frames[#frames + 1] = f
    return f
end
function Methods:SetScript(name, fn) self.scripts[name] = fn end
function Methods:GetScript(name) return self.scripts[name] end
function Methods:HookScript(name, fn)
    local previous = self.scripts[name]
    self.scripts[name] = function(...)
        if previous then previous(...) end
        fn(...)
    end
end
function Methods:GetFontString()
    self.fontString = self.fontString or make("FontString", self)
    return self.fontString
end
function Methods:SetSize(w, h) self.width, self.height = w, h end
function Methods:SetWidth(w) self.width = w end
function Methods:SetHeight(h) self.height = h end
function Methods:GetWidth() return self.width or 100 end
function Methods:GetHeight() return self.height or 25 end
function Methods:SetPoint(...) self.points = { ... } end
function Methods:GetPoint() return unpack(self.points) end
function Methods:SetText(value)
    self.value = value or ""
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function Methods:GetText() return self.value end
function Methods:SetEnabled(enabled) self.enabled = enabled end
function Methods:Show() self.shown = true end
function Methods:Hide()
    local was = self.shown; self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function Methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Methods:CreateFontString() return make("FontString", self) end
function Methods:CreateTexture() return make("Texture", self) end
function Methods:GetHighlightTexture() return self.highlight end
function Methods:SetHighlightTexture() self.highlight = self:CreateTexture() end
function Methods:SetFrameLevel(level) self.level = level end
function Methods:GetFrameLevel() return self.level or 1 end
function Methods:SetScrollChild(child) self.child = child end
function Methods:GetVerticalScroll() return self.offset or 0 end
function Methods:SetVerticalScroll(offset) self.offset = offset end
function Methods:GetVerticalScrollRange() return math.max(0, (self.child and self.child:GetHeight() or 0) - self:GetHeight()) end
for _, method in ipairs({ "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetJustifyH", "SetAllPoints",
    "SetColorTexture", "SetVertexColor", "SetAutoFocus", "SetMaxLetters", "SetTexture", "SetNumeric", "ClearFocus",
    "SetFocus", "HighlightText", "SetFrameStrata", "EnableMouse", "EnableMouseWheel", "SetClampedToScreen", "ClearAllPoints",
    "SetMovable", "SetScale", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetMultiLine", "SetFontObject",
    "RegisterEvent", "RegisterUnitEvent", "UnregisterEvent", "SetTextColor", "SetHorizTile", "SetAtlas",
    "SetWordWrap", "SetMaxLines", "SetSpacing", "EnableKeyboard", "SetPropagateKeyboardInput",
    "SetDesaturated", "SetRotation", "SetTexCoord", "SetVertTile", "SetVertexColor", "SetJustifyV" }) do
    Methods[method] = function() end
end
function Methods:SetAlpha(alpha) self.alpha = alpha end
function Methods:GetParent() return self.parent end
function Methods:IsEnabled() return self.enabled ~= false end
function Methods:GetSize() return self:GetWidth(), self:GetHeight() end
-- MinimalScrollBar (styles B and C).
function Methods:RegisterCallback(event, fn, owner) self.callbacks = self.callbacks or {}; self.callbacks[event] = fn end
function Methods:SetVisibleExtentPercentage(value) self.extent = value end
function Methods:SetPanExtentPercentage(value) self.pan = value end
function Methods:SetScrollPercentage(value) self.percentage = value end
CreateFrame = function(kind, _, parent, template)
    local f = make(kind, parent)
    f.template = template
    if template == "UIPanelScrollFrameTemplate" then
        f.ScrollBar = make("Slider", f)
        f.ScrollBar.ScrollUpButton = make("Button", f.ScrollBar)
        f.ScrollBar.ScrollDownButton = make("Button", f.ScrollBar)
    end
    return f
end
UIParent = make("Frame"); UIParent:SetSize(1920, 1080)
BackdropTemplateMixin = {}
ChatFontNormal = {}
SlashCmdList = {}
GetTime = function() return 0 end
InCombatLockdown = function() return false end
UnitFullName = function() return "UITester", "Realm" end
GetRealmName = function() return "Realm" end
UnitClass = function() return "Mage", "MAGE" end
GetBuildInfo = function() return "1.60.1", "69913" end
GetCursorInfo = function() end
PlaySoundFile = function() return true, 1 end
PlaySound = PlaySoundFile
StopSound = function() end
for _, file in ipairs({ "Model", "API", "BossVoices", "Catalog", "Library", "Audio", "Sharing", "Theme", "UI", "Core" }) do
    assert(loadfile(root .. file .. ".lua"))("Resonance", R)
end
R.EventFrame.scripts.OnEvent(nil, "ADDON_LOADED", "Resonance")
assert(#R.Profile.cards == 0)
SlashCmdList.RESONANCEFOREVER("")
assert(R.UI.main:IsShown() and R.UI.empty:IsShown())
for _, name in ipairs(UISpecialFrames or {}) do
    assert(name ~= "ResonanceForeverEditor", "panel changes must not close the editor")
end
R.UI.main.scripts.OnKeyDown(R.UI.main, "P")
assert(R.UI.main:IsShown(), "spellbook key must leave editor open")
R.UI.main.scripts.OnKeyDown(R.UI.main, "ESCAPE")
assert(not R.UI.main:IsShown(), "local Escape closes editor")
R:ToggleUI()
local card = R:AddAction({ kind = "spell", spellID = 100, name = "Fireball", ranked = true, rank = "Rank 1", mode = "casting", icon = 134400 })
R:AddAction({ kind = "spell", spellID = 101, name = "Fireball", ranked = true, rank = "Rank 2", mode = "casting", icon = 134400 })
R.selected = card; R:RefreshUI()
assert(R.UI.title:GetText() == "Fireball" and R.UI.momentHeaders.casting:IsShown())
local function click(target)
    assert(target and target.scripts.OnClick, "missing clickable control")
    target.scripts.OnClick(target)
end
local function findButton(label, parent)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.value == label and (not parent or f.parent == parent) then return f end
    end
end
click(findButton("+ Sound", R.UI.momentHeaders.casting))
assert(R.UI.library:IsShown())
click(R.UI.soundRows[1].choose)
assert(#card.config.casting == 1 and not R.UI.library:IsShown())
local original = card.config.casting[1].sound
click(R.UI.perRank)
R.selectedRank = 101; R:RefreshUI()
local row = R.UI.layerRows[1]
row.delay.value = "350"
row.delay.scripts.OnTextChanged(row.delay, true)
assert(card.overrides[101].casting[1].delay == 350 and card.config.casting[1].delay == 0)
click(R.UI.resetRank)
assert(not card.overrides[101] and R:GetConfig(card, 101).casting[1].sound == original)
click(R.UI.layerRows[1].remove)
assert(#card.overrides[101].casting == 0 and #card.config.casting == 1)
R.UI:OpenLibrary()
assert(R.UI.soundRows[1].choose.enabled == false)
assert(not R.UI.soundRows[1].choose:IsShown(), "browse mode hides assignment controls")
assert(R.UI.modalShield:IsShown(), "modal blocks editing behind the picker")
assert(R.UI.libraryHeading:GetFrameLevel() > R.UI.library:GetFrameLevel() + 1, "dialog title above native border")
assert(not R.UI.previousPage.enabled, "first page cannot page backwards")
R.UI.librarySearch:SetText("no-such-sound-test-string")
assert(not R.UI.soundRows[1]:IsShown())
assert(R.UI.libraryEmpty:IsShown() and not R.UI.nextPage.enabled, "empty results explain filters and disable paging")
R.UI.librarySearch:SetText("")
click(findButton("Play", R.UI.soundRows[1]))
assert(R.UI.soundRows[1].state:GetText() == "Played")
R.UI:OpenSets()
assert(not R.UI.library:IsShown() and R.UI.sets:IsShown())
click(findButton("Save"))
assert(R.Profile.activeSetName == "Default" and R.Profile.sets.Default, "Save uses Default when no named profile is loaded")
R.UI.setName:SetText("UI snapshot")
click(findButton("Save as"))
assert(R.Profile.sets["UI snapshot"])
R.UI.setName:SetText("Different typed name")
card.config.casting[1].delay = 725
click(findButton("Save"))
assert(R.Profile.activeSetName == "UI snapshot" and not R.Profile.sets["Different typed name"], "Save targets active set regardless of name field")
assert(R.Profile.sets["UI snapshot"].cards[1].config.casting[1].delay == 725)
R.UI.setName:SetText("Second UI set")
click(findButton("Save as"))
R.Profile.cards[1].config.casting[1].delay = 900
local originalMenu = R.UI.Menu
R.UI.Menu = function(self, anchor, entries, selected) selected("UI snapshot") end
click(findButton("Load saved set"))
R.UI.Menu = originalMenu
assert(R.UI.setName:GetText() == "UI snapshot", "load updates name field")
assert(R.UI.activeSetLabel:GetText():find("UI snapshot", 1, true), "active set is visible")
R.Profile.cards[1].config.casting[1].delay = 800
click(findButton("Save"))
assert(R:ApplySet(R.Profile.sets["Second UI set"], "Second UI set"))
assert(R:ApplySet(R.Profile.sets["UI snapshot"], "UI snapshot"))
assert(R.Profile.cards[1].config.casting[1].delay == 800, "save over loaded set survives switching away and back")
R.UI:OpenSets()
assert(R.UI.setName:GetText() == "UI snapshot", "reopen shows active name")
click(findButton("Export current"))
assert(R.UI.shareText:GetText():find("RESONANCE-FOREVER-1:", 1, true) == 1)
R.UI.setName:SetText("Imported snapshot")
click(findButton("Import as saved set"))
assert(R.Profile.sets["Imported snapshot"])
R.UI.sets:Hide()
assert(not R.UI.modalShield:IsShown(), "closing dialog releases editor")
R.selected = R.Profile.cards[1]; R:RefreshUI()
click(R.UI.delete)
assert(#R.Profile.cards == 0 and R.UI.empty:IsShown())
click(R.UI.undo)
assert(#R.Profile.cards == 1 and R.selected.name == "Fireball")
R:AddSection("Combat")
R.selected.section = "Combat"; R:RefreshUI()
R.UI.search:SetText("no-match")
assert(not R.UI.actionRows[1]:IsShown())
R.UI.search:SetText("")
assert(R.UI.actionRows[1]:IsShown())
SlashCmdList.RESONANCEFOREVER("off")
assert(not R.Profile.enabled)
SlashCmdList.RESONANCEFOREVER("on")
assert(R.Profile.enabled)
local count = #frames
for _ = 1, 50 do R:RefreshUI(); R.UI:RefreshLibrary() end
assert(#frames == count, "refresh must reuse frames")
SlashCmdList.RESONANCEFOREVER("")
assert(not R.UI.main:IsShown())
SlashCmdList.RESONANCEFOREVER("")
assert(R.UI.main:IsShown())
R.selected = nil
R:ToggleUI(); R:ToggleUI()
assert(R.selected == R.Profile.cards[1], "reopening with saved actions selects the first action")

-- Layout: the left column shares one edge; InputBoxTemplate draws 5px left of its frame.
local UIref = R.UI
local searchX = select(2, UIref.search:GetPoint())
assert(searchX - 5 == 28 and searchX + UIref.search:GetWidth() == 276, "search box spans the left column")
local sectionX = select(2, UIref.sectionName:GetPoint())
assert(sectionX - 5 == 28, "section field starts on the column edge")
assert(select(2, UIref.cardEnable:GetPoint()) + UIref.cardEnable:GetWidth() == 708, "title-row toggle ends on the editor edge")
assert(select(2, UIref.delete:GetPoint()) + UIref.delete:GetWidth() == 708, "row buttons end on the editor edge")
assert(UIref.editorScroll.fullWidth == 688, "cards use the same right edge")

-- Rows use the whole well until the list overflows, then make room for the bar.
R.selected = R.Profile.cards[1]; R:RefreshUI()
assert(UIref.actionRows[1].width == 240, "short list fills the well")
for id = 700, 715 do
    R:AddAction({ kind = "spell", spellID = id, name = "Filler " .. id, ranked = false, mode = "instant", icon = 134400 })
end
R:RefreshUI()
assert(UIref.actionRows[1].width == 218 and UIref.actionScroll.width == 218, "long list reserves the scroll bar lane")
for _ = 700, 715 do R:RemoveCard(R.Profile.cards[#R.Profile.cards]) end
R.selected = R.Profile.cards[1]; R:RefreshUI()
assert(UIref.actionRows[1].width == 240)
assert(UIref.momentHeaders.casting.width == 688, "moment card spans the editor when it fits")
assert(UIref.actionScroll.scrollBarHideable and not UIref.actionScroll.ScrollBar.shown, "A hides an idle scroll bar")

-- Status messages survive refreshes; the profile line returns afterwards.
R:Status("Test message")
R:RefreshUI()
assert(UIref.status:GetText() == "Test message", "refresh keeps the current message")
R:Status(nil)
assert(UIref.status:GetText():find("Active profile", 1, true), "profile line returns")
assert(not UIref.undo:IsShown(), "undo appears only after a removal")

-- Menus mark the current value.
UIref:Menu(UIref.section, { { label = "My actions", value = "My actions" }, { label = "Combat", value = "Combat" } },
    function() end, "Combat")
assert(not UIref.menu.rows[1].check.shown and UIref.menu.rows[2].check.shown, "current menu choice is marked")
UIref.menu:Hide()

-- Styles rebuild the windows and keep working.
assert(R.Theme.skin == "A" and UIref.style:GetText() == "Style: A · Classic")
for _, id in ipairs({ "B", "C", "A" }) do
    R.UI:SetSkin(id)
    assert(R.DB.skin == id and R.Theme.skin == id and R.UI.main:IsShown(), "style " .. id .. " applies")
    assert(R.UI.style:GetText():find(id .. " ·", 1, true), "style button names " .. id)
    assert(R.UI.title:GetText() == R.selected.name, "editor refreshed in " .. id)
    if id ~= "A" then
        assert(R.UI.actionScroll.MinimalBar and R.UI.actionScroll.ScrollBar.alpha == 0, "minimal bar in " .. id)
    end
    R.UI:OpenLibrary()
    assert(R.UI.library:IsShown() and R.UI.soundRows[1]:IsShown(), "library in " .. id)
    R.UI:OpenSets()
    assert(R.UI.sets:IsShown() and not R.UI.library:IsShown(), "sets in " .. id)
    R.UI.sets:Hide()
    local built = #frames
    for _ = 1, 10 do R:RefreshUI(); R.UI:RefreshLibrary() end
    assert(#frames == built, "style " .. id .. " refresh reuses frames")
end
SlashCmdList.RESONANCEFOREVER("style c")
assert(R.DB.skin == "C" and R.UI.main:IsShown())
SlashCmdList.RESONANCEFOREVER("style z")
assert(R.DB.skin == "C", "unknown style is ignored")
SlashCmdList.RESONANCEFOREVER("style a")
assert(R.DB.skin == "A")
print("PASS: editor construction, rank edits, library, sets, removal/undo, filters, lifecycle, pooled refresh, layout, styles")
print("Library entries: " .. #R.Library)
