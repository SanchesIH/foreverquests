local _, ns = ...
local L = ns.L
local ST = ns.ST
local Skin = ns.Skin

-- The journal window, laid out like BtWQuests: portrait, back/forward/here buttons, a
-- breadcrumb bar and search on top; the sidebar on the left; tiles, lists and the chain tree
-- on a rock background; the chain's story beside the tree (Story.lua).
local UI = {}
ns.UI = UI

local ICON = "Interface\\Icons\\INV_Misc_Map02"
local GOLD, GREEN, GREY, RED, PURPLE, BLUE, BRIDGE = Skin.GOLD, Skin.GREEN, Skin.GREY, Skin.RED, Skin.PURPLE, Skin.BLUE, Skin.BRIDGE

local STATUS_COLOR = {
    [ST.DONE] = GREEN,
    [ST.READY] = GOLD,
    [ST.ACTIVE] = GOLD,
    [ST.AVAILABLE] = GOLD,
    [ST.LEVEL] = RED,
    [ST.LOCKED] = GREY,
    [ST.EXCLUDED] = { 0.35, 0.3, 0.3 },
    [ST.SKIPPED] = { 0.4, 0.4, 0.4 },
}
UI.STATUS_COLOR = STATUS_COLOR

local function Hex(c) return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
local function Color(text, c) return Hex(c) .. text .. "|r" end
UI.Color = Color

local function Arrow(dir)
    local atlas = (dir == "out") and "common-icon-forwardarrow" or "common-icon-backarrow"
    if Skin.HasAtlas(atlas) and CreateAtlasMarkup then return CreateAtlasMarkup(atlas, 14, 14) .. " " end
    return ""
end
UI.Arrow = Arrow

local function SetStatusIcon(tex, st, flags)
    tex:SetDesaturated(false)
    tex:SetVertexColor(1, 1, 1)
    local repeatable = flags and bit.band(flags, ns.FLAG_REPEAT) ~= 0
    if st == ST.DONE then
        Skin.SetIcon(tex, "common-icon-checkmark", "Interface\\RaidFrame\\ReadyCheck-Ready")
    elseif st == ST.READY then
        Skin.SetIcon(tex, "QuestTurnin", "Interface\\GossipFrame\\ActiveQuestIcon")
    elseif st == ST.ACTIVE then
        Skin.SetIcon(tex, "QuestTurnin", "Interface\\GossipFrame\\ActiveQuestIcon")
        tex:SetDesaturated(true)
        tex:SetVertexColor(1, 0.9, 0.6)
    elseif st == ST.AVAILABLE then
        if repeatable then
            Skin.SetIcon(tex, "QuestDaily", "Interface\\GossipFrame\\DailyQuestIcon")
        else
            Skin.SetIcon(tex, "QuestNormal", "Interface\\GossipFrame\\AvailableQuestIcon")
        end
    elseif st == ST.LEVEL then
        Skin.SetIcon(tex, "QuestNormal", "Interface\\GossipFrame\\AvailableQuestIcon")
        tex:SetDesaturated(true)
        tex:SetVertexColor(1, 0.3, 0.3)
    elseif st == ST.LOCKED then
        Skin.SetIcon(tex, nil, "Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
    else
        Skin.SetIcon(tex, "common-icon-redx", "Interface\\RaidFrame\\ReadyCheck-NotReady")
        tex:SetDesaturated(true)
    end
end
UI.SetStatusIcon = SetStatusIcon

local STATUS_TEXT = {
    [ST.DONE] = function() return L.ST_DONE end,
    [ST.READY] = function() return L.ST_READY end,
    [ST.ACTIVE] = function() return L.ST_ACTIVE end,
    [ST.AVAILABLE] = function() return L.ST_AVAILABLE end,
    [ST.LEVEL] = function(id) return L.ST_LEVEL:format(ns.Q[id][ns.F.REQ] or 0) end,
    [ST.LOCKED] = function() return L.ST_LOCKED end,
    [ST.EXCLUDED] = function() return L.ST_EXCLUDED end,
    [ST.SKIPPED] = function() return L.ST_SKIPPED end,
}
UI.STATUS_TEXT = STATUS_TEXT

local function LevelText(lo, hi)
    if not lo or lo == 0 then return "" end
    if lo == hi or not hi or hi == 0 then return L.LEVEL_ONE:format(lo) end
    return L.LEVEL_RANGE:format(lo, hi)
end
UI.LevelText = LevelText

local function QuestCount(n)
    if n == 1 then return L.QUEST_1 end
    return L.QUESTS_N:format(n)
end

local function TryCreate(ftype, name, parent, template)
    local ok, f = pcall(CreateFrame, ftype, name, parent, template)
    if ok and f then return f end
end

local function PanelButton(parent, text, w, h)
    local b = TryCreate("Button", nil, parent, "UIPanelButtonTemplate")
    if not b then
        b = CreateFrame("Button", nil, parent)
        Skin.Box(b, 8)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER")
        b:SetFontString(fs)
    end
    b:SetSize(w or 90, h or 22)
    b:SetText(text or "")
    return b
end
UI.PanelButton = PanelButton

--- Where a quest is picked up, for lists that mix maps (class, professions, search).
local function QuestPlace(id)
    local q = ns.Q[id]
    local cat = q[ns.F.CAT]
    if cat >= 800000 or cat == 0 then
        local map = q[11] or q[16]
        if map then return ns.MapName(map) end
    end
    return ns.CatName(cat)
end
UI.QuestPlace = QuestPlace

local function SortQuests(list)
    table.sort(list, function(a, b)
        local qa, qb = ns.Q[a], ns.Q[b]
        if (qa[ns.F.REQ] or 0) ~= (qb[ns.F.REQ] or 0) then return (qa[ns.F.REQ] or 0) < (qb[ns.F.REQ] or 0) end
        if (qa[ns.F.LVL] or 0) ~= (qb[ns.F.LVL] or 0) then return (qa[ns.F.LVL] or 0) < (qb[ns.F.LVL] or 0) end
        return a < b
    end)
    return list
end

-- ------------------------------------------------------------------ tooltips
local function AddQuestList(tt, header, list)
    if not list or #list == 0 then return end
    local shown = false
    for _, id in ipairs(list) do
        if ns.Q[id] and ns.IsEligible(id) then
            if not shown then
                tt:AddLine(" ")
                tt:AddLine(header, GOLD[1], GOLD[2], GOLD[3])
                shown = true
            end
            local c = STATUS_COLOR[ns.Status(id)]
            tt:AddDoubleLine("  " .. ns.QName(id), QuestPlace(id), c[1], c[2], c[3], 0.6, 0.6, 0.6)
        end
    end
end

function UI:QuestTooltip(owner, id, opts)
    local q = ns.Q[id]
    if not q then return end
    opts = opts or {}
    local tt = GameTooltip
    tt:SetOwner(owner, opts.anchor or "ANCHOR_RIGHT")
    local st = ns.Status(id)
    local c = STATUS_COLOR[st]
    tt:AddLine(ns.QName(id), 1, 0.82, 0, true)
    local lvl = L.TT_LEVEL:format(q[ns.F.LVL] or 0)
    if (q[ns.F.REQ] or 0) > 0 then lvl = lvl .. " (" .. L.TT_REQ:format(q[ns.F.REQ]) .. ")" end
    tt:AddDoubleLine(lvl, QuestPlace(id), 0.8, 0.8, 0.8, 0.6, 0.6, 0.6)
    tt:AddLine(STATUS_TEXT[st](id), c[1], c[2], c[3])

    local flags = q[ns.F.FLAGS] or 0
    local tags = {}
    if bit.band(flags, ns.FLAG_REPEAT) ~= 0 then tags[#tags + 1] = L.TAG_REPEAT end
    if bit.band(flags, ns.FLAG_ITEM) ~= 0 then tags[#tags + 1] = L.TAG_ITEM end
    if bit.band(flags, ns.FLAG_BREADCRUMB) ~= 0 then tags[#tags + 1] = L.TAG_BREADCRUMB end
    if bit.band(flags, ns.FLAG_NEW) ~= 0 then tags[#tags + 1] = L.TAG_FOREVER end
    if #tags > 0 then tt:AddLine(table.concat(tags, " · "), 0.8, 0.75, 0.6) end
    local dest = ns.BridgeTo(id)
    if dest then
        tt:AddLine(L.BRIDGE_TAG .. ": " .. L.BRIDGE_TO:format(ns.CatName(dest)), BRIDGE[1], BRIDGE[2], BRIDGE[3], true)
    end

    local obj = ns.QObjective(id)
    if obj and obj ~= "" then
        tt:AddLine(" ")
        tt:AddLine(obj, 1, 0.95, 0.8, true)
    end

    tt:AddLine(" ")
    local function place(kind, eid, map, x, y, label)
        local who = ns.EntityName(kind, eid)
        if kind == 3 and who then who = L.TT_ITEM:format(who) end
        local where = map and ("%s (%.1f, %.1f)"):format(ns.MapName(map), x, y) or L.TT_UNKNOWN_LOC
        tt:AddDoubleLine(label .. " " .. (who or "?"), where, GOLD[1], GOLD[2], GOLD[3], 0.8, 0.8, 0.8)
    end
    if q[9] then place(q[9], q[10], q[11], q[12], q[13], L.TT_START) end
    if q[14] then place(q[14], q[15], q[16], q[17], q[18], L.TT_END) end

    AddQuestList(tt, L.TT_PREREQ, q[ns.F.PREALL])
    AddQuestList(tt, L.TT_PREREQ_ANY, q[ns.F.PREANY])
    if q[ns.F.BCFOR] then AddQuestList(tt, L.TT_NEXT, { q[ns.F.BCFOR] }) end
    if ns.CHILD and ns.CHILD[id] then AddQuestList(tt, L.TT_UNLOCKS_ACCEPT, ns.CHILD[id]) end
    AddQuestList(tt, L.TT_EXCL, q[ns.F.EXCL])

    tt:AddLine(" ")
    if opts.node then
        tt:AddLine(L.TT_NODE_CLICK, 0.5, 1, 0.5)
        tt:AddLine(L.TT_NODE_RIGHT, 0.5, 1, 0.5)
    else
        tt:AddLine(L.TT_CLICK, 0.5, 1, 0.5)
        if opts.rightOpensChain and q[ns.F.CHAIN] then tt:AddLine(L.TT_RIGHT, 0.5, 1, 0.5) end
    end
    tt:AddLine(L.TT_SHIFT, 0.5, 1, 0.5)
    tt:AddLine("ID " .. id, 0.4, 0.4, 0.4)
    tt:Show()
end

function UI:QuestClick(id, button, fromList)
    if button == "RightButton" then
        local cid = ns.Q[id][ns.F.CHAIN]
        if fromList and cid then self:OpenChain(cid, id) end
        return
    end
    ns:ShowLocation(id, IsShiftKeyDown())
end

-- ------------------------------------------------------------------ widget pools
local function NewPool(createFunc) return { free = {}, used = {}, create = createFunc } end

local function Acquire(pool, parent)
    local w = table.remove(pool.free)
    if not w then w = pool.create(parent) end
    if w.SetParent and w:GetParent() ~= parent then w:SetParent(parent) end
    w:ClearAllPoints()
    w:Show()
    pool.used[#pool.used + 1] = w
    return w
end
UI.Acquire = Acquire

local function ReleaseAll(pool)
    for i = #pool.used, 1, -1 do
        local w = pool.used[i]
        w:Hide()
        pool.free[#pool.free + 1] = w
        pool.used[i] = nil
    end
end
UI.ReleaseAll = ReleaseAll
UI.NewPool = NewPool

-- ------------------------------------------------------------------ tiles
local PIN_ATLAS, PIN_FILE = "PetJournal-FavoritesIcon", "Interface\\Common\\FavoritesIcon"
local IGNORE_FILE = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

local function TileHover(b)
    local over = b:IsMouseOver()
    b.glow:SetShown(over or b.keepGlow)
    b.pin:SetShown(over and b.key ~= nil or (b.key and ns.IsPinned(b.key)))
    b.ignore:SetShown(over and b.key ~= nil)
    b.check:SetShown(b.done and not over)
    if not over then GameTooltip:Hide() end
end

-- category / chain tile: dark rounded box, gold title, blue glow on hover
local function TileCreate(parent)
    local b = CreateFrame("Button", nil, parent)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Skin.Box(b, 12)
    Skin.HoverGlow(b, 20, BLUE, true)
    b.title = b:CreateFontString(nil, "OVERLAY", "ForeverQuestsFontTile")
    b.title:SetPoint("TOPLEFT", 10, -10)
    b.title:SetPoint("TOPRIGHT", -10, -10)
    b.title:SetHeight(36)
    b.title:SetJustifyH("CENTER")
    b.title:SetJustifyV("TOP")
    b.title:SetWordWrap(true)
    if b.title.SetMaxLines then b.title:SetMaxLines(2) end
    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.sub:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -1)
    b.sub:SetPoint("TOPRIGHT", b.title, "BOTTOMRIGHT", 0, -1)
    b.sub:SetJustifyH("CENTER")
    b.sub:SetWordWrap(false)
    b.note = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.note:SetPoint("TOPLEFT", b.sub, "BOTTOMLEFT", 0, -2)
    b.note:SetPoint("TOPRIGHT", b.sub, "BOTTOMRIGHT", 0, -2)
    b.note:SetJustifyH("CENTER")
    b.note:SetWordWrap(false)
    b.bar = Skin.ProgressBar(b, 5)
    b.bar:SetPoint("BOTTOMLEFT", 28, 11)
    b.bar:SetPoint("BOTTOMRIGHT", -54, 11)
    b.bar.text:Hide()
    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.count:SetPoint("LEFT", b.bar, "RIGHT", 6, 0)
    b.check = Skin.Check(b, 16)
    b.check:SetPoint("BOTTOMRIGHT", -8, 6)
    b.pin = Skin.IconButton(b, 16, PIN_ATLAS, PIN_FILE, function() return b.key and ns.IsPinned(b.key) and L.UNPIN or L.PIN end)
    b.pin:SetPoint("BOTTOMRIGHT", -8, 6)
    b.ignore = Skin.IconButton(b, 16, nil, IGNORE_FILE, function() return b.key and ns.IsIgnored(b.key) and L.UNIGNORE or L.IGNORE end)
    b.ignore:SetPoint("BOTTOMLEFT", 8, 6)
    b.pin:Hide()
    b.ignore:Hide()
    b.pin:SetScript("OnClick", function() if b.key then ns.TogglePin(b.key) UI:Refresh() end end)
    b.ignore:SetScript("OnClick", function() if b.key then ns.ToggleIgnore(b.key) UI:Refresh() end end)
    for _, child in ipairs({ b.pin, b.ignore }) do
        child:HookScript("OnLeave", function() TileHover(b) end)
        child:HookScript("OnEnter", function() b.glow:Show() end)
    end
    b:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
    b:SetScript("OnEnter", function(self)
        TileHover(self)
        self.glow:Show()
        self.pin:SetShown(self.key ~= nil)
        self.ignore:SetShown(self.key ~= nil)
        self.check:Hide()
        if self.onEnter then self.onEnter(self) end
    end)
    b:SetScript("OnLeave", function(self) TileHover(self) end)
    return b
end

--- started: green border. Done: grey border, check mark (the "Completed" separator groups them).
local function TileState(b, started, done, locked)
    b.done = done and true or false
    b.check:SetShown(b.done)
    if started then
        b.edge:SetColor(GREEN[1], GREEN[2], GREEN[3], 1)
    elseif locked then
        b.edge:SetColor(0.5, 0.18, 0.15, 1)
    else
        b.edge:SetColor(GREY[1], GREY[2], GREY[3], 1)
    end
    b.pin.icon:SetDesaturated(not (b.key and ns.IsPinned(b.key)))
    b.pin:SetShown(b.key and ns.IsPinned(b.key) and not b.done or false)
    if b.pin:IsShown() then b.check:Hide() end
    b.ignore:Hide()
    b.glow:Hide()
end

-- list row (standalone quests, search results), BtWQuests list-item look
local function RowCreate(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(28)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Skin.Box(b, 8)
    Skin.HoverGlow(b, 14, BLUE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 10, 0)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.check = Skin.Check(b, 14)
    b.check:SetPoint("RIGHT", -10, 0)
    b.chainBtn = PanelButton(b, L.CHAIN_BTN, 64, 20)
    b.chainBtn:SetPoint("RIGHT", -28, 0)
    b.chainBtn:SetScript("OnClick", function(self) local r = self:GetParent() if r.onChain then r.onChain() end end)
    b.right = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.right:SetPoint("RIGHT", -100, 0)
    b.right:SetJustifyH("RIGHT")
    b.level = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.level:SetPoint("RIGHT", b.right, "LEFT", -12, 0)
    b.level:SetWidth(48)
    b.level:SetJustifyH("RIGHT")
    b.name:SetPoint("RIGHT", b.level, "LEFT", -6, 0)
    b:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
    b:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function SeparatorCreate(parent) return Skin.Separator(parent) end

local function TextCreate(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetAllPoints()
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    return f
end

-- bridge strip on a map page: "arrives from" / "leaves to"
local function BridgeRowCreate(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(24)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(Skin.MEDIA .. "Fade")
    b.bg:SetVertexColor(BRIDGE[1] * 0.35, BRIDGE[2] * 0.35, BRIDGE[3] * 0.4, 0.9)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 8, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text:SetPoint("RIGHT", -8, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(BRIDGE[1], BRIDGE[2], BRIDGE[3], 0.12)
    b:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
    b:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- ------------------------------------------------------------------ chain nodes
-- Same art as BtWQuests' chain items: the group finder button with its cover frame.
local NODE_W, NODE_H, COL_W, ROW_H = 190, 60, 210, 92
UI.NODE_W, UI.NODE_H = NODE_W, NODE_H
local MEGA = "Interface\\PVPFrame\\PvPMegaQueue"

local function NodeCreate(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(NODE_W, NODE_H)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.art = b:CreateTexture(nil, "BACKGROUND")
    b.art:SetSize(180, 50)
    b.art:SetPoint("CENTER")
    b.cover = b:CreateTexture(nil, "ARTWORK", nil, -1)
    b.cover:SetSize(190, 60)
    b.cover:SetPoint("CENTER")
    if Skin.HasAtlas("groupfinder-button-arenas") and Skin.HasAtlas("groupfinder-button-cover") then
        b.art:SetAtlas("groupfinder-button-arenas")
        b.cover:SetAtlas("groupfinder-button-cover")
    else
        b.art:SetTexture(Skin.WHITE)
        b.art:SetVertexColor(0.16, 0.12, 0.08, 1)
        b.cover:Hide()
        Skin.Box(b, 10)
        b.fill:SetColor(0.1, 0.08, 0.05, 0.6)
        b.edge:SetColor(0.65, 0.5, 0.25, 1)
    end
    b.next = Skin.Slice(b, "Glow", 18, "ARTWORK", 1, 8.5, "ADD")
    b.next:SetColor(1, 0.75, 0.2, 0.7)
    b.next:Hide()
    b.sel = Skin.Slice(b, "Glow", 18, "ARTWORK", 2, 8.5, "ADD")
    b.sel:SetColor(BLUE[1], BLUE[2], BLUE[3], 1)
    b.sel:Hide()
    b.active = b:CreateTexture(nil, "OVERLAY")
    b.active:SetSize(180, 50)
    b.active:SetPoint("CENTER")
    b.active:SetTexture(MEGA)
    b.active:SetTexCoord(0.00195313, 0.63867188, 0.76953125, 0.83007813)
    b.active:SetBlendMode("ADD")
    b.active:SetAlpha(0.5)
    b.active:Hide()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(180, 50)
    hl:SetPoint("CENTER")
    hl:SetTexture(MEGA)
    hl:SetTexCoord(0.00195313, 0.63867188, 0.70703125, 0.76757813)
    hl:SetBlendMode("ADD")
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- name on top (up to two lines), level / map on its own line underneath: nothing overlaps
    b.name:SetPoint("TOPLEFT", 14, -9)
    b.name:SetPoint("TOPRIGHT", -12, -9)
    b.name:SetHeight(27)
    b.name:SetJustifyV("TOP")
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(true)
    if b.name.SetMaxLines then b.name:SetMaxLines(2) end
    b.level = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.level:SetPoint("BOTTOMLEFT", 14, 8)
    b.level:SetPoint("RIGHT", -44, 0)
    b.level:SetJustifyH("LEFT")
    b.level:SetWordWrap(false)
    b.status = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.status:SetSize(15, 15)
    b.status:SetPoint("BOTTOMRIGHT", -9, 7)
    b.tag = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.tag:SetSize(14, 14)
    b.tag:SetPoint("BOTTOMRIGHT", b.status, "BOTTOMLEFT", -2, 0)
    b:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
    b:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function NodeReset(b)
    b.next:Hide()
    b.sel:Hide()
    b.active:Hide()
    b.tag:Hide()
    b.status:Show()
    b:SetAlpha(1)
    b.art:SetDesaturated(false)
    b.art:SetVertexColor(1, 1, 1)
    b.cover:SetVertexColor(1, 1, 1)
    b.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    b.level:SetText("")
end

-- ------------------------------------------------------------------ sidebar widgets
local function SideModeCreate(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(28)
    Skin.Box(b, 8)
    Skin.HoverGlow(b, 14, BLUE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("LEFT", 8, 0)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.label:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.label:SetJustifyH("LEFT")
    b.label:SetWordWrap(false)
    b:SetScript("OnClick", function(self) if self.onClick then self.onClick(self) end end)
    return b
end

local function SideEntryCreate(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(30)
    b.sel = b:CreateTexture(nil, "BORDER")
    b.sel:SetAllPoints()
    b.sel:SetTexture(Skin.MEDIA .. "Fade")
    b.sel:SetVertexColor(1, 0.75, 0.1, 0.35)
    b.selBar = b:CreateTexture(nil, "ARTWORK")
    b.selBar:SetPoint("TOPLEFT")
    b.selBar:SetPoint("BOTTOMLEFT")
    b.selBar:SetWidth(3)
    b.selBar:SetColorTexture(1, 0.82, 0, 1)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.name:SetPoint("TOPLEFT", 10, -5)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.lvl = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.lvl:SetPoint("TOPRIGHT", -6, -5)
    b.lvl:SetJustifyH("RIGHT")
    b.name:SetPoint("RIGHT", b.lvl, "LEFT", -4, 0)
    b.bar = Skin.ProgressBar(b, 3)
    b.bar:SetPoint("BOTTOMLEFT", 10, 6)
    b.bar:SetPoint("BOTTOMRIGHT", -6, 6)
    b.bar.text:Hide()
    b.here = b:CreateTexture(nil, "OVERLAY")
    b.here:SetSize(10, 10)
    b.here:SetPoint("TOPLEFT", 0, -6)
    Skin.SetIcon(b.here, "Waypoint-MapPin-ChatIcon", "Interface\\Minimap\\Tracking\\None")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(Skin.MEDIA .. "Fade")
    hl:SetVertexColor(BLUE[1], BLUE[2], BLUE[3], 0.35)
    hl:SetBlendMode("ADD")
    b:SetScript("OnClick", function(self) if self.onClick then self.onClick(self) end end)
    b:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function SideHeaderCreate(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(22)
    f.text = f:CreateFontString(nil, "OVERLAY", "ForeverQuestsFontTileSmall")
    f.text:SetPoint("BOTTOMLEFT", 6, 4)
    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetHeight(1)
    f.line:SetPoint("BOTTOMLEFT", 4, 0)
    f.line:SetPoint("BOTTOMRIGHT", -4, 0)
    f.line:SetColorTexture(1, 0.82, 0, 0.3)
    return f
end

-- ------------------------------------------------------------------ scroll area
local function CreateScroll(parent, dragPan)
    local s = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, s)
    child:SetSize(10, 10)
    s:SetScrollChild(child)
    s.child = child
    s:EnableMouseWheel(true)
    child:EnableMouse(true)

    local function maxV() return math.max(0, child:GetHeight() - s:GetHeight()) end
    local function maxH() return math.max(0, child:GetWidth() - s:GetWidth()) end

    local vbar = CreateFrame("Frame", nil, s)
    vbar:SetWidth(8)
    vbar:SetPoint("TOPRIGHT", s, "TOPRIGHT", -2, -2)
    vbar:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 2)
    vbar.bg = vbar:CreateTexture(nil, "BACKGROUND")
    vbar.bg:SetAllPoints()
    vbar.bg:SetColorTexture(0, 0, 0, 0.45)
    local vthumb = CreateFrame("Button", nil, vbar)
    vthumb:SetWidth(8)
    vthumb.t = vthumb:CreateTexture(nil, "ARTWORK")
    vthumb.t:SetAllPoints()
    vthumb.t:SetColorTexture(0.75, 0.6, 0.3, 0.7)
    vbar.thumb = vthumb

    local hbar = CreateFrame("Frame", nil, s)
    hbar:SetHeight(8)
    hbar:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 2, 2)
    hbar:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -12, 2)
    hbar.bg = hbar:CreateTexture(nil, "BACKGROUND")
    hbar.bg:SetAllPoints()
    hbar.bg:SetColorTexture(0, 0, 0, 0.45)
    local hthumb = CreateFrame("Button", nil, hbar)
    hthumb:SetHeight(8)
    hthumb.t = hthumb:CreateTexture(nil, "ARTWORK")
    hthumb.t:SetAllPoints()
    hthumb.t:SetColorTexture(0.75, 0.6, 0.3, 0.7)
    hbar.thumb = hthumb

    function s:UpdateBars()
        local mv, mh = maxV(), maxH()
        if mv > 1 then
            vbar:Show()
            local h = vbar:GetHeight()
            local th = math.max(24, h * s:GetHeight() / child:GetHeight())
            vthumb:SetHeight(th)
            vthumb:ClearAllPoints()
            vthumb:SetPoint("TOP", vbar, "TOP", 0, -((h - th) * (s:GetVerticalScroll() / mv)))
        else
            vbar:Hide()
        end
        if mh > 1 then
            hbar:Show()
            local w = hbar:GetWidth()
            local tw = math.max(24, w * s:GetWidth() / child:GetWidth())
            hthumb:SetWidth(tw)
            hthumb:ClearAllPoints()
            hthumb:SetPoint("LEFT", hbar, "LEFT", (w - tw) * (s:GetHorizontalScroll() / mh), 0)
        else
            hbar:Hide()
        end
    end

    function s:SetV(v)
        s:SetVerticalScroll(math.min(maxV(), math.max(0, v)))
        s:UpdateBars()
    end

    function s:SetH(v)
        s:SetHorizontalScroll(math.min(maxH(), math.max(0, v)))
        s:UpdateBars()
    end

    function s:SetContentSize(w, h)
        child:SetSize(math.max(1, w), math.max(1, h))
        s:SetV(s:GetVerticalScroll())
        s:SetH(s:GetHorizontalScroll())
    end

    s:SetScript("OnMouseWheel", function(_, delta)
        if IsShiftKeyDown() and maxH() > 0 then
            s:SetH(s:GetHorizontalScroll() - delta * 60)
        else
            s:SetV(s:GetVerticalScroll() - delta * 60)
        end
    end)
    s:SetScript("OnSizeChanged", function() s:UpdateBars() end)

    if dragPan then
        child:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            local x, y = GetCursorPosition()
            s.drag = { x = x, y = y, h = s:GetHorizontalScroll(), v = s:GetVerticalScroll() }
        end)
        child:SetScript("OnMouseUp", function() s.drag = nil end)
        child:SetScript("OnHide", function() s.drag = nil end)
        s:SetScript("OnUpdate", function()
            local d = s.drag
            if not d then return end
            if not IsMouseButtonDown("LeftButton") then s.drag = nil return end
            local x, y = GetCursorPosition()
            local scale = child:GetEffectiveScale()
            s:SetH(d.h - (x - d.x) / scale)
            s:SetV(d.v + (y - d.y) / scale)
        end)
    end

    local function thumbDrag(thumb, vertical)
        thumb:SetScript("OnMouseDown", function()
            local x, y = GetCursorPosition()
            thumb.drag = { x = x, y = y, h = s:GetHorizontalScroll(), v = s:GetVerticalScroll() }
        end)
        thumb:SetScript("OnMouseUp", function() thumb.drag = nil end)
        thumb:SetScript("OnUpdate", function()
            local d = thumb.drag
            if not d then return end
            if not IsMouseButtonDown("LeftButton") then thumb.drag = nil return end
            local x, y = GetCursorPosition()
            local scale = thumb:GetEffectiveScale()
            if vertical then
                local span = vbar:GetHeight() - thumb:GetHeight()
                if span > 0 then s:SetV(d.v + (d.y - y) / scale / span * maxV()) end
            else
                local span = hbar:GetWidth() - thumb:GetWidth()
                if span > 0 then s:SetH(d.h + (x - d.x) / scale / span * maxH()) end
            end
        end)
    end
    thumbDrag(vthumb, true)
    thumbDrag(hthumb, false)
    return s
end
UI.CreateScroll = CreateScroll

-- ------------------------------------------------------------------ modes
local MODES = {
    { key = "quest", label = "MODE_QUESTS", icon = "Interface\\GossipFrame\\AvailableQuestIcon", kinds = { 1, 2, 3 } },
    { key = "repeat", label = "MODE_REPEAT", icon = "Interface\\GossipFrame\\DailyQuestIcon", kinds = { 1, 2, 3, 4, 5, 6, 7, 8 }, repeatable = true },
    { key = "class", label = "MODE_CLASS", icon = "Interface\\Icons\\INV_Misc_Book_11", kinds = { 7 } },
    { key = "prof", label = "MODE_PROF", icon = "Interface\\Icons\\Trade_BlackSmithing", kinds = { 8 } },
    { key = "dungeon", label = "MODE_DUNGEON", icon = "Interface\\Icons\\INV_Misc_Key_14", kinds = { 4 } },
    { key = "bg", label = "MODE_BG", icon = "Interface\\Icons\\INV_BannerPVP_01", kinds = { 5 } },
    { key = "other", label = "MODE_OTHER", icon = "Interface\\Icons\\INV_Misc_QuestionMark", kinds = { 6 } },
}
local MODE_BY_KEY = {}
for _, m in ipairs(MODES) do MODE_BY_KEY[m.key] = m end
local GROUP_LABEL = { [1] = "KALIMDOR", [2] = "EASTERN", [3] = "NEWZONES" }

--- Chains and standalone quests of a category, in story order. Quests above the player's level
--- are hidden; if that leaves nothing, everything comes back flagged as a level-locked preview.
function UI:Content(cat)
    local m = ns.M[cat]
    if not m then return {}, {}, false, 0 end
    local hideDone = ns.db.hideDone
    local allChains, okChains, allSingles, okSingles = {}, {}, {}, {}
    for _, cid in ipairs(ns.ChainStoryOrder(m[5])) do
        local d, t, vis, best = ns.ChainStats(cid)
        if t > 0 and not (hideDone and best == ST.DONE) then
            local e = { cid = cid, d = d, t = t, best = best, vis = vis }
            allChains[#allChains + 1] = e
            if vis > 0 then okChains[#okChains + 1] = e end
        end
    end
    for _, id in ipairs(m[6]) do
        if ns.IsEligible(id) then
            local st = ns.Status(id)
            if st ~= ST.SKIPPED and not (hideDone and st == ST.DONE) then
                allSingles[#allSingles + 1] = id
                if ns.PassesLevel(id) then okSingles[#okSingles + 1] = id end
            end
        end
    end
    local chains, singles, fallback = okChains, okSingles, false
    if #okChains == 0 and #okSingles == 0 and (#allChains > 0 or #allSingles > 0) then
        chains, singles, fallback = allChains, allSingles, true
    end
    local minReq
    if fallback then
        local function consider(id)
            if ns.IsEligible(id) then
                local r = ns.Q[id][ns.F.REQ] or 0
                if not minReq or r < minReq then minReq = r end
            end
        end
        for _, e in ipairs(chains) do for _, id in ipairs(ns.C[e.cid][3]) do consider(id) end end
        for _, id in ipairs(singles) do consider(id) end
    end
    SortQuests(singles)
    return chains, singles, fallback, minReq or 0
end

--- done, total, available, started for a category (the tile and sidebar use these).
function UI:CatProgress(cat)
    local d, t, avail = ns.CatStats(cat)
    local started = d > 0 and d < t
    if not started and d < t then
        local m = ns.M[cat]
        for _, cid in ipairs(m[5]) do
            local _, _, _, best = ns.ChainStats(cid)
            if best == ST.ACTIVE or best == ST.READY then started = true break end
        end
    end
    return d, t, avail, started
end

-- ------------------------------------------------------------------ repeatable quests
--- Every repeatable quest (and craftsman's writ) by map, built once from the data.
local function RepeatIndex()
    if ns.repeatIndex then return ns.repeatIndex end
    local idx = {}
    for id in pairs(ns.Q) do
        if ns.IsRepeatable(id) then
            local cat = ns.Q[id][ns.F.CAT]
            if ns.M[cat] then
                idx[cat] = idx[cat] or {}
                table.insert(idx[cat], id)
            end
        end
    end
    ns.repeatIndex = idx
    return idx
end

--- Repeatable quests of a map you can take (level filter as everywhere else).
function UI:RepeatContent(cat)
    local all, ok = {}, {}
    for _, id in ipairs(RepeatIndex()[cat] or {}) do
        if ns.IsEligible(id, true) then
            all[#all + 1] = id
            if ns.PassesLevel(id) then ok[#ok + 1] = id end
        end
    end
    local list, fallback = ok, false
    if #ok == 0 and #all > 0 then list, fallback = all, true end
    SortQuests(list)
    return list, fallback
end

function UI:RepeatCats()
    local list = {}
    local myClass = select(3, UnitClass("player"))
    for cat in pairs(RepeatIndex()) do
        local m = ns.M[cat]
        local ok = not (m[1] == 7 and not ns.db.otherClass and myClass and ns.ClassOfCat(cat) ~= myClass)
        if ok then
            local ids, fallback = self:RepeatContent(cat)
            if #ids > 0 then
                local avail = 0
                for _, id in ipairs(ids) do
                    local st = ns.Status(id)
                    if st == ST.AVAILABLE or st == ST.DONE then avail = avail + 1 end
                end
                list[#list + 1] = { cat = cat, kind = m[1], lo = m[3], hi = m[4], fallback = fallback, count = #ids, avail = avail }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        if a.kind == 7 or a.kind == 8 then return ns.CatName(a.cat) < ns.CatName(b.cat) end
        if a.lo ~= b.lo then return a.lo < b.lo end
        return ns.CatName(a.cat) < ns.CatName(b.cat)
    end)
    return list
end

function UI:CatsForMode(mode)
    if mode == "repeat" then return self:RepeatCats() end
    local def = MODE_BY_KEY[mode]
    local kinds = {}
    for _, k in ipairs(def.kinds) do kinds[k] = true end
    local list = {}
    local myClass = select(3, UnitClass("player"))
    for cat, m in pairs(ns.M) do
        if kinds[m[1]] then
            local ok = true
            if m[1] == 7 and not ns.db.otherClass and myClass and ns.ClassOfCat(cat) ~= myClass then ok = false end
            if ok then
                local chains, singles, fallback = self:Content(cat)
                if #chains > 0 or #singles > 0 then
                    list[#list + 1] = { cat = cat, kind = m[1], lo = m[3], hi = m[4], fallback = fallback }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        if a.kind == 7 or a.kind == 8 then return ns.CatName(a.cat) < ns.CatName(b.cat) end
        if a.lo ~= b.lo then return a.lo < b.lo end
        return ns.CatName(a.cat) < ns.CatName(b.cat)
    end)
    return list
end

local function ModeForCat(cat)
    local k = ns.CatKind(cat)
    if k == 4 then return "dungeon" end
    if k == 5 then return "bg" end
    if k == 7 then return "class" end
    if k == 8 then return "prof" end
    if k == 6 then return "other" end
    return "quest"
end
UI.ModeForCat = ModeForCat

-- ------------------------------------------------------------------ main frame
local SIDEBAR_W = 214
local STORY_W = 340

local function NavButton(parent, kind)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    local files = {
        back = { "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled" },
        fwd = { "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled" },
    }
    local f = files[kind]
    if f then
        b:SetNormalTexture(f[1])
        b:SetPushedTexture(f[2])
        b:SetDisabledTexture(f[3])
    end
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    return b
end

function UI:Create()
    if self.frame then return end
    local f = TryCreate("Frame", "ForeverQuestsFrame", UIParent, "ButtonFrameTemplate")
    local native = f ~= nil
    if not f then
        f = CreateFrame("Frame", "ForeverQuestsFrame", UIParent, "BackdropTemplate")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        f.TitleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.TitleText:SetPoint("TOP", 0, -16)
    end
    self.frame = f
    f:SetSize(1220, 740)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(980, 560, 1900, 1250)
    elseif f.SetMinResize then
        f:SetMinResize(980, 560)
    end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.point = { p, rp, x, y }
    end)
    f:Hide()
    tinsert(UISpecialFrames, "ForeverQuestsFrame")

    if native then
        if f.SetTitle then pcall(f.SetTitle, f, L.TITLE) end
        local portrait = (f.PortraitContainer and f.PortraitContainer.portrait) or f.portrait
        if f.SetPortraitToAsset then
            pcall(f.SetPortraitToAsset, f, ICON)
        elseif portrait and SetPortraitToTexture then
            pcall(SetPortraitToTexture, portrait, ICON)
        end
    end
    if f.TitleText and (not native or not f.SetTitle) then f.TitleText:SetText(L.TITLE) end

    local inset = f.Inset
    if not inset then
        inset = CreateFrame("Frame", nil, f)
        f.Inset = inset
    end
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", f, "TOPLEFT", native and 4 or 14, native and -64 or -72)
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", native and -6 or -14, native and 24 or 30)
    local rock = inset:CreateTexture(nil, "BACKGROUND", nil, 1)
    rock:SetAllPoints()
    rock:SetTexture(Skin.ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetVertexColor(0.55, 0.55, 0.55)
    local shade = inset:CreateTexture(nil, "BACKGROUND", nil, 2)
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.35)

    -- top bar: back / forward / here, breadcrumbs, search, options
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", native and 58 or 20, native and -26 or -38)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, native and -26 or -38)
    bar:SetHeight(34)
    self.toolbar = bar

    local back = NavButton(bar, "back")
    back:SetPoint("LEFT", 0, 0)
    back:SetScript("OnClick", function() UI:Back() end)
    back:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.BACK_TT)
        GameTooltip:Show()
    end)
    back:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.backButton = back
    local fwd = NavButton(bar, "fwd")
    fwd:SetPoint("LEFT", back, "RIGHT", 0, 0)
    fwd:SetScript("OnClick", function() UI:Forward() end)
    fwd:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.FORWARD_TT)
        GameTooltip:Show()
    end)
    fwd:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.fwdButton = fwd
    local here = Skin.IconButton(bar, 22, "Waypoint-MapPin-ChatIcon", "Interface\\Icons\\INV_Misc_Map_01", function() return L.HERE_TT end)
    here:SetPoint("LEFT", fwd, "RIGHT", 2, 0)
    here:SetScript("OnClick", function() UI:OpenCurrentZone() end)
    self.hereButton = here

    -- breadcrumbs sit in a dark well, like the journal's navigation bar
    local nav = CreateFrame("Frame", nil, bar)
    nav:SetPoint("LEFT", here, "RIGHT", 8, 0)
    nav:SetHeight(32)
    local well = nav:CreateTexture(nil, "BACKGROUND")
    well:SetAllPoints()
    well:SetColorTexture(0, 0, 0, 0.55)
    self.nav = nav
    self.crumbs = {}
    for i = 1, 3 do
        local c = Skin.Crumb(nav)
        c:SetFrameLevel(nav:GetFrameLevel() + 10 - i)
        self.crumbs[i] = c
    end
    self.popup = Skin.Popup(f)

    local opt = Skin.IconButton(bar, 22, nil, "Interface\\WorldMap\\Gear_64Grey", function() return L.OPTIONS end)
    opt:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    opt:SetScript("OnClick", function() UI:ToggleOptions() end)
    self.optButton = opt

    local search = TryCreate("EditBox", "ForeverQuestsSearchBox", bar, "SearchBoxTemplate")
    if not search then
        search = CreateFrame("EditBox", "ForeverQuestsSearchBox", bar, "InputBoxTemplate")
    end
    search:SetSize(210, 22)
    search:SetAutoFocus(false)
    search:SetPoint("RIGHT", opt, "LEFT", -10, 0)
    if search.Instructions then search.Instructions:SetText(L.SEARCH) end
    search:HookScript("OnTextChanged", function(self, userInput)
        local t = self:GetText() or ""
        if not userInput and t ~= "" then return end
        if #t >= 2 then
            UI:Navigate({ mode = UI.state and UI.state.mode or "quest", cat = UI.state and UI.state.cat, search = t }, true)
        elseif UI.state and UI.state.search then
            UI:Back()
        end
    end)
    search:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
    self.search = search
    nav:SetPoint("RIGHT", search, "LEFT", -14, 0)

    -- sidebar
    local side = CreateFrame("Frame", nil, inset)
    side:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
    side:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 4, 4)
    side:SetWidth(SIDEBAR_W)
    Skin.Box(side, 12)
    side.fill:SetColor(0.03, 0.025, 0.02, 0.92)
    side.edge:SetColor(0.35, 0.3, 0.22, 1)
    self.side = side

    self.modeButtons = {}
    local y = -8
    for i, m in ipairs(MODES) do
        local b = SideModeCreate(side)
        b:SetPoint("TOPLEFT", side, "TOPLEFT", 8, y)
        b:SetPoint("TOPRIGHT", side, "TOPRIGHT", -8, y)
        b.mode = m.key
        b.label:SetText(L[m.label])
        Skin.SetIcon(b.icon, nil, m.icon)
        b.onClick = function() UI:SelectMode(m.key) end
        self.modeButtons[i] = b
        y = y - 30
    end
    local _, classFile = UnitClass("player")
    if classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
        local cb = self.modeButtons[2]
        cb.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        local c = CLASS_ICON_TCOORDS[classFile]
        cb.icon:SetTexCoord(c[1], c[2], c[3], c[4])
    end
    local sideScroll = CreateScroll(side)
    sideScroll:SetPoint("TOPLEFT", side, "TOPLEFT", 6, y - 6)
    sideScroll:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -6, 8)
    self.sideScroll = sideScroll

    -- main area
    local main = CreateFrame("Frame", nil, inset)
    main:SetPoint("TOPLEFT", side, "TOPRIGHT", 6, 0)
    main:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -4, 4)
    self.main = main

    local head = CreateFrame("Frame", nil, main)
    head:SetPoint("TOPLEFT", 8, -6)
    head:SetPoint("TOPRIGHT", -8, -6)
    head:SetHeight(50)
    head.title = head:CreateFontString(nil, "OVERLAY", "ForeverQuestsFontTitle")
    head.title:SetPoint("TOPLEFT", 2, -2)
    head.title:SetPoint("RIGHT", head, "RIGHT", -260, 0)
    head.title:SetJustifyH("LEFT")
    head.title:SetWordWrap(false)
    head.sub = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    head.sub:SetPoint("TOPLEFT", head.title, "BOTTOMLEFT", 0, -3)
    head.sub:SetJustifyH("LEFT")
    head.sub:SetWordWrap(false)
    head.bar = Skin.ProgressBar(head, 8)
    head.bar:SetPoint("LEFT", head.sub, "RIGHT", 12, 0)
    head.bar:SetWidth(150)
    head.bar.text:SetFontObject("GameFontHighlightSmall")
    head.bar.text:ClearAllPoints()
    head.bar.text:SetPoint("LEFT", head.bar, "RIGHT", 6, 0)

    local mapBtn = PanelButton(head, L.OPEN_MAP, 110, 22)
    mapBtn:SetPoint("TOPRIGHT", 0, -2)
    mapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(L.OPEN_MAP_TT)
        GameTooltip:Show()
    end)
    mapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mapBtn:SetScript("OnClick", function() if UI.mapTarget then ns.OpenMapTo(UI.mapTarget) end end)
    head.mapBtn = mapBtn
    local storyBtn = PanelButton(head, L.VIEW_STORY, 110, 22)
    storyBtn:SetPoint("RIGHT", mapBtn, "LEFT", -6, 0)
    storyBtn:SetScript("OnClick", function()
        ns.db.storyPanel = not ns.db.storyPanel
        UI:Refresh()
    end)
    storyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(L.VIEW_STORY_TT)
        GameTooltip:Show()
    end)
    storyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    head.storyBtn = storyBtn
    local sep = head:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", 0, -2)
    sep:SetPoint("BOTTOMRIGHT", 0, -2)
    sep:SetColorTexture(1, 0.82, 0, 0.35)
    self.head = head

    local banner = CreateFrame("Frame", nil, main)
    banner:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
    banner:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -10)
    banner:SetHeight(34)
    Skin.Box(banner, 10)
    banner.fill:SetColor(0.3, 0.04, 0.04, 0.9)
    banner.edge:SetColor(0.7, 0.2, 0.15, 1)
    banner.icon = banner:CreateTexture(nil, "ARTWORK")
    banner.icon:SetSize(20, 20)
    banner.icon:SetPoint("LEFT", 10, 0)
    Skin.SetIcon(banner.icon, "services-icon-warning", "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    banner.text:SetPoint("LEFT", banner.icon, "RIGHT", 8, 0)
    banner.text:SetPoint("RIGHT", banner, "RIGHT", -10, 0)
    banner.text:SetJustifyH("LEFT")
    banner:Hide()
    self.banner = banner

    -- the story panel lives on the right of the main area (chain pages only)
    self.story = ns.Story:Create(main, STORY_W)

    local scroll = CreateScroll(main, true)
    self.scroll = scroll
    self.canvas = scroll.child
    self:LayoutScroll(false, false)

    local foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 7)
    foot:SetPoint("RIGHT", f, "RIGHT", -40, 0)
    foot:SetJustifyH("LEFT")
    self.footer = foot

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        ns.db.size = { f:GetWidth(), f:GetHeight() }
        local p, _, rp, x, y = f:GetPoint()
        ns.db.point = { p, rp, x, y }
        UI:Refresh()
    end)
    f:HookScript("OnSizeChanged", function()
        if UI.resizeTimer then return end
        UI.resizeTimer = true
        C_Timer.After(0.15, function()
            UI.resizeTimer = nil
            if f:IsShown() then UI:Refresh() end
        end)
    end)
    f:HookScript("OnShow", function() ns:UpdatePlayer(); ns:InvalidateStatus(); UI:Refresh() end)
    f:HookScript("OnHide", function()
        if UI.options then UI.options:Hide() end
        UI.popup:Hide()
    end)

    self.tiles = NewPool(TileCreate)
    self.rows = NewPool(RowCreate)
    self.nodes = NewPool(NodeCreate)
    self.seps = NewPool(SeparatorCreate)
    self.texts = NewPool(TextCreate)
    self.bridgeRows = NewPool(BridgeRowCreate)
    self.sideEntries = NewPool(SideEntryCreate)
    self.sideHeaders = NewPool(SideHeaderCreate)
    self.lines = { free = {}, used = {} }
    self.lastCat = {}
    self.history = {}
    self.future = {}

    self:CreateLoreBox()
    self:ResetPosition(true)
end

--- The zone story box at the top of a map page: one compact panel that can be folded away.
function UI:CreateLoreBox()
    local box = CreateFrame("Frame", nil, self.canvas)
    Skin.Box(box, 12)
    box.fill:SetColor(0.07, 0.055, 0.035, 0.94)
    box.edge:SetColor(0.45, 0.36, 0.2, 1)
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.icon:SetSize(18, 18)
    box.icon:SetPoint("TOPLEFT", 12, -9)
    Skin.SetIcon(box.icon, nil, "Interface\\Icons\\INV_Misc_Book_09")
    box.title = box:CreateFontString(nil, "OVERLAY", "ForeverQuestsFontTileSmall")
    box.title:SetPoint("LEFT", box.icon, "RIGHT", 6, 0)
    box.toggle = CreateFrame("Button", nil, box)
    box.toggle:SetSize(20, 20)
    box.toggle:SetPoint("TOPRIGHT", -8, -7)
    box.toggle.text = box.toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    box.toggle.text:SetAllPoints()
    box.toggle:SetScript("OnClick", function()
        ns.db.loreCollapsed = not ns.db.loreCollapsed
        UI:Refresh()
    end)
    box.speak = ns.Speech:Button(box, 18, function()
        local item = ns.Story:ZoneItem(box.loreCat)
        if item then return { item }, item.label end
    end)
    box.speak:SetPoint("RIGHT", box.toggle, "LEFT", -6, 0)
    box.body = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    box.body:SetPoint("TOPLEFT", box.icon, "BOTTOMLEFT", 0, -6)
    box.body:SetJustifyH("LEFT")
    box.body:SetJustifyV("TOP")
    box.body:SetWordWrap(true)
    box.body:SetSpacing(2)
    box.body:SetTextColor(0.92, 0.88, 0.78)
    box:Hide()
    self.loreBox = box
end

function UI:AddLore(y, title, text)
    local box = self.loreBox
    if not text or text == "" then
        box:Hide()
        return y
    end
    local w = self:ViewWidth() - 8
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", 4, -y)
    box:SetWidth(w)
    box.title:SetText(title)
    box.loreText = text
    box.toggle.text:SetText(ns.db.loreCollapsed and "+" or "-")
    box:Show()
    if ns.db.loreCollapsed then
        box.body:Hide()
        box:SetHeight(34)
        return y + 42
    end
    box.body:Show()
    box.body:SetWidth(w - 28)
    box.body:SetText(text)
    local h = (box.body:GetStringHeight() or 0)
    if h < 10 then h = 40 end
    box:SetHeight(h + 46)
    return y + h + 54
end

function UI:ApplyLanguage()
    if not self.frame then return end
    local f = self.frame
    if f.SetTitle then pcall(f.SetTitle, f, L.TITLE) end
    if f.TitleText then f.TitleText:SetText(L.TITLE) end
    self.head.mapBtn:SetText(L.OPEN_MAP)
    self.head.storyBtn:SetText(L.VIEW_STORY)
    if self.search and self.search.Instructions then self.search.Instructions:SetText(L.SEARCH) end
    for i, b in ipairs(self.modeButtons) do b.label:SetText(L[MODES[i].label]) end
    for _, r in ipairs(self.rows.free) do r.chainBtn:SetText(L.CHAIN_BTN) end
    for _, r in ipairs(self.rows.used) do r.chainBtn:SetText(L.CHAIN_BTN) end
    self:UpdateOptions()
    self.story:ApplyLanguage()
    ns.ClearNameCaches()
end

--- Places the scroll area under the header (and the warning banner), next to the story panel.
function UI:LayoutScroll(withBanner, withStory)
    local s = self.scroll
    s:ClearAllPoints()
    local top = withBanner and self.banner or self.head
    s:SetPoint("TOPLEFT", top, "BOTTOMLEFT", -4, withBanner and -8 or -10)
    if withStory then
        self.story.frame:ClearAllPoints()
        self.story.frame:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 4, withBanner and -8 or -10)
        self.story.frame:SetPoint("BOTTOMRIGHT", self.main, "BOTTOMRIGHT", 0, 0)
        self.story.frame:Show()
        s:SetPoint("BOTTOMRIGHT", self.story.frame, "BOTTOMLEFT", -6, 0)
    else
        self.story.frame:Hide()
        s:SetPoint("BOTTOMRIGHT", self.main, "BOTTOMRIGHT", 0, 0)
    end
end

function UI:ShowBanner(text)
    if text then
        self.banner.text:SetText(text)
        self.banner:Show()
    else
        self.banner:Hide()
    end
    self.withBanner = text ~= nil
end

function UI:ResetPosition(fromSaved)
    local f = self.frame
    if not f then return end
    f:ClearAllPoints()
    local db = ns.db
    if fromSaved and db.size then f:SetSize(db.size[1], db.size[2]) else f:SetSize(1220, 740) end
    if fromSaved and db.point then
        f:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
end

-- ------------------------------------------------------------------ options
function UI:ToggleOptions()
    if not self.options then
        local o = CreateFrame("Frame", nil, self.frame)
        Skin.Box(o, 12)
        o.fill:SetColor(0.05, 0.04, 0.03, 0.97)
        o.edge:SetColor(0.6, 0.5, 0.3, 1)
        o:SetFrameStrata("DIALOG")
        o:SetPoint("TOPRIGHT", self.optButton, "BOTTOMRIGHT", 0, -6)
        o:EnableMouse(true)
        local W = 250
        o:SetWidth(W)
        local items = {
            { "spoilerFree", "OPT_SPOILER" },
            { "showHigher", "OPT_SHOW_HIGHER" },
            { "hideDone", "OPT_HIDE_DONE" },
            { "showRepeat", "OPT_REPEAT" },
            { "otherClass", "OPT_OTHERCLASS" },
            { "otherRace", "OPT_OTHERRACE" },
            { "storyPanel", "OPT_STORY_PANEL" },
            { "openZone", "OPT_OPENZONE" },
            { "tomtom", "OPT_TOMTOM" },
            { "mapButton", "OPT_MAPBUTTON" },
            { "minimap", "OPT_MINIMAP" },
        }
        o.checks = {}
        local y = -10
        for _, it in ipairs(items) do
            local c = TryCreate("CheckButton", nil, o, "UICheckButtonTemplate") or CreateFrame("CheckButton", nil, o)
            c:SetSize(20, 20)
            c:SetPoint("TOPLEFT", 10, y)
            if c.Text then c.Text:SetText("") end
            if c.text then c.text:SetText("") end
            c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            c.label:SetPoint("LEFT", c, "RIGHT", 4, 0)
            c.label:SetWidth(W - 44)
            c.label:SetJustifyH("LEFT")
            c.label:SetWordWrap(false)
            c.lkey = it[2]
            c.label:SetText(L[it[2]])
            c.key = it[1]
            c:SetScript("OnClick", function(self)
                ns.db[self.key] = self:GetChecked() and true or false
                ns:InvalidateStatus()
                if self.key == "mapButton" then UI:SetupMapButton() end
                if self.key == "minimap" then UI:SetupMinimapButton() end
                UI:Refresh()
            end)
            o.checks[#o.checks + 1] = c
            y = y - 21
        end
        y = y - 8
        -- buttons fill the box width; their text is small and never wider than the button
        local function button(onClick)
            local b = PanelButton(o, "", W - 24, 20)
            b:SetPoint("TOPLEFT", 12, y)
            local fs = b:GetFontString()
            if fs then
                fs:SetFontObject("GameFontNormalSmall")
                fs:SetWidth(W - 40)
                fs:SetWordWrap(false)
            end
            b:SetScript("OnClick", onClick)
            y = y - 23
            return b
        end
        o.langButton = button(function()
            local order = { auto = "ptBR", ptBR = "enUS", enUS = "auto" }
            ns.db.lang = order[ns.db.lang or "auto"] or "auto"
            ns.ApplyLanguage()
            UI:ApplyLanguage()
            UI:Refresh()
            UI:UpdateOptions()
        end)
        o.unignore = button(function()
            ns.db.ignored = {}
            UI:Refresh()
        end)
        o.updateButton = button(function()
            o:Hide()
            UI:ShowUpdate()
        end)
        o.resetButton = button(function()
            ns.db.point, ns.db.size = nil, nil
            UI:ResetPosition()
        end)
        o:SetHeight(-y + 8)
        o:Hide()
        self.options = o
    end
    self:UpdateOptions()
    self.options:SetShown(not self.options:IsShown())
end

--- The game does not let addons download or write files, so updating happens outside it:
--- this window explains how and offers the /reload afterwards.
function UI:ShowUpdate()
    if not self.update then
        local u = CreateFrame("Frame", nil, self.frame)
        u:SetFrameStrata("DIALOG")
        u:SetSize(400, 280)
        u:SetPoint("CENTER", self.frame, "CENTER", 0, 40)
        u:EnableMouse(true)
        Skin.Box(u, 12)
        u.fill:SetColor(0.05, 0.04, 0.03, 0.98)
        u.edge:SetColor(0.7, 0.55, 0.25, 1)
        u.title = u:CreateFontString(nil, "OVERLAY", "ForeverQuestsFontSection")
        u.title:SetPoint("TOPLEFT", 14, -12)
        u.version = u:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        u.version:SetPoint("LEFT", u.title, "RIGHT", 8, -1)
        local close = Skin.IconButton(u, 16, nil, "Interface\\Buttons\\UI-StopButton", function() return CLOSE or "Close" end)
        close:SetPoint("TOPRIGHT", -10, -12)
        close:SetScript("OnClick", function() u:Hide() end)
        u.body = u:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        u.body:SetPoint("TOPLEFT", 14, -40)
        u.body:SetPoint("RIGHT", u, "RIGHT", -14, 0)
        u.body:SetJustifyH("LEFT")
        u.body:SetJustifyV("TOP")
        u.body:SetSpacing(3)
        u.link = CreateFrame("EditBox", nil, u, "InputBoxTemplate")
        u.link:SetSize(340, 20)
        u.link:SetPoint("BOTTOMLEFT", 22, 44)
        u.link:SetAutoFocus(false)
        u.link:SetFontObject("GameFontHighlightSmall")
        u.link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        u.link:SetScript("OnTextChanged", function(self) self:SetText(ns.REPO_URL) end)
        u.link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        u.reload = PanelButton(u, "", 170, 22)
        u.reload:SetPoint("BOTTOMLEFT", 14, 12)
        u.reload:SetScript("OnClick", function() ReloadUI() end)
        u.ok = PanelButton(u, "", 170, 22)
        u.ok:SetPoint("BOTTOMRIGHT", -14, 12)
        u.ok:SetScript("OnClick", function() u:Hide() end)
        self.update = u
    end
    local u = self.update
    u.title:SetText(L.UPDATE_TITLE)
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("ForeverQuests", "Version")
        or (GetAddOnMetadata and GetAddOnMetadata("ForeverQuests", "Version")) or "?"
    u.version:SetText(L.UPDATE_VERSION:format(version))
    u.body:SetText(L.UPDATE_BODY)
    u.link:SetText(ns.REPO_URL)
    u.reload:SetText(L.UPDATE_RELOAD)
    u.ok:SetText(OKAY or "OK")
    u:Show()
end

function UI:UpdateOptions()
    local o = self.options
    if not o then return end
    for _, c in ipairs(o.checks) do
        c:SetChecked(ns.db[c.key] and true or false)
        c.label:SetText(L[c.lkey])
    end
    local names = { auto = L.OPT_LANG_AUTO, ptBR = L.OPT_LANG_PT, enUS = L.OPT_LANG_EN }
    o.langButton:SetText(L.OPT_LANG .. ": " .. (names[ns.db.lang or "auto"] or names.auto))
    o.unignore:SetText(L.OPT_UNIGNORE_ALL)
    o.resetButton:SetText(L.OPT_RESET)
    o.updateButton:SetText(L.OPT_UPDATE)
end

-- ------------------------------------------------------------------ world map + minimap buttons
function UI:SetupMapButton()
    if not WorldMapFrame then return end
    if not self.mapButton then
        local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
        local b = CreateFrame("Button", "ForeverQuestsMapButton", parent)
        b:SetSize(32, 32)
        b:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8)
        b:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 3, -3)
        b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        b.icon:SetTexture(ICON)
        b.border = b:CreateTexture(nil, "OVERLAY")
        b.border:SetAllPoints()
        b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        b.border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnClick", function()
            local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
            local cat = mapID and ns.CategoryForMap(mapID)
            UI:Show()
            if cat then UI:OpenCategory(cat) end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.TITLE)
            GameTooltip:AddLine(L.MAP_BUTTON_TT, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.mapButton = b
    end
    self.mapButton:SetShown(ns.db.mapButton and true or false)
end

local function MinimapPos(b)
    local angle = math.rad(ns.db.minimapAngle or 215)
    local r = (Minimap:GetWidth() or 140) / 2 + 10
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(angle), r * math.sin(angle))
end

function UI:SetupMinimapButton()
    if not Minimap then return end
    if not self.minimapButton then
        local b = CreateFrame("Button", "ForeverQuestsMinimapButton", Minimap)
        b:SetSize(31, 31)
        b:SetFrameStrata("MEDIUM")
        b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b:SetMovable(true)
        local icon = b:CreateTexture(nil, "BACKGROUND")
        icon:SetSize(20, 20)
        icon:SetPoint("CENTER", 0, 0)
        icon:SetTexture(ICON)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.icon = icon
        local border = b:CreateTexture(nil, "OVERLAY")
        border:SetSize(53, 53)
        border:SetPoint("TOPLEFT", 0, 0)
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        b:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                UI:Show()
                UI:OpenCurrentZone()
            else
                UI:Toggle()
            end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(L.TITLE)
            GameTooltip:AddLine(L.MINIMAP_TT, 1, 1, 1)
            GameTooltip:AddLine(L.MINIMAP_TT2, 1, 1, 1)
            GameTooltip:AddLine(L.MINIMAP_DRAG, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnDragStart", function(self) self.dragging = true end)
        b:SetScript("OnDragStop", function(self) self.dragging = false end)
        b:SetScript("OnUpdate", function(self)
            if not self.dragging then return end
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            ns.db.minimapAngle = math.deg(math.atan2(py - my, px - mx))
            MinimapPos(self)
        end)
        self.minimapButton = b
    end
    MinimapPos(self.minimapButton)
    self.minimapButton:SetShown(ns.db.minimap ~= false)
end

-- ------------------------------------------------------------------ navigation
function UI:Show()
    self:Create()
    if not self.state then
        local cur = ns.db.openZone and ns.CurrentCategory() or nil
        if cur then
            self.state = { mode = ModeForCat(cur), cat = cur }
        else
            self.state = { mode = "quest", home = true }
        end
    end
    self.frame:Show()
end

function UI:Toggle()
    self:Create()
    if self.frame:IsShown() then self.frame:Hide() else self:Show() end
end

function UI:OpenCurrentZone()
    self:Create()
    local cur = ns.CurrentCategory()
    if cur then self:OpenCategory(cur) end
end

function UI:OpenCategory(cat)
    self:Navigate({ mode = ModeForCat(cat), cat = cat })
end

function UI:OpenChain(cid, focus)
    local cat = ns.C[cid][1]
    self:Navigate({ mode = ModeForCat(cat), cat = cat, cid = cid, focus = focus })
end

--- A mode button opens that mode's home: every map of it as a tile.
function UI:SelectMode(mode)
    self:Navigate({ mode = mode, home = true })
end

function UI:GoHome()
    self:Navigate({ mode = (self.state and self.state.mode) or "quest", home = true })
end

function UI:Navigate(state, replaceSearch)
    if self.state and not (replaceSearch and self.state.search) then
        self.history[#self.history + 1] = self.state
        if #self.history > 50 then table.remove(self.history, 1) end
    end
    self.future = {}
    if not state.search and self.search and self.search:GetText() ~= "" then
        self.search:SetText("")
        self.search:ClearFocus()
    end
    self.state = state
    if state.cat and state.mode then self.lastCat[state.mode] = state.cat end
    self.popup:Hide()
    self.scroll:SetV(0)
    self.scroll:SetH(0)
    self:Refresh()
end

function UI:Back()
    local prev = table.remove(self.history)
    if not prev then return end
    self.future[#self.future + 1] = self.state
    if not prev.search and self.search and self.search:GetText() ~= "" then self.search:SetText("") end
    self.state = prev
    self:Refresh()
end

function UI:Forward()
    local nxt = table.remove(self.future)
    if not nxt then return end
    self.history[#self.history + 1] = self.state
    self.state = nxt
    self:Refresh()
end

--- Breadcrumbs: Home > Map v > Chain v. The arrow opens the list of the other maps / chains.
function UI:SetCrumbs(list)
    self.backButton:SetEnabled(#self.history > 0)
    self.fwdButton:SetEnabled(#self.future > 0)
    local x = 0
    for i, c in ipairs(self.crumbs) do
        local it = list[i]
        if it then
            c.text:SetText(it.text)
            c:SetHome(i == 1)
            c:ClearAllPoints()
            c:SetPoint("LEFT", self.nav, "LEFT", x, 0)
            local w = c:Fit(it.menu ~= nil)
            c.onClick = it.onClick
            c.onMenu = it.menu and function(btn) UI.popup:Open(btn, it.menu()) end or nil
            c:Show()
            x = x + w + 18
        else
            c:Hide()
        end
    end
end

-- ------------------------------------------------------------------ render helpers
function UI:Clear()
    ReleaseAll(self.tiles)
    ReleaseAll(self.rows)
    ReleaseAll(self.nodes)
    ReleaseAll(self.seps)
    ReleaseAll(self.texts)
    ReleaseAll(self.bridgeRows)
    self.loreBox:Hide()
    for i = #self.lines.used, 1, -1 do
        local l = self.lines.used[i]
        l:Hide()
        self.lines.free[#self.lines.free + 1] = l
        self.lines.used[i] = nil
    end
end

local LINE_BG = "Interface/Artifacts/_Artifacts-DependencyBar-BG"
local LINE_FILL = "Interface/Artifacts/_Artifacts-DependencyBar-Fill"

function UI:Line()
    local l = table.remove(self.lines.free)
    if not l then l = self.canvas:CreateLine(nil, "BACKGROUND") end
    l:Show()
    self.lines.used[#self.lines.used + 1] = l
    return l
end

--- One connection of the tree: a dark groove, filled green once the earlier quest is done.
function UI:Connect(a, b, state, dotted)
    local groove = self:Line()
    local ok = pcall(groove.SetTexture, groove, LINE_BG, "REPEAT")
    if not ok then groove:SetColorTexture(0.15, 0.13, 0.1, 0.9) end
    groove:SetVertexColor(1, 1, 1, dotted and 0.5 or 1)
    groove:SetThickness(dotted and 7 or 11)
    groove:SetStartPoint("BOTTOM", a, 0, 6)
    groove:SetEndPoint("TOP", b, 0, -6)
    if state then
        local fill = self:Line()
        local ok2 = pcall(fill.SetTexture, fill, LINE_FILL, "REPEAT")
        if not ok2 then fill:SetColorTexture(1, 1, 1, 1) end
        fill:SetThickness(dotted and 7 or 11)
        fill:SetStartPoint("BOTTOM", a, 0, 6)
        fill:SetEndPoint("TOP", b, 0, -6)
        local c = (state == "done" and GREEN) or (state == "link" and PURPLE) or (state == "bridge" and BRIDGE) or { 1, 0.6, 0 }
        fill:SetVertexColor(c[1], c[2], c[3], 1)
    end
end

function UI:ViewWidth()
    return math.max(300, (self.scroll:GetWidth() or 800) - 16)
end

function UI:AddSeparator(y, text, count, key)
    local s = Acquire(self.seps, self.canvas)
    s:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", 4, -y)
    s:SetWidth(self:ViewWidth() - 6)
    s.text:SetText(text)
    local collapsed = key and ns.db.collapsed and ns.db.collapsed[key]
    s.count:SetText((count or "") .. (key and (collapsed and "  [+]" or "  [-]") or ""))
    s.onClick = key and function()
        ns.db.collapsed = ns.db.collapsed or {}
        ns.db.collapsed[key] = not ns.db.collapsed[key] or nil
        UI:Refresh()
    end or nil
    return y + 32, collapsed
end

function UI:AddMessage(y, text, width)
    local t = Acquire(self.texts, self.canvas)
    t:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", 8, -y)
    local w = (width or self:ViewWidth()) - 16
    t:SetSize(w, 20)
    t.text:SetWidth(w)
    t.text:SetText(text)
    local h = t.text:GetStringHeight() or 20
    if h < 14 then h = 20 end
    t:SetHeight(h)
    return y + h + 10
end

local function QuestTagText(id)
    local q = ns.Q[id]
    local flags = q[ns.F.FLAGS] or 0
    if ns.BridgeTo(id) then return Color(L.BRIDGE_TAG, BRIDGE) end
    if bit.band(flags, ns.FLAG_REPEAT) ~= 0 then return L.TAG_REPEAT end
    if bit.band(flags, ns.FLAG_ITEM) ~= 0 then return L.TAG_ITEM end
    if bit.band(flags, ns.FLAG_NEW) ~= 0 then return Color(L.TAG_FOREVER_SHORT, PURPLE) end
    return ""
end

function UI:AddQuestRow(y, id, opts)
    opts = opts or {}
    local r = Acquire(self.rows, self.canvas)
    r:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", 6, -y)
    r:SetWidth(self:ViewWidth() - 10)
    local st = ns.Status(id)
    local q = ns.Q[id]
    SetStatusIcon(r.icon, st, q[ns.F.FLAGS])
    local c = STATUS_COLOR[st]
    r.name:SetText(ns.QName(id))
    if st == ST.DONE then
        r.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    elseif st == ST.AVAILABLE or st == ST.READY or st == ST.ACTIVE then
        r.name:SetTextColor(1, 1, 1)
    else
        r.name:SetTextColor(c[1], c[2], c[3])
    end
    r.check:SetShown(st == ST.DONE)
    r.icon:SetShown(st ~= ST.DONE)
    -- green border while it is in your log, grey otherwise (done ones sit under "Completed")
    if st == ST.ACTIVE or st == ST.READY then
        r.edge:SetColor(GREEN[1], GREEN[2], GREEN[3], 1)
    else
        r.edge:SetColor(GREY[1], GREY[2], GREY[3], 1)
    end
    r.level:SetText(("[%d]"):format(q[ns.F.LVL] or 0))
    local lvlc = (q[ns.F.REQ] or 0) > ns.player.level and RED or GOLD
    r.level:SetTextColor(lvlc[1], lvlc[2], lvlc[3])
    local right = opts.showPlace and QuestPlace(id) or QuestTagText(id)
    if st == ST.LEVEL then right = Color(L.ST_LEVEL:format(q[ns.F.REQ] or 0), RED) end
    if st == ST.ACTIVE or st == ST.READY then right = Color(STATUS_TEXT[st](id), GOLD) end
    r.right:SetText(right)
    local cid = q[ns.F.CHAIN]
    if opts.chainButton and cid then
        r.chainBtn:Show()
        r.onChain = function() UI:OpenChain(cid, id) end
    else
        r.chainBtn:Hide()
        r.onChain = nil
    end
    r.onClick = function(_, button) UI:QuestClick(id, button, true) end
    r.onEnter = function(self) UI:QuestTooltip(self, id, { rightOpensChain = opts.chainButton }) end
    return y + 32
end

-- ------------------------------------------------------------------ refresh
function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    local state = self.state
    if not state then
        state = { mode = "quest", home = true }
        self.state = state
    end
    self:Clear()
    local v = self.scroll:GetVerticalScroll()
    local h = self.scroll:GetHorizontalScroll()
    self:RenderSidebar()
    self:ShowBanner(nil)
    self.head.storyBtn:Hide()
    self.head.bar:Hide()
    local story = false
    if state.search then
        self:RenderSearch(state.search)
    elseif state.cid and ns.C[state.cid] then
        story = ns.db.storyPanel and true or false
        self:RenderChain(state.cid)
    elseif state.single and ns.Q[state.single] then
        story = ns.db.storyPanel and true or false
        self:RenderSingle(state.single)
    elseif state.cat and ns.M[state.cat] then
        self:RenderCategory(state.cat)
    else
        self:RenderHome(state.mode or "quest")
    end
    self:LayoutScroll(self.withBanner, story)
    self.scroll:SetV(v)
    self.scroll:SetH(h)

    local p = ns.player
    local className = UnitClass("player")
    self.footer:SetText((UnitName("player") or "") .. "  ·  " .. (LEVEL or "Level") .. " " .. p.level ..
        (className and ("  ·  " .. className) or "") .. ((TomTom and ns.db.tomtom) and "  ·  TomTom" or ""))
end

function UI:RenderSidebar()
    local state = self.state
    for _, b in ipairs(self.modeButtons) do
        if b.mode == state.mode then
            b.fill:SetColor(0.32, 0.22, 0.05, 0.95)
            b.edge:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
            b.label:SetTextColor(1, 1, 1)
        else
            b.fill:SetColor(0, 0, 0, 0.85)
            b.edge:SetColor(GREY[1], GREY[2], GREY[3], 1)
            b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        end
    end

    ReleaseAll(self.sideEntries)
    ReleaseAll(self.sideHeaders)
    local list = self:CatsForMode(state.mode)
    local canvas = self.sideScroll.child
    local w = math.max(100, (self.sideScroll:GetWidth() or (SIDEBAR_W - 12)) - 12)
    local current = ns.CurrentCategory()
    -- maps you have finished go to the end, under "Completed"
    local open, done = {}, {}
    local rep = state.mode == "repeat"
    for _, e in ipairs(list) do
        if rep then
            e.d, e.t, e.started = 0, e.count, false
            open[#open + 1] = e
        else
            local d, t, _, started = self:CatProgress(e.cat)
            e.d, e.t, e.started = d, t, started
            if t > 0 and d >= t then done[#done + 1] = e else open[#open + 1] = e end
        end
    end
    local y, lastGroup = 2, nil
    local function header(text)
        local hd = Acquire(self.sideHeaders, canvas)
        hd:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -y)
        hd:SetWidth(w)
        hd.text:SetText(text)
        y = y + 24
    end
    local function entry(e)
        local b = Acquire(self.sideEntries, canvas)
        b:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -y)
        b:SetWidth(w)
        local name = ns.CatName(e.cat)
        b.name:SetText(name)
        local selected = (e.cat == state.cat) and not state.search
        b.sel:SetShown(selected)
        b.selBar:SetShown(selected)
        b.here:SetShown(e.cat == current)
        if rep then
            b.lvl:SetText(L.REPEAT_N:format(e.count))
        elseif e.kind == 7 or e.kind == 8 then
            b.lvl:SetText(("%d/%d"):format(e.d, e.t))
        else
            b.lvl:SetText(LevelText(e.lo, e.hi))
        end
        b.bar:SetShown(not rep)
        b.bar:SetProgress(e.d, e.t)
        if e.fallback and not ns.db.showHigher then
            b.name:SetTextColor(RED[1], RED[2], RED[3])
            b.lvl:SetTextColor(RED[1], RED[2], RED[3])
        else
            b.name:SetTextColor(1, 1, 1)
            b.lvl:SetTextColor(0.75, 0.7, 0.6)
        end
        b.onClick = function() UI:Navigate({ mode = state.mode, cat = e.cat }) end
        b.onEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(name, 1, 1, 1)
            GameTooltip:AddLine(LevelText(e.lo, e.hi), GOLD[1], GOLD[2], GOLD[3])
            if rep then
                GameTooltip:AddLine(L.REPEAT_N:format(e.count), 0.6, 0.8, 1)
            else
                GameTooltip:AddLine(L.PROGRESS:format(e.d, e.t), 0.8, 0.8, 0.8)
            end
            if e.cat == current then GameTooltip:AddLine(L.YOU_ARE_HERE, GREEN[1], GREEN[2], GREEN[3]) end
            GameTooltip:Show()
        end
        y = y + 31
    end
    for _, e in ipairs(open) do
        local group = GROUP_LABEL[e.kind]
        if group and group ~= lastGroup then
            lastGroup = group
            header(L[group])
        end
        entry(e)
    end
    if #done > 0 then
        header(L.COMPLETED_SEP)
        for _, e in ipairs(done) do entry(e) end
    end
    self.sideScroll:SetContentSize(w, y + 4)
end

function UI:SetMapTarget(cat)
    local m = cat and ns.M[cat]
    local target
    if cat and cat > 0 and cat < 800000 then target = cat elseif cat and cat < 0 and m then target = m[9] end
    self.mapTarget = target
    self.head.mapBtn:SetShown(target ~= nil)
end

--- Lists for the crumb arrows.
function UI:MapMenu(mode, selected)
    local items = {}
    for _, e in ipairs(self:CatsForMode(mode)) do
        local cat = e.cat
        items[#items + 1] = {
            text = ns.CatName(cat), right = LevelText(e.lo, e.hi), selected = cat == selected,
            onClick = function() UI:Navigate({ mode = mode, cat = cat }) end,
        }
    end
    return items
end

function UI:ChainMenu(cat, selected)
    local items = {}
    local chains = self:Content(cat)
    for _, e in ipairs(chains) do
        local cid = e.cid
        items[#items + 1] = {
            text = ns.ChainName(cid), right = e.d .. "/" .. e.t, selected = cid == selected,
            onClick = function() UI:OpenChain(cid) end,
        }
    end
    return items
end

function UI:HomeCrumb(mode)
    return { text = L.HOME, onClick = function() UI:Navigate({ mode = mode, home = true }) end }
end

-- ------------------------------------------------------------------ tile grid
--- Lays tiles out in a grid; returns the y under them.
function UI:TileGrid(y, entries, fill, height)
    if #entries == 0 then return y end
    local vw = self:ViewWidth()
    local GAP, MINW = 10, 176
    local cols = math.max(1, math.floor((vw - 4 + GAP) / (MINW + GAP)))
    local tw = math.floor((vw - 4 - (cols - 1) * GAP) / cols)
    local th = height or 96
    for i, e in ipairs(entries) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local t = Acquire(self.tiles, self.canvas)
        t:SetSize(tw, th)
        t:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", 4 + col * (tw + GAP), -(y + row * (th + GAP)))
        fill(t, e)
    end
    local rows = math.ceil(#entries / cols)
    return y + rows * (th + GAP) + 6
end

-- ------------------------------------------------------------------ home: every map of a mode
function UI:RenderHome(mode)
    local label = L[MODE_BY_KEY[mode].label]
    self:SetCrumbs({ self:HomeCrumb(mode) })
    self.head.title:SetText(label)
    self:SetMapTarget(nil)
    local list = self:CatsForMode(mode)
    local open, done, ignored = {}, {}, {}
    local allD, allT = 0, 0
    local current = ns.CurrentCategory()
    local rep = mode == "repeat"
    for _, e in ipairs(list) do
        if rep then
            e.d, e.t, e.started = 0, e.count, false
        else
            local d, t, avail, started = self:CatProgress(e.cat)
            e.d, e.t, e.avail, e.started = d, t, avail, started
        end
        e.key = (rep and "r" or "m") .. e.cat
        allD, allT = allD + e.d, allT + e.t
        if ns.IsIgnored(e.key) then ignored[#ignored + 1] = e
        elseif not rep and e.t > 0 and e.d >= e.t then done[#done + 1] = e
        else open[#open + 1] = e end
    end
    -- pinned first, then continent groups in level order
    table.sort(open, function(a, b)
        local pa, pb = ns.IsPinned(a.key) and 0 or 1, ns.IsPinned(b.key) and 0 or 1
        if pa ~= pb then return pa < pb end
        if a.kind ~= b.kind then return a.kind < b.kind end
        if a.kind == 7 or a.kind == 8 then return ns.CatName(a.cat) < ns.CatName(b.cat) end
        if a.lo ~= b.lo then return a.lo < b.lo end
        return ns.CatName(a.cat) < ns.CatName(b.cat)
    end)
    self.head.sub:SetText(rep and L.REPEAT_HOME_SUB:format(allT, #list) or L.HOME_SUB:format(#list))
    self.head.bar:SetShown(not rep)
    self.head.bar:SetProgress(allD, allT)
    self.head.bar.text:SetText(L.PROGRESS:format(allD, allT))

    local function fill(t, e)
        t.key = e.key
        t.title:SetText(ns.CatName(e.cat))
        local sub = (e.kind == 7 or e.kind == 8) and QuestCount(e.t) or LevelText(e.lo, e.hi)
        if rep then
            sub = L.REPEAT_N:format(e.count) .. ((e.kind ~= 7 and e.kind ~= 8) and ("  ·  " .. LevelText(e.lo, e.hi)) or "")
        elseif e.avail > 0 and not (e.t > 0 and e.d >= e.t) then
            sub = sub .. "  ·  " .. L.AVAILABLE_N:format(e.avail)
        end
        t.sub:SetText(sub)
        if e.cat == current then
            t.note:SetText(Color(L.YOU_ARE_HERE, GREEN))
        else
            t.note:SetText("")
        end
        local red = e.fallback and not ns.db.showHigher
        if red then t.title:SetTextColor(RED[1], RED[2], RED[3]) else t.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
        t.bar:SetShown(not rep)
        t.count:SetShown(not rep)
        t.bar:SetProgress(e.d, e.t)
        t.count:SetText(e.d .. "/" .. e.t)
        TileState(t, e.started, not rep and e.t > 0 and e.d >= e.t, red)
        t.onClick = function() UI:Navigate({ mode = mode, cat = e.cat }) end
        t.onEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ns.CatName(e.cat), 1, 1, 1)
            GameTooltip:AddLine(LevelText(e.lo, e.hi), GOLD[1], GOLD[2], GOLD[3])
            if rep then GameTooltip:AddLine(L.REPEAT_N:format(e.count), 0.6, 0.8, 1) else GameTooltip:AddLine(L.PROGRESS:format(e.d, e.t), 0.8, 0.8, 0.8) end
            if not rep and e.avail > 0 then GameTooltip:AddLine(L.AVAILABLE_N:format(e.avail), 1, 1, 0.6) end
            local lore = ns.ZoneLore(e.cat)
            if lore then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine((lore:match("^[^\n]+") or lore), 1, 0.95, 0.8, true)
            end
            GameTooltip:Show()
        end
    end

    local y = 6
    if mode == "quest" then
        -- one block per continent, the way the sidebar groups them
        local lastGroup, block = nil, {}
        local function flush()
            if #block > 0 then
                y = self:AddSeparator(y, L[lastGroup] or "", nil)
                y = self:TileGrid(y, block, fill)
                block = {}
            end
        end
        local pinned = {}
        for _, e in ipairs(open) do
            if ns.IsPinned(e.key) then pinned[#pinned + 1] = e end
        end
        if #pinned > 0 then
            y = self:AddSeparator(y, L.PINNED, nil)
            y = self:TileGrid(y, pinned, fill)
        end
        for _, e in ipairs(open) do
            if not ns.IsPinned(e.key) then
                local g = GROUP_LABEL[e.kind] or "OTHER"
                if g ~= lastGroup then
                    flush()
                    lastGroup = g
                end
                block[#block + 1] = e
            end
        end
        flush()
    else
        y = self:TileGrid(y, open, fill)
    end
    if #done > 0 then
        local collapsed
        y, collapsed = self:AddSeparator(y + 4, L.COMPLETED_SEP, "(" .. #done .. ")", "home-done-" .. mode)
        if not collapsed then y = self:TileGrid(y, done, fill) end
    end
    if #ignored > 0 then
        local collapsed
        y, collapsed = self:AddSeparator(y + 4, L.IGNORED_SEP, "(" .. #ignored .. ")", "home-ign-" .. mode)
        if collapsed == nil then collapsed = false end
        if not collapsed then y = self:TileGrid(y, ignored, fill) end
    end
    if #list == 0 then y = self:AddMessage(y + 20, L.NOTHING_HERE) end
    self.scroll:SetContentSize(self:ViewWidth(), y + 10)
end

-- ------------------------------------------------------------------ a map
--- Where a chain goes or comes from, as display text.
local function LinkTargets(c, dir)
    local list = dir == "out" and c[5] or c[6]
    if not list then return nil end
    local seen, names = {}, {}
    for i = 1, #list, 3 do
        local a, b = list[i], list[i + 1]
        local other = dir == "out" and b or a
        local mine = dir == "out" and a or b
        if ns.IsEligible(other) and ns.IsEligible(mine) then
            local cat = ns.Q[other][ns.F.CAT]
            if not seen[cat] then
                seen[cat] = true
                names[#names + 1] = ns.CatName(cat)
            end
        end
    end
    if #names == 0 then return nil end
    return table.concat(names, ", ")
end
UI.LinkTargets = LinkTargets

--- The bridge quests of a chain (the ones that take you to another region).
local function ChainBridges(cid)
    local out = {}
    for _, id in ipairs(ns.C[cid][3]) do
        if ns.BridgeTo(id) and ns.IsEligible(id) then out[#out + 1] = id end
    end
    return out
end

function UI:AddBridgeRow(y, id, dir)
    local b = Acquire(self.bridgeRows, self.canvas)
    b:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", 6, -y)
    b:SetWidth(self:ViewWidth() - 10)
    local q = ns.Q[id]
    local st = ns.Status(id)
    SetStatusIcon(b.icon, st, q[ns.F.FLAGS])
    local giver = ns.EntityName(q[9], q[10]) or "?"
    local taker = ns.EntityName(q[14], q[15]) or "?"
    local fromMap = q[11] and ns.MapName(q[11]) or "?"
    local toMap = q[16] and ns.MapName(q[16]) or "?"
    local text
    if dir == "in" then
        text = Arrow("in") .. Color(L.BRIDGE_ARRIVE, BRIDGE) .. "  " .. ns.QName(id) .. Color(("  [%d]"):format(q[ns.F.LVL] or 0), GOLD) ..
            Color("  —  " .. L.BRIDGE_FROM_TO:format(giver, fromMap, taker), { 0.75, 0.72, 0.65 })
    else
        text = Arrow("out") .. Color(L.BRIDGE_LEAVE, BRIDGE) .. "  " .. ns.QName(id) .. Color(("  [%d]"):format(q[ns.F.LVL] or 0), GOLD) ..
            Color("  —  " .. L.BRIDGE_TO_WHO:format(taker, toMap), { 0.75, 0.72, 0.65 })
    end
    b.text:SetText(text)
    b.onClick = function(_, button)
        local cid = q[ns.F.CHAIN]
        if button == "RightButton" and cid then UI:OpenChain(cid, id) else UI:QuestClick(id, button, true) end
    end
    b.onEnter = function(self) UI:QuestTooltip(self, id, { rightOpensChain = true }) end
    return y + 26
end

--- A map in the Repeatable section: one tile per repeatable quest.
function UI:RenderRepeatCategory(cat)
    local mode = "repeat"
    local m = ns.M[cat]
    local name = ns.CatName(cat)
    self:SetCrumbs({
        self:HomeCrumb(mode),
        { text = name, onClick = function() UI:Navigate({ mode = mode, cat = cat }) end,
          menu = function() return UI:MapMenu(mode, cat) end },
    })
    local ids, fallback = self:RepeatContent(cat)
    self.head.title:SetText(name)
    self.head.sub:SetText(LevelText(m[3], m[4]) .. "  ·  " .. L.REPEAT_N:format(#ids))
    self:SetMapTarget(cat)
    if fallback and not ns.db.showHigher then
        local minReq
        for _, id in ipairs(ids) do
            local r = ns.Q[id][ns.F.REQ] or 0
            if not minReq or r < minReq then minReq = r end
        end
        self:ShowBanner(L.LOW_LEVEL_WARN:format(minReq or 0))
    end
    self:LayoutScroll(self.withBanner, false)
    local y = 6
    y = self:AddMessage(y, Color(L.REPEAT_INFO, { 0.75, 0.72, 0.65 }))
    local open, ignored = {}, {}
    for _, id in ipairs(ids) do
        local e = { id = id, key = "q" .. id, st = ns.Status(id) }
        -- a repeatable quest done before is still there to do again
        if e.st == ST.DONE then e.st = ST.AVAILABLE end
        if ns.IsIgnored(e.key) then ignored[#ignored + 1] = e else open[#open + 1] = e end
    end
    table.sort(open, function(a, b)
        local pa, pb = ns.IsPinned(a.key) and 0 or 1, ns.IsPinned(b.key) and 0 or 1
        if pa ~= pb then return pa < pb end
        return false
    end)
    local red = fallback and not ns.db.showHigher
    local function fill(t, e) UI:FillSingleTile(t, e, mode, cat, red) end
    y = self:TileGrid(y, open, fill, 104)
    if #ignored > 0 then
        local collapsed
        y, collapsed = self:AddSeparator(y + 4, L.IGNORED_SEP, "(" .. #ignored .. ")", "ignored-rep")
        if not collapsed then y = self:TileGrid(y, ignored, fill, 104) end
    end
    if #ids == 0 then y = self:AddMessage(y + 20, L.NOTHING_HERE) end
    self.scroll:SetContentSize(self:ViewWidth(), y + 10)
end

function UI:RenderCategory(cat)
    local mode = self.state.mode
    if mode == "repeat" then return self:RenderRepeatCategory(cat) end
    local m = ns.M[cat]
    local name = ns.CatName(cat)
    self:SetCrumbs({
        self:HomeCrumb(mode),
        { text = name, onClick = function() UI:Navigate({ mode = mode, cat = cat }) end,
          menu = function() return UI:MapMenu(mode, cat) end },
    })
    local done, total = ns.CatStats(cat)
    self.head.title:SetText(name)
    self.head.sub:SetText(LevelText(m[3], m[4]))
    self.head.bar:Show()
    self.head.bar:SetProgress(done, total)
    self.head.bar.text:SetText(L.PROGRESS:format(done, total))
    self:SetMapTarget(cat)

    local chains, singles, fallback, minReq = self:Content(cat)
    if fallback and not ns.db.showHigher then self:ShowBanner(L.LOW_LEVEL_WARN:format(minReq)) end
    self:LayoutScroll(self.withBanner, false)
    local y = 6
    self.loreBox.loreCat = cat
    self.playCtx = { cat = cat }
    y = self:AddLore(y, L.LORE_PLACE:format(name), ns.ZoneLore(cat))

    local _, leave = ns.CatBridges(cat)

    local open, done, ignored = {}, {}, {}
    for _, e in ipairs(chains) do
        e.key = "c" .. e.cid
        if ns.IsIgnored(e.key) then ignored[#ignored + 1] = e
        elseif e.best == ST.DONE then done[#done + 1] = e
        else open[#open + 1] = e end
    end
    -- pinned chains first; the rest stays in story order
    local pinned, rest = {}, {}
    for _, e in ipairs(open) do
        if ns.IsPinned(e.key) then pinned[#pinned + 1] = e else rest[#rest + 1] = e end
    end
    open = pinned
    for _, e in ipairs(rest) do open[#open + 1] = e end

    local function fill(t, e)
        local c = ns.C[e.cid]
        t.key = e.key
        t.title:SetText(ns.ChainName(e.cid))
        local lo, hi = ns.ChainLevels(e.cid)
        t.sub:SetText(QuestCount(e.t) .. "  ·  " .. LevelText(lo, hi))
        local red = fallback and not ns.db.showHigher
        if red then t.title:SetTextColor(RED[1], RED[2], RED[3]) else t.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
        local outT, inT = LinkTargets(c, "out"), LinkTargets(c, "in")
        local bridges = ChainBridges(e.cid)
        local note = ""
        if outT then
            note = Arrow("out") .. Color(L.CONTINUES_IN .. ": " .. outT, PURPLE)
        elseif inT then
            note = Arrow("in") .. Color(L.COMES_FROM .. ": " .. inT, { 0.75, 0.75, 0.75 })
        elseif #bridges > 0 then
            note = Color(L.BRIDGE_TAG .. ": " .. L.BRIDGE_TO:format(ns.CatName(ns.BridgeTo(bridges[1]))), BRIDGE)
        elseif e.best == ST.LOCKED then
            note = Color(L.ST_LOCKED, GREY)
        elseif e.best == ST.ACTIVE or e.best == ST.READY then
            note = Color(STATUS_TEXT[e.best](c[2]), GOLD)
        end
        t.note:SetText(note)
        t.bar:Show()
        t.count:Show()
        t.bar:SetProgress(e.d, e.t)
        t.count:SetText(e.d .. "/" .. e.t)
        TileState(t, ns.ChainStarted(e.cid), e.best == ST.DONE, red)
        t.onClick = function() UI:OpenChain(e.cid) end
        t.onEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ns.ChainName(e.cid), 1, 0.82, 0)
            GameTooltip:AddLine(QuestCount(e.t) .. "  ·  " .. LevelText(lo, hi), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L.PROGRESS:format(e.d, e.t), 1, 1, 1)
            local lore = ns.ChainLore(e.cid) or ns.ChainSummary(e.cid)
            if lore then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(lore, 1, 0.95, 0.8, true)
            end
            if inT then GameTooltip:AddLine(L.COMES_FROM .. ": " .. inT, 0.7, 0.7, 0.7, true) end
            if outT then
                GameTooltip:AddLine(L.CONTINUES_IN .. ": " .. outT, PURPLE[1], PURPLE[2], PURPLE[3], true)
                GameTooltip:AddLine(L.NO_RETURN, 0.6, 0.6, 0.6, true)
            end
            for _, id in ipairs(bridges) do
                GameTooltip:AddLine(L.BRIDGE_TAG .. ": " .. ns.QName(id) .. " → " .. ns.CatName(ns.BridgeTo(id)), BRIDGE[1], BRIDGE[2], BRIDGE[3], true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.TT_OPEN_CHAIN, 0.5, 1, 0.5)
            GameTooltip:Show()
        end
    end


    -- standalone quests: one tile each, opening a view with just that quest
    local openSingles, doneSingles, ignoredSingles = {}, {}, {}
    for _, id in ipairs(singles) do
        local key = "q" .. id
        local st = ns.Status(id)
        local e = { id = id, key = key, st = st }
        if ns.IsIgnored(key) then ignoredSingles[#ignoredSingles + 1] = e
        elseif st == ST.DONE then doneSingles[#doneSingles + 1] = e
        else openSingles[#openSingles + 1] = e end
    end
    local pinnedS, restS = {}, {}
    for _, e in ipairs(openSingles) do
        if ns.IsPinned(e.key) then pinnedS[#pinnedS + 1] = e else restS[#restS + 1] = e end
    end
    openSingles = pinnedS
    for _, e in ipairs(restS) do openSingles[#openSingles + 1] = e end
    local function fillSingle(t, e)
        UI:FillSingleTile(t, e, mode, cat, fallback and not ns.db.showHigher)
    end
    local function fillAny(t, e)
        if e.cid then fill(t, e) else fillSingle(t, e) end
    end
    --- Chains and standalone quests in one list: chains keep their story order and each
    --- standalone quest goes in by level. Pinned ones stay on top.
    local function merge(chainList, singleList)
        local function lvl(e)
            if e.cid then return (select(1, ns.ChainLevels(e.cid))) end
            return ns.Q[e.id][ns.F.LVL] or 0
        end
        local out, si = {}, 1
        local sorted = {}
        for _, e in ipairs(singleList) do sorted[#sorted + 1] = e end
        table.sort(sorted, function(a, b)
            local pa, pb = ns.IsPinned(a.key) and 0 or 1, ns.IsPinned(b.key) and 0 or 1
            if pa ~= pb then return pa < pb end
            if lvl(a) ~= lvl(b) then return lvl(a) < lvl(b) end
            return a.id < b.id
        end)
        for _, c in ipairs(chainList) do
            while sorted[si] and (ns.IsPinned(sorted[si].key) or lvl(sorted[si]) < lvl(c)) and not (ns.IsPinned(c.key) and not ns.IsPinned(sorted[si].key)) do
                out[#out + 1] = sorted[si]
                si = si + 1
            end
            out[#out + 1] = c
        end
        for i = si, #sorted do out[#out + 1] = sorted[i] end
        return out
    end
    local all = merge(open, openSingles)
    if #all > 0 then y = self:TileGrid(y + 2, all, fillAny, 104) end

    if #done > 0 or #doneSingles > 0 then
        local collapsed
        y, collapsed = self:AddSeparator(y + 4, L.COMPLETED_SEP, "(" .. (#done + #doneSingles) .. ")", "done")
        if not collapsed then y = self:TileGrid(y, merge(done, doneSingles), fillAny, 104) end
    end

    -- where the story goes from here
    local leaveShown = {}
    for _, id in ipairs(leave) do
        if ns.IsEligible(id) and ns.PassesLevel(id) then leaveShown[#leaveShown + 1] = id end
    end
    if #leaveShown > 0 then
        local collapsed
        y, collapsed = self:AddSeparator(y + 4, L.BRIDGES_OUT, "(" .. #leaveShown .. ")", "leave")
        if not collapsed then
            for i, id in ipairs(leaveShown) do
                if i > 12 then break end
                y = self:AddBridgeRow(y, id, "out")
            end
        end
    end

    if #ignored > 0 or #ignoredSingles > 0 then
        local collapsed
        y, collapsed = self:AddSeparator(y + 4, L.IGNORED_SEP, "(" .. (#ignored + #ignoredSingles) .. ")", "ignored")
        if not collapsed then y = self:TileGrid(y, merge(ignored, ignoredSingles), fillAny, 104) end
    end

    if #chains == 0 and #singles == 0 then y = self:AddMessage(y + 20, L.NOTHING_HERE) end
    self.scroll:SetContentSize(self:ViewWidth(), y + 10)
end

--- A standalone quest as a tile.
function UI:FillSingleTile(t, e, mode, cat, red)
    local id, st = e.id, e.st
    local q = ns.Q[id]
    t.key = e.key
    t.title:SetText(ns.QName(id))
    if red or st == ST.LEVEL then t.title:SetTextColor(RED[1], RED[2], RED[3]) else t.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
    local lvl = LevelText(q[ns.F.LVL] or 0, q[ns.F.LVL] or 0)
    local who = ns.EntityName(q[9], q[10])
    if cat >= 800000 or cat == 0 then
        t.sub:SetText(lvl .. "  ·  " .. QuestPlace(id))
    else
        t.sub:SetText(L.QUEST_1 .. "  ·  " .. lvl)
    end
    local note = ""
    local dest = ns.BridgeTo(id)
    if st == ST.ACTIVE or st == ST.READY then
        note = Color(STATUS_TEXT[st](id), GOLD)
    elseif st == ST.LEVEL then
        note = Color(L.ST_LEVEL:format(q[ns.F.REQ] or 0), RED)
    elseif dest then
        note = Color(L.BRIDGE_TAG .. ": " .. L.BRIDGE_TO:format(ns.CatName(dest)), BRIDGE)
    elseif who then
        note = Color(who, { 0.8, 0.75, 0.6 })
    end
    t.note:SetText(note)
    local done = st == ST.DONE
    local repeatable = ns.IsRepeatable(id)
    t.bar:SetShown(not repeatable)
    t.count:SetShown(not repeatable)
    if repeatable and note == "" then note = Color(L.TAG_REPEAT, { 0.45, 0.75, 1 }) end
    t.note:SetText(note)
    t.bar:SetProgress(done and 1 or 0, 1)
    t.count:SetText((done and 1 or 0) .. "/1")
    TileState(t, st == ST.ACTIVE or st == ST.READY, done, red)
    t.onClick = function(_, button)
        if button == "RightButton" then ns:ShowLocation(id, IsShiftKeyDown()) return end
        UI:Navigate({ mode = mode, cat = cat, single = id, focus = id })
    end
    t.onEnter = function(self) UI:QuestTooltip(self, id) end
end

--- One standalone quest: its giver and the quest, with its story beside it.
function UI:RenderSingle(id)
    local q = ns.Q[id]
    local cat = self.state.cat or q[ns.F.CAT]
    local mode = self.state.mode or ModeForCat(cat)
    local catName = ns.CatName(cat)
    self:SetCrumbs({
        self:HomeCrumb(mode),
        { text = catName, onClick = function() UI:Navigate({ mode = mode, cat = cat }) end,
          menu = function() return UI:MapMenu(mode, cat) end },
        { text = ns.QName(id), onClick = function() end },
    })
    local st = ns.Status(id)
    self.head.title:SetText(ns.QName(id))
    self.head.sub:SetText(catName .. "  ·  " .. LevelText(q[ns.F.LVL] or 0, q[ns.F.LVL] or 0) .. "  ·  " .. STATUS_TEXT[st](id))
    self:SetMapTarget(cat)
    self.head.storyBtn:Show()
    self.head.storyBtn:SetText(ns.db.storyPanel and L.HIDE_STORY or L.VIEW_STORY)
    local lay = ns.BuildSingleLayout(id)
    self.lay = lay
    self.state.focus = self.state.focus or id
    self.playCtx = { cat = cat, quest = id }
    self:LayoutScroll(self.withBanner, ns.db.storyPanel)
    self:RenderChainTree(cat, lay)
    if ns.db.storyPanel then self.story:Render(nil, lay, self.state.focus, cat) end
end

-- ------------------------------------------------------------------ chain view
function UI:RenderChain(cid)
    local c = ns.C[cid]
    local cat = c[1]
    local mode = self.state.mode or ModeForCat(cat)
    local lay = ns.BuildChainLayout(cid)
    local fallback = false
    if #lay.nodes == 0 then
        lay = ns.BuildChainLayout(cid, true)
        fallback = true
        local minReq
        for _, id in ipairs(c[3]) do
            if ns.IsEligible(id) then
                local r = ns.Q[id][ns.F.REQ] or 0
                if not minReq or r < minReq then minReq = r end
            end
        end
        self:ShowBanner(L.LOW_LEVEL_WARN:format(minReq or 0))
    end
    local catName, chainName = ns.CatName(cat), ns.ChainName(cid)
    self:SetCrumbs({
        self:HomeCrumb(mode),
        { text = catName, onClick = function() UI:Navigate({ mode = mode, cat = cat }) end,
          menu = function() return UI:MapMenu(mode, cat) end },
        { text = chainName, onClick = function() end, menu = function() return UI:ChainMenu(cat, cid) end },
    })
    local d, t = ns.ChainStats(cid)
    local lo, hi = ns.ChainLevels(cid)
    self.head.title:SetText(chainName)
    self.head.sub:SetText(catName .. "  ·  " .. QuestCount(t) .. "  ·  " .. LevelText(lo, hi))
    self.head.bar:Show()
    self.head.bar:SetProgress(d, t)
    self.head.bar.text:SetText(L.PROGRESS:format(d, t))
    self:SetMapTarget(cat)
    self.head.storyBtn:Show()
    self.head.storyBtn:SetText(ns.db.storyPanel and L.HIDE_STORY or L.VIEW_STORY)
    self.lay = lay
    self.playCtx = { cat = cat, cid = cid, quest = self.state.focus }
    self:LayoutScroll(self.withBanner, ns.db.storyPanel)
    self:RenderChainTree(cat, lay)
    if ns.db.storyPanel then
        self.story:Render(cid, lay, self.state.focus, cat)
    end
end

--- Selects a quest: highlights its node and shows it in the story panel.
function UI:SelectQuest(id, fromStory)
    if not self.state then return end
    self.state.focus = id
    if self.playCtx then self.playCtx.quest = id end
    if ns.Player then ns.Player:Update() end
    for _, b in ipairs(self.nodes.used) do
        b.sel:SetShown(b.questID == id)
    end
    if fromStory then
        for _, b in ipairs(self.nodes.used) do
            if b.questID == id then self:ScrollToNode(b) break end
        end
    elseif ns.db.storyPanel and self.story.frame:IsShown() then
        self.story:Select(id)
    end
end

function UI:ScrollToNode(b)
    local _, _, _, x, y = b:GetPoint()
    if not x then return end
    self.scroll:SetH(x + NODE_W / 2 - (self.scroll:GetWidth() or 600) / 2)
    self.scroll:SetV(-y - 80)
end

function UI:RenderChainTree(cat, lay)
    local vw = self:ViewWidth()
    local top = 18
    local focusNode

    local outDeg = {}
    for _, e in ipairs(lay.edges) do outDeg[e[1]] = (outDeg[e[1]] or 0) + 1 end
    local fitCols = math.max(3, math.floor((vw - 20) / COL_W))
    local layerY, layerWrap, effWidth = {}, {}, 0
    local yAcc = top
    for li = 0, lay.depth do
        local row = lay.layers[li]
        local wrap
        if #row > fitCols then
            local story, leaves = {}, {}
            for _, nd in ipairs(row) do
                if outDeg[nd.key] then story[#story + 1] = nd else leaves[#leaves + 1] = nd end
            end
            if #story <= fitCols then
                wrap = fitCols
                local ordered = {}
                local left = math.floor((fitCols - #story) / 2)
                for i = 1, math.min(left, #leaves) do ordered[#ordered + 1] = leaves[i] end
                for _, nd in ipairs(story) do ordered[#ordered + 1] = nd end
                for i = math.min(left, #leaves) + 1, #leaves do ordered[#ordered + 1] = leaves[i] end
                lay.layers[li] = ordered
                row = ordered
            end
        end
        layerWrap[li] = wrap
        layerY[li] = yAcc
        local subRows = wrap and math.ceil(#row / wrap) or 1
        yAcc = yAcc + subRows * ROW_H
        local w = wrap or #row
        if w > effWidth then effWidth = w end
    end
    local canvasW = math.max(vw, effWidth * COL_W + 40)

    for li = 0, lay.depth do
        local row = lay.layers[li]
        local n = #row
        local wrap = layerWrap[li]
        for k, nd in ipairs(row) do
            local b = Acquire(self.nodes, self.canvas)
            NodeReset(b)
            local pos, cnt, sub = nd.pos, n, 0
            if wrap then
                sub = math.floor((k - 1) / wrap)
                pos = (k - 1) % wrap + 1
                cnt = math.min(wrap, n - sub * wrap)
            end
            local x = canvasW / 2 + (pos - (cnt + 1) / 2) * COL_W - NODE_W / 2
            local yy = layerY[li] + sub * ROW_H
            b:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", x, -yy)
            nd.frame = b
            b.questID = nd.quest
            if nd.quest then
                self:FillQuestNode(b, nd.quest, cat)
                if self.state.focus == nd.quest then focusNode = b; b.sel:Show() end
            elseif nd.giver then
                self:FillGiverNode(b, nd.giver)
            else
                self:FillLinkNode(b, nd.link)
            end
        end
    end

    for _, e in ipairs(lay.edges) do
        local a, b = lay.byKey[e[1]], lay.byKey[e[2]]
        if a and b and a.frame and b.frame then
            local state
            if a.link or b.link then
                state = "link"
            elseif a.giver then
                local st = ns.Status(b.quest)
                if st == ST.DONE or st == ST.ACTIVE or st == ST.READY then state = "done" end
            elseif a.quest and ns.IsDone(a.quest) then
                state = "done"
                if b.quest then
                    local st = ns.Status(b.quest)
                    if st == ST.ACTIVE or st == ST.READY then state = "active" end
                end
            end
            self:Connect(a.frame, b.frame, state, e[3] == 3)
        end
    end

    local y = yAcc
    if #lay.nodes == 0 then y = self:AddMessage(y, L.NOTHING_HERE) end
    self.scroll:SetContentSize(canvasW, y + 20)

    if not self.state.scrolled then
        self.state.scrolled = true
        local extra = canvasW - self.scroll:GetWidth()
        C_Timer.After(0, function()
            if extra > 0 then self.scroll:SetH(extra / 2) end
            if focusNode then self:ScrollToNode(focusNode) end
        end)
    end
end

function UI:FillQuestNode(b, id, cat)
    local q = ns.Q[id]
    local st = ns.Status(id)
    b.name:SetText(ns.QName(id))
    b.level:SetText(L.LEVEL_ONE:format(q[ns.F.LVL] or 0))
    SetStatusIcon(b.status, st, q[ns.F.FLAGS])
    if st == ST.DONE then
        b.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    elseif st == ST.LEVEL then
        b.name:SetTextColor(RED[1], RED[2], RED[3])
        b.art:SetDesaturated(true)
    elseif st == ST.LOCKED then
        b.name:SetTextColor(0.6, 0.58, 0.52)
        b.art:SetDesaturated(true)
        b.art:SetVertexColor(0.6, 0.6, 0.6)
    elseif st == ST.EXCLUDED or st == ST.SKIPPED then
        b.name:SetTextColor(0.5, 0.5, 0.5)
        b.art:SetDesaturated(true)
        b:SetAlpha(0.55)
    end
    if st == ST.ACTIVE or st == ST.READY then b.active:Show() end
    if st == ST.AVAILABLE then b.next:Show() end
    -- bridge quests carry a travel mark and a blue tint
    if ns.BridgeTo(id) then
        b.tag:Show()
        Skin.SetIcon(b.tag, "poi-traveldirections-arrow", "Interface\\Icons\\INV_Misc_Map_01")
        b.cover:SetVertexColor(BRIDGE[1] * 1.1, BRIDGE[2] * 1.1, BRIDGE[3] * 1.1)
    elseif cat >= 800000 then
        local map = q[11] or q[16]
        if map then b.level:SetText(L.LEVEL_ONE:format(q[ns.F.LVL] or 0) .. " · " .. ns.MapName(map)) end
    end
    b.onClick = function(_, button)
        if button == "RightButton" or IsShiftKeyDown() or not ns.db.storyPanel then
            ns:ShowLocation(id, IsShiftKeyDown())
            UI:SelectQuest(id)
        else
            UI:SelectQuest(id)
        end
    end
    b.onEnter = function(self) UI:QuestTooltip(self, id, { node = true }) end
end

--- "Go to <NPC>": who starts this way into the chain, and where.
function UI:FillGiverNode(b, g)
    local who = ns.EntityName(g.kind, g.id) or "?"
    if g.kind == 3 then
        b.name:SetText(L.GO_FIND_ITEM:format(who))
    else
        b.name:SetText(L.GO_TO:format(who))
    end
    b.name:SetTextColor(1, 0.9, 0.7)
    b.art:SetVertexColor(0.85, 0.75, 0.6)
    local started = false
    for _, id in ipairs(g.quests) do
        local st = ns.Status(id)
        if st == ST.DONE or st == ST.ACTIVE or st == ST.READY then started = true end
    end
    if started then
        Skin.SetIcon(b.status, "common-icon-checkmark", "Interface\\RaidFrame\\ReadyCheck-Ready")
    else
        b.status:SetTexture(nil)
        b.status:Hide()
    end
    if g.map then b.level:SetText(ns.MapName(g.map)) end
    b.onClick = function()
        local id = g.quests[1]
        if id then ns:ShowLocation(id, false) end
    end
    b.onEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(g.kind == 3 and L.GO_FIND_ITEM:format(who) or L.GO_TO:format(who), 1, 0.82, 0)
        if g.map then
            GameTooltip:AddLine(("%s (%.1f, %.1f)"):format(ns.MapName(g.map), g.x or 0, g.y or 0), 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.GO_STARTS, GOLD[1], GOLD[2], GOLD[3])
        for _, id in ipairs(g.quests) do
            local col = STATUS_COLOR[ns.Status(id)]
            GameTooltip:AddDoubleLine("  " .. ns.QName(id), ("[%d]"):format(ns.Q[id][ns.F.LVL] or 0), col[1], col[2], col[3], GOLD[1], GOLD[2], GOLD[3])
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TT_CLICK, 0.5, 1, 0.5)
        GameTooltip:Show()
    end
end

function UI:FillLinkNode(b, lk)
    local where = ns.CatName(lk.cat)
    local target = lk.chain and ns.ChainName(lk.chain) or ns.QName(lk.quest)
    b.name:SetText((lk.dir == "out" and L.CONTINUES_IN or L.COMES_FROM) .. ": " .. where)
    b.name:SetTextColor(0.9, 0.78, 1)
    b.art:SetVertexColor(PURPLE[1], PURPLE[2], PURPLE[3])
    b.level:SetText("")
    Skin.SetIcon(b.status, (lk.dir == "out") and "common-icon-forwardarrow" or "common-icon-backarrow", "Interface\\Icons\\INV_Misc_Map_01")
    b.onClick = function()
        if lk.chain then UI:OpenChain(lk.chain, lk.quest) else UI:OpenCategory(lk.cat) end
    end
    b.onEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine((lk.dir == "out" and L.CONTINUES_IN or L.COMES_FROM) .. ": " .. where, PURPLE[1], PURPLE[2], PURPLE[3])
        GameTooltip:AddLine(target, 1, 1, 1)
        if lk.dir == "out" then GameTooltip:AddLine(L.NO_RETURN, 0.7, 0.7, 0.7, true) end
        if lk.type == 3 then GameTooltip:AddLine("(" .. L.OPTIONAL .. ")", 0.6, 0.6, 0.6) end
        GameTooltip:AddLine(" ")
        for _, qid in ipairs(lk.quests or {}) do
            local col = STATUS_COLOR[ns.Status(qid)]
            GameTooltip:AddDoubleLine(ns.QName(qid), ("[%d]"):format(ns.Q[qid][ns.F.LVL] or 0), col[1], col[2], col[3], GOLD[1], GOLD[2], GOLD[3])
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TT_GO, 0.5, 1, 0.5)
        GameTooltip:Show()
    end
end

-- ------------------------------------------------------------------ search
function UI:RenderSearch(text)
    self:SetCrumbs({ self:HomeCrumb(self.state.mode or "quest"), { text = L.RESULTS } })
    self.head.title:SetText(L.RESULTS)
    self:SetMapTarget(nil)
    local res = ns.Search(text)
    local shown = {}
    for _, id in ipairs(res) do
        if ns.PassesLevel(id) then shown[#shown + 1] = id end
    end
    SortQuests(shown)
    self.head.sub:SetText('"' .. text .. '"  ·  ' .. #shown)
    local y = 6
    if #shown == 0 then
        y = self:AddMessage(y + 20, L.NO_RESULTS)
    else
        for i, id in ipairs(shown) do
            if i > 300 then break end
            y = self:AddQuestRow(y, id, { showPlace = true, chainButton = true })
        end
    end
    self.scroll:SetContentSize(self:ViewWidth(), y + 10)
end
