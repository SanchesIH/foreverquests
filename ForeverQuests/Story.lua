local _, ns = ...
local L = ns.L
local ST = ns.ST
local Skin = ns.Skin

-- The story beside the tree, like the quest details beside the world map: the chain told in
-- the order it is played, one block per quest. Clicking a node scrolls here; clicking a block
-- highlights its node.
local Story = {}
ns.Story = Story

local GOLD, GREEN, BRIDGE, PURPLE = Skin.GOLD, Skin.GREEN, Skin.BRIDGE, Skin.PURPLE
local TEXT = { 0.93, 0.89, 0.8 }
local DIM = { 0.66, 0.62, 0.55 }

local function Color(text, c) return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) .. text .. "|r" end

-- one block: a heading, a few short lines and the text
local function BlockCreate(parent)
    local b = CreateFrame("Button", nil, parent)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetTexture(Skin.MEDIA .. "Fade")
    b.sel:SetVertexColor(1, 0.75, 0.15, 0.28)
    b.selBar = b:CreateTexture(nil, "ARTWORK")
    b.selBar:SetPoint("TOPLEFT", 0, 0)
    b.selBar:SetPoint("BOTTOMLEFT", 0, 0)
    b.selBar:SetWidth(3)
    b.selBar:SetColorTexture(1, 0.82, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("TOPLEFT", 8, -4)
    b.title = b:CreateFontString(nil, "OVERLAY", "ForeverQuestsFontStoryTitle")
    b.title:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 6, 2)
    b.title:SetJustifyH("LEFT")
    b.title:SetWordWrap(true)
    b.lines = {}
    b.speak = ns.Speech:Button(b, 14, function()
        if b.questID then return { Story:QuestItem(b.questID) }, ns.QName(b.questID) end
        return { { label = b.title:GetText() or "", segments = b.segments } }, b.title:GetText()
    end)
    b.speak:SetPoint("TOPRIGHT", -6, -4)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.05)
    b:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
    b:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

--- Fills a block: title, then rows of { text, font, color }. Returns its height.
local function FillBlock(b, w, title, icon, rows)
    for _, fs in ipairs(b.lines) do fs:Hide() end
    if icon then
        b.icon:Show()
        if type(icon) == "function" then icon(b.icon) else Skin.SetIcon(b.icon, nil, icon) end
        b.title:ClearAllPoints()
        b.title:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 6, 2)
        b.title:SetWidth(w - 40)
    else
        b.icon:Hide()
        b.title:ClearAllPoints()
        b.title:SetPoint("TOPLEFT", 10, -4)
        b.title:SetWidth(w - 20)
    end
    b.title:SetText(title or "")
    -- what the speaker button reads: the title and every narrative row, each in its language
    local segs = {}
    local lang = ns.Lang()
    if title and title ~= "" then segs[1] = { text = title .. ".", lang = lang, optional = true } end
    for _, r in ipairs(rows) do
        if r.speak then segs[#segs + 1] = { text = r.text, lang = r.speak, audio = r.audio } end
    end
    b.segments = segs
    b.speak:SetShown(ns.Speech:CanRead() and #segs > 1)
    if b.speak:IsShown() then b.title:SetWidth(b.title:GetWidth() - 18) end
    local h = 6 + math.max(16, b.title:GetStringHeight() or 16)
    local prev = b.title
    for i, r in ipairs(rows) do
        local fs = b.lines[i]
        if not fs then
            fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            fs:SetWordWrap(true)
            fs:SetSpacing(2)
            b.lines[i] = fs
        end
        fs:SetFontObject(r.font or "GameFontHighlight")
        local c = r.color or TEXT
        fs:SetTextColor(c[1], c[2], c[3])
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -(h + (r.gap or 5)))
        fs:SetWidth(w - 20)
        fs:SetText(r.text)
        fs:Show()
        h = h + (r.gap or 5) + (fs:GetStringHeight() or 12)
        prev = fs
    end
    h = h + 10
    b:SetHeight(h)
    return h
end

function Story:Create(parent, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(width)
    Skin.Box(f, 12)
    f.fill:SetColor(0.09, 0.065, 0.04, 0.97)
    f.edge:SetColor(0.55, 0.43, 0.22, 1)
    local paper = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    paper:SetPoint("TOPLEFT", 4, -4)
    paper:SetPoint("BOTTOMRIGHT", -4, 4)
    paper:SetTexture(Skin.MARBLE, "REPEAT", "REPEAT")
    paper:SetHorizTile(true)
    paper:SetVertTile(true)
    paper:SetVertexColor(0.32, 0.24, 0.15, 0.55)

    f.head = f:CreateFontString(nil, "OVERLAY", "ForeverQuestsFontSection")
    f.head:SetPoint("TOPLEFT", 12, -9)
    f.readAll = ns.Speech:Button(f, 18, function()
        if Story.cid then return Story:ChainItems(Story.cid), ns.ChainName(Story.cid) end
        if Story.single then return { Story:QuestItem(Story.single) }, ns.QName(Story.single) end
    end)
    f.readAll:SetPoint("TOPRIGHT", -10, -8)
    f.headLine = f:CreateTexture(nil, "ARTWORK")
    f.headLine:SetHeight(1)
    f.headLine:SetPoint("TOPLEFT", 8, -32)
    f.headLine:SetPoint("TOPRIGHT", -8, -32)
    f.headLine:SetColorTexture(1, 0.82, 0, 0.35)

    -- actions for the selected quest
    local act = CreateFrame("Frame", nil, f)
    act:SetPoint("BOTTOMLEFT", 8, 8)
    act:SetPoint("BOTTOMRIGHT", -8, 8)
    act:SetHeight(24)
    f.startBtn = ns.UI.PanelButton(act, L.STORY_SHOW_START, 150, 22)
    f.startBtn:SetPoint("LEFT", 0, 0)
    f.startBtn:SetScript("OnClick", function() if Story.selected then ns:ShowLocation(Story.selected, false) end end)
    f.endBtn = ns.UI.PanelButton(act, L.STORY_SHOW_END, 150, 22)
    f.endBtn:SetPoint("RIGHT", 0, 0)
    f.endBtn:SetScript("OnClick", function() if Story.selected then ns:ShowLocation(Story.selected, true) end end)
    f.act = act

    local scroll = ns.UI.CreateScroll(f)
    scroll:SetPoint("TOPLEFT", 6, -38)
    scroll:SetPoint("BOTTOMRIGHT", -6, 38)
    self.scroll = scroll
    self.frame = f
    self.width = width
    self.blocks = ns.UI.NewPool(BlockCreate)
    self.byQuest = {}
    f:Hide()
    self:ApplyLanguage()
    return self
end

function Story:ApplyLanguage()
    local f = self.frame
    if not f then return end
    f.head:SetText(L.STORY_PANEL)
    f.startBtn:SetText(L.STORY_SHOW_START)
    f.endBtn:SetText(L.STORY_SHOW_END)
end

local function people(id)
    local giver, taker = ns.QuestPeople(id)
    local out = {}
    if giver then out[#out + 1] = L.STORY_GIVER:format(giver) end
    if taker and taker ~= giver then out[#out + 1] = L.STORY_TAKER:format(taker) end
    return table.concat(out, "\n")
end

--- The rows of one quest, as the quest log would show them.
local function QuestRows(id)
    local q = ns.Q[id]
    local st = ns.Status(id)
    local col = ns.UI.STATUS_COLOR[st]
    local rows = {}
    local meta = ("[%d]  "):format(q[ns.F.LVL] or 0) .. ns.UI.STATUS_TEXT[st](id)
    if bit.band(q[ns.F.FLAGS] or 0, ns.FLAG_NEW) ~= 0 then meta = meta .. "  ·  " .. Color(L.TAG_FOREVER_SHORT, PURPLE) end
    rows[#rows + 1] = { text = meta, font = "GameFontNormalSmall", color = col, gap = 2 }
    local dest = ns.BridgeTo(id)
    if dest then
        rows[#rows + 1] = { text = L.BRIDGE_TAG .. ": " .. L.BRIDGE_STORY:format(ns.CatName(dest)), font = "GameFontNormalSmall", color = BRIDGE, speak = ns.Lang() }
    end
    local who = people(id)
    if who ~= "" then rows[#rows + 1] = { text = who, font = "GameFontNormalSmall", color = { 0.9, 0.78, 0.5 } } end

    local setup, outcome, original, onTurnIn, objective = ns.QuestStory(id)
    local spoil = ns.ShowSpoilers(id)
    -- a written narrative replaces the quest's own text: no objective, no original wording
    if objective and not setup then
        rows[#rows + 1] = { text = Color(L.STORY_OBJECTIVE, GOLD) .. " " .. objective, font = "GameFontHighlightSmall", color = { 1, 1, 1 }, speak = ns.Lang() }
    end
    if setup then
        rows[#rows + 1] = { text = setup, color = TEXT, gap = 8, speak = ns.Lang(), audio = "q" .. id .. "a" }
        if outcome and spoil then rows[#rows + 1] = { text = Color(L.STORY_ON_TURNIN, GOLD) .. " " .. outcome, color = TEXT, speak = ns.Lang(), audio = "q" .. id .. "b" } end
    elseif original then
        if ns.WantPT() then rows[#rows + 1] = { text = L.STORY_ORIGINAL_PT, font = "GameFontDisableSmall", color = DIM, gap = 8 } end
        rows[#rows + 1] = { text = original, color = { 0.88, 0.84, 0.74 }, gap = ns.WantPT() and 3 or 8, speak = "enUS" }
        if onTurnIn and spoil then rows[#rows + 1] = { text = Color(L.STORY_ON_TURNIN, GOLD) .. " " .. onTurnIn, color = { 0.88, 0.84, 0.74 }, speak = "enUS" } end
    elseif not objective then
        rows[#rows + 1] = { text = L.STORY_NO_TEXT, color = DIM, gap = 8 }
    end
    if not spoil and (outcome or onTurnIn) then
        rows[#rows + 1] = { text = L.STORY_HIDDEN, font = "GameFontDisableSmall", color = DIM }
    end
    return rows
end

--- Quests of the layout in the order the story is played (layer by layer).
local function StoryOrder(lay)
    local out = {}
    for li = 0, lay.depth do
        local quests = {}
        for _, nd in ipairs(lay.layers[li]) do
            if nd.quest then quests[#quests + 1] = nd.quest end
        end
        table.sort(quests, function(a, b)
            local qa, qb = ns.Q[a], ns.Q[b]
            if (qa[ns.F.REQ] or 0) ~= (qb[ns.F.REQ] or 0) then return (qa[ns.F.REQ] or 0) < (qb[ns.F.REQ] or 0) end
            return a < b
        end)
        out[#out + 1] = quests
    end
    return out
end

function Story:Render(cid, lay, focus, cat)
    local UI = ns.UI
    self.cid = cid
    self.single = (not cid) and focus or nil
    UI.ReleaseAll(self.blocks)
    wipe(self.byQuest)
    local canvas = self.scroll.child
    local w = math.max(200, (self.scroll:GetWidth() or (self.width - 12)) - 12)
    local y = 4
    local c = cid and ns.C[cid] or { cat }
    local function place(b, h)
        b:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -y)
        b:SetWidth(w)
        y = y + h + 4
    end
    local function block(title, rows, icon)
        local b = UI.Acquire(self.blocks, canvas)
        b.sel:Hide()
        b.selBar:Hide()
        b.onClick, b.onEnter, b.questID = nil, nil, nil
        place(b, FillBlock(b, w, title, icon, rows))
        return b
    end

    -- the chain (the place's own story is shown only on the map's page)
    local intro = cid and (ns.ChainLore(cid) or ns.ChainSummary(cid))
    if intro then block(L.LORE_CHAIN, { { text = intro, color = TEXT, speak = ns.Lang(), audio = cid and ("c" .. ns.C[cid][2]) } }) end

    -- ways in
    local incoming = {}
    for li = 0, lay.depth do
        for _, nd in ipairs(lay.layers[li]) do
            if nd.link and nd.link.dir == "in" then incoming[#incoming + 1] = nd.link end
        end
    end
    if #incoming > 0 then
        local rows = {}
        for _, lk in ipairs(incoming) do
            local target = lk.chain and ns.ChainName(lk.chain) or ns.QName(lk.quest)
            rows[#rows + 1] = { text = Color(ns.CatName(lk.cat) .. ": ", PURPLE) .. target, color = TEXT }
        end
        block(L.COMES_FROM, rows, "Interface\\Icons\\INV_Misc_Map02")
    end

    local firstLayer = true
    for _, quests in ipairs(StoryOrder(lay)) do
        if #quests > 1 then
            -- "ways to start" only when the entry quests really are alternatives (exclusive or
            -- breadcrumbs); otherwise they are simply done side by side
            local alternatives = firstLayer
            if alternatives then
                local inLayer = {}
                for _, id in ipairs(quests) do inLayer[id] = true end
                for _, id in ipairs(quests) do
                    local q = ns.Q[id]
                    local excl = q[ns.F.EXCL]
                    local isAlt = bit.band(q[ns.F.FLAGS] or 0, ns.FLAG_BREADCRUMB) ~= 0
                    for _, other in ipairs(excl or {}) do if inLayer[other] then isAlt = true end end
                    if not isAlt then alternatives = false break end
                end
            end
            block(alternatives and L.STORY_ENTRY or L.STORY_PARALLEL,
                { { text = alternatives and L.STORY_ENTRY_SUB or L.STORY_PARALLEL_SUB, font = "GameFontDisableSmall", color = DIM, gap = 2 } })
        end
        if #quests > 0 then firstLayer = false end
        for _, id in ipairs(quests) do
            local st = ns.Status(id)
            local b = block(ns.QName(id), QuestRows(id), function(tex) UI.SetStatusIcon(tex, st, ns.Q[id][ns.F.FLAGS]) end)
            b.questID = id
            self.byQuest[id] = b
            b.onClick = function(_, button)
                if button == "RightButton" then
                    ns:ShowLocation(id, IsShiftKeyDown())
                else
                    Story:Select(id)
                    UI:SelectQuest(id, true)
                end
            end
        end
    end

    local outs = {}
    for li = 0, lay.depth do
        for _, nd in ipairs(lay.layers[li]) do
            if nd.link and nd.link.dir == "out" then outs[#outs + 1] = nd.link end
        end
    end
    if #outs > 0 then
        local rows = {}
        for _, lk in ipairs(outs) do
            local target = lk.chain and ns.ChainName(lk.chain) or ns.QName(lk.quest)
            rows[#rows + 1] = { text = Color(ns.CatName(lk.cat) .. ": ", PURPLE) .. target .. "  " .. Color("(" .. L.NO_RETURN .. ")", DIM), color = TEXT }
        end
        block(L.STORY_CONTINUES, rows, "Interface\\Icons\\INV_Misc_Map_01")
    end

    self.scroll:SetContentSize(w, y + 8)
    self.selected = nil
    if focus and self.byQuest[focus] then
        self:Select(focus)
    else
        self.scroll:SetV(0)
        self:UpdateActions()
    end
end

function Story:UpdateActions()
    local f = self.frame
    local id = self.selected
    f.startBtn:SetEnabled(id ~= nil)
    f.endBtn:SetEnabled(id ~= nil)
end

--- Highlights a quest's block and scrolls it into view.
function Story:Select(id)
    self.selected = id
    for qid, b in pairs(self.byQuest) do
        local on = qid == id
        b.sel:SetShown(on)
        b.selBar:SetShown(on)
    end
    local b = self.byQuest[id]
    if b then
        local _, _, _, _, y = b:GetPoint()
        if y then self.scroll:SetV(-y - 8) end
    end
    self:UpdateActions()
end

-- ------------------------------------------------------------------ playlists for the player
--- The place: its "about this place" text.
function Story:ZoneItem(cat)
    local zone = cat and ns.ZoneLore(cat)
    if not zone then return nil end
    local label = L.LORE_PLACE:format(ns.CatName(cat))
    return { label = label, segments = { { text = zone, lang = ns.Lang(), audio = "z" .. cat } } }
end

--- One quest: its narrative (or its own text when there is none).
function Story:QuestItem(id)
    local segs = { { text = ns.QName(id) .. ".", lang = ns.Lang(), optional = true } }
    for _, r in ipairs(QuestRows(id)) do
        if r.speak then segs[#segs + 1] = { text = r.text, lang = r.speak, audio = r.audio } end
    end
    return { label = ns.QName(id), questID = id, segments = segs }
end

--- A whole chain: its introduction, then every quest in the order it is played.
function Story:ChainItems(cid)
    local items = {}
    local intro = ns.ChainLore(cid)
    if intro then
        items[1] = { label = ns.ChainName(cid), segments = { { text = intro, lang = ns.Lang(), audio = "c" .. ns.C[cid][2] } } }
    end
    local lay = ns.BuildChainLayout(cid)
    if #lay.nodes == 0 then lay = ns.BuildChainLayout(cid, true) end
    for _, quests in ipairs(StoryOrder(lay)) do
        for _, id in ipairs(quests) do items[#items + 1] = self:QuestItem(id) end
    end
    return items
end
