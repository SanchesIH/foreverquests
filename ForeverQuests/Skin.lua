local _, ns = ...

-- Look of the journal: fonts, tiles, chain nodes and the small pieces they are made of.
-- The tile art (Media\*.tga) was drawn for this addon; everything else is the game's own art.
local Skin = {}
ns.Skin = Skin

local MEDIA = "Interface\\AddOns\\ForeverQuests\\Media\\"
Skin.MEDIA = MEDIA
Skin.WHITE = "Interface\\Buttons\\WHITE8X8"
Skin.ROCK = "Interface\\FrameGeneral\\UI-Background-Rock"
Skin.MARBLE = "Interface\\FrameGeneral\\UI-Background-Marble"

Skin.GOLD = { 1, 0.82, 0 }
Skin.GREEN = { 0.25, 0.85, 0.25 }
Skin.GREY = { 0.42, 0.42, 0.42 }
Skin.RED = { 1, 0.28, 0.25 }
Skin.BLUE = { 0.25, 0.55, 1 }
Skin.PURPLE = { 0.72, 0.5, 1 }
Skin.BRIDGE = { 0.35, 0.8, 0.95 }

function Skin.HasAtlas(atlas)
    return atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
end

function Skin.SetIcon(tex, atlas, file)
    if Skin.HasAtlas(atlas) then
        tex:SetAtlas(atlas)
    else
        tex:SetTexture(file)
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

-- ------------------------------------------------------------------ fonts
local function MakeFont(name, file, size, flags, r, g, b, inherits)
    local f = _G[name] or CreateFont(name)
    if inherits and _G[inherits] then f:CopyFontObject(_G[inherits]) end
    if file then pcall(f.SetFont, f, file, size, flags or "") end
    f:SetShadowOffset(1, -1)
    f:SetShadowColor(0, 0, 0, 1)
    if r then f:SetTextColor(r, g, b) end
    return f
end

local MORPHEUS = "Fonts\\MORPHEUS.TTF"
Skin.FontTile = MakeFont("ForeverQuestsFontTile", MORPHEUS, 16, "", 1, 0.82, 0)
Skin.FontTileSmall = MakeFont("ForeverQuestsFontTileSmall", MORPHEUS, 14, "", 1, 0.82, 0)
Skin.FontTitle = MakeFont("ForeverQuestsFontTitle", MORPHEUS, 24, "", 1, 0.82, 0)
Skin.FontSection = MakeFont("ForeverQuestsFontSection", MORPHEUS, 17, "", 1, 0.82, 0)
Skin.FontStoryTitle = MakeFont("ForeverQuestsFontStoryTitle", MORPHEUS, 18, "", 1, 0.82, 0)

-- ------------------------------------------------------------------ nine-slice
-- Draws a rounded box from one 64x64 texture: corners stay sharp at any size.
local SLICE = {
    { "TOPLEFT", 0, 0.25, 0, 0.25 }, { "TOP", 0.25, 0.75, 0, 0.25 }, { "TOPRIGHT", 0.75, 1, 0, 0.25 },
    { "LEFT", 0, 0.25, 0.25, 0.75 }, { "CENTER", 0.25, 0.75, 0.25, 0.75 }, { "RIGHT", 0.75, 1, 0.25, 0.75 },
    { "BOTTOMLEFT", 0, 0.25, 0.75, 1 }, { "BOTTOM", 0.25, 0.75, 0.75, 1 }, { "BOTTOMRIGHT", 0.75, 1, 0.75, 1 },
}

--- corner: size of a corner on screen. out: how far the box spills outside the frame.
function Skin.Slice(frame, file, corner, layer, sub, out, blend)
    out = out or 0
    local s = { parts = {} }
    for i, d in ipairs(SLICE) do
        local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        t:SetTexture(MEDIA .. file)
        t:SetTexCoord(d[2], d[3], d[4], d[5])
        if blend then t:SetBlendMode(blend) end
        s.parts[i] = t
    end
    local p = s.parts
    p[1]:SetPoint("TOPLEFT", -out, out)
    p[3]:SetPoint("TOPRIGHT", out, out)
    p[7]:SetPoint("BOTTOMLEFT", -out, -out)
    p[9]:SetPoint("BOTTOMRIGHT", out, -out)
    for _, i in ipairs({ 1, 3, 7, 9 }) do p[i]:SetSize(corner, corner) end
    p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT")
    p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
    p[8]:SetPoint("TOPLEFT", p[7], "TOPRIGHT")
    p[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT")
    p[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT")
    p[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPRIGHT")
    p[6]:SetPoint("TOPLEFT", p[3], "BOTTOMLEFT")
    p[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT")
    p[5]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT")
    p[5]:SetPoint("BOTTOMRIGHT", p[9], "TOPLEFT")
    function s:SetColor(r, g, b, a)
        for _, t in ipairs(self.parts) do t:SetVertexColor(r, g, b, a or 1) end
    end
    function s:SetShown(v)
        for _, t in ipairs(self.parts) do t:SetShown(v) end
    end
    function s:Show() self:SetShown(true) end
    function s:Hide() self:SetShown(false) end
    function s:SetAlpha(a)
        for _, t in ipairs(self.parts) do t:SetAlpha(a) end
    end
    return s
end

--- A dark rounded box with a thin border, the base of every tile and panel.
function Skin.Box(frame, corner)
    corner = corner or 12
    frame.fill = Skin.Slice(frame, "Fill", corner, "BACKGROUND", -2)
    frame.fill:SetColor(0, 0, 0, 0.88)
    frame.edge = Skin.Slice(frame, "Border", corner, "BORDER", 0)
    frame.edge:SetColor(Skin.GREY[1], Skin.GREY[2], Skin.GREY[3], 1)
    return frame
end

--- Blue glow drawn around a tile while the mouse is over it.
function Skin.HoverGlow(frame, corner, color, manual)
    local c = color or Skin.BLUE
    corner = corner or 18
    -- the glow ring sits 12px into its 64px texture: line it up with the box's own border
    local g = Skin.Slice(frame, "Glow", corner, "ARTWORK", 7, corner * 0.75 - 1, "ADD")
    g:SetColor(c[1], c[2], c[3], 0.95)
    g:Hide()
    frame.glow = g
    if not manual then
        frame:HookScript("OnEnter", function(self) if not self.noGlow then self.glow:Show() end end)
        frame:HookScript("OnLeave", function(self) if not self.keepGlow then self.glow:Hide() end end)
    end
    return g
end

-- ------------------------------------------------------------------ small parts
function Skin.Check(parent, size)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    t:SetSize(size or 16, size or 16)
    Skin.SetIcon(t, "common-icon-checkmark", "Interface\\RaidFrame\\ReadyCheck-Ready")
    if not Skin.HasAtlas("common-icon-checkmark") then t:SetVertexColor(1, 1, 1) end
    return t
end

function Skin.ProgressBar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.85, 0.65, 0.1)
    bar:SetMinMaxValues(0, 1)
    bar:SetHeight(height or 6)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.07, 0.05, 0.9)
    local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0.32, 0.27, 0.18, 1)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 0, 0)
    function bar:SetProgress(done, total)
        self:SetMinMaxValues(0, math.max(1, total))
        self:SetValue(done)
        if total > 0 and done >= total then
            self:SetStatusBarColor(0.6, 0.6, 0.6)
        else
            self:SetStatusBarColor(0.85, 0.65, 0.1)
        end
    end
    return bar
end

--- "— Completed ————" separator, as in BtWQuests.
function Skin.Separator(parent)
    local f = CreateFrame("Button", nil, parent)
    f:SetHeight(26)
    f.text = f:CreateFontString(nil, "OVERLAY", "ForeverQuestsFontSection")
    f.text:SetPoint("LEFT", 14, 0)
    f.left = f:CreateTexture(nil, "ARTWORK")
    f.left:SetHeight(1)
    f.left:SetPoint("LEFT", 0, -1)
    f.left:SetPoint("RIGHT", f.text, "LEFT", -4, -1)
    f.left:SetColorTexture(1, 0.82, 0, 0.45)
    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.count:SetPoint("LEFT", f.text, "RIGHT", 6, -1)
    f.right = f:CreateTexture(nil, "ARTWORK")
    f.right:SetHeight(1)
    f.right:SetPoint("LEFT", f.count, "RIGHT", 6, 0)
    f.right:SetPoint("RIGHT", 0, -1)
    f.right:SetColorTexture(1, 0.82, 0, 0.45)
    f:SetScript("OnClick", function(self) if self.onClick then self.onClick(self) end end)
    return f
end

--- Small square icon button (pin / ignore on tiles, and the toolbar).
function Skin.IconButton(parent, size, atlas, file, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    Skin.SetIcon(b.icon, atlas, file)
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(type(tip) == "function" and tip() or tip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

-- ------------------------------------------------------------------ breadcrumb buttons
-- The navigation bar uses the game's help-frame art, like the dungeon journal.
local HELP = "Interface\\HelpFrame\\CS_HelpTextures"
local HELP_TILE = "Interface\\HelpFrame\\CS_HelpTextures_Tile"

function Skin.Crumb(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(30)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(HELP_TILE, "REPEAT", "CLAMP")
    b.bg:SetHorizTile(true)
    b.bg:SetTexCoord(0, 1, 0.0625, 0.12109375)
    b.arrow = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.arrow:SetSize(21, 30)
    b.arrow:SetPoint("LEFT", b, "RIGHT", 0, 0)
    b.arrow:SetTexture(HELP)
    b.arrow:SetTexCoord(0.88867188, 0.92968750, 0.29687500, 0.53125000)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(HELP)
    hl:SetTexCoord(0.00195313, 0.25195313, 0.65625000, 0.92187500)
    hl:SetBlendMode("ADD")
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", 14, 0)
    b.text:SetWordWrap(false)
    b.menu = CreateFrame("Button", nil, b)
    b.menu:SetSize(18, 18)
    b.menu:SetPoint("RIGHT", -4, 0)
    b.menu.art = b.menu:CreateTexture(nil, "ARTWORK")
    b.menu.art:SetSize(11, 11)
    b.menu.art:SetPoint("CENTER", 0, -1)
    b.menu.art:SetTexture("Interface\\Buttons\\SquareButtonTextures")
    b.menu.art:SetTexCoord(0.45312500, 0.64062500, 0.20312500, 0.01562500)
    b.menu:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", function(self) if self.onClick then self.onClick(self) end end)
    b.menu:SetScript("OnClick", function(self) local p = self:GetParent() if p.onMenu then p.onMenu(p) end end)
    function b:SetHome(on)
        if on then
            self.bg:SetVertexColor(1, 0.35, 0.3)
            self.text:SetFontObject("GameFontHighlight")
        else
            self.bg:SetVertexColor(1, 1, 1)
            self.text:SetFontObject("GameFontNormal")
        end
    end
    function b:Fit(withMenu)
        self.menu:SetShown(withMenu and true or false)
        local w = (self.text:GetStringWidth() or 60) + 28 + (withMenu and 18 or 0)
        self:SetWidth(math.min(240, w))
        return self:GetWidth()
    end
    return b
end

-- ------------------------------------------------------------------ popup list (crumb menus)
function Skin.Popup(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    Skin.Box(f, 10)
    f.fill:SetColor(0.05, 0.04, 0.03, 0.97)
    f.edge:SetColor(0.6, 0.5, 0.3, 1)
    f.rows = {}
    f:Hide()
    function f:Open(anchor, items)
        for _, r in ipairs(self.rows) do r:Hide() end
        local perCol = 22
        local cols = math.max(1, math.ceil(#items / perCol))
        local rowsInCol = math.min(#items, perCol)
        local w = 150
        for i, it in ipairs(items) do
            local r = self.rows[i]
            if not r then
                r = CreateFrame("Button", nil, self)
                r:SetHeight(18)
                r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                r.text:SetPoint("LEFT", 6, 0)
                r.text:SetJustifyH("LEFT")
                r.right = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                r.right:SetPoint("RIGHT", -6, 0)
                local hl = r:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(1, 0.82, 0, 0.15)
                r:SetScript("OnClick", function(self) self:GetParent():Hide() if self.onClick then self.onClick() end end)
                self.rows[i] = r
            end
            r.text:SetText(it.text)
            r.right:SetText(it.right or "")
            if it.selected then r.text:SetTextColor(1, 0.82, 0) else r.text:SetTextColor(1, 1, 1) end
            r.onClick = it.onClick
            r:Show()
            w = math.max(w, (r.text:GetStringWidth() or 100) + (r.right:GetStringWidth() or 0) + 30)
        end
        w = math.min(w, 300)
        for i in ipairs(items) do
            local r = self.rows[i]
            local col = math.floor((i - 1) / perCol)
            local row = (i - 1) % perCol
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 6 + col * w, -6 - row * 18)
            r:SetWidth(w - 4)
        end
        self:SetSize(cols * w + 10, rowsInCol * 18 + 12)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        self:Show()
    end
    return f
end
