local _, ns = ...
local L = ns.L
local Skin = ns.Skin
local Speech = ns.Speech

-- The narration player: a small window of its own, so the story keeps playing (and can be
-- controlled) after the journal is closed. It reads the place, the selected quest or the
-- whole chain of whatever the journal last showed.
local Player = {}
ns.Player = Player

local function fmt(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

local function ctxButton(parent, onClick)
    local b = ns.UI.PanelButton(parent, "", 92, 20)
    local fs = b:GetFontString()
    if fs then
        fs:SetFontObject("GameFontNormalSmall")
        fs:SetWidth(84)
        fs:SetWordWrap(false)
    end
    b:SetScript("OnClick", onClick)
    return b
end

local function transport(parent, atlas, file, tip, onClick)
    local b = Skin.IconButton(parent, 22, atlas, file, tip)
    b:SetScript("OnClick", onClick)
    return b
end

function Player:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "ForeverQuestsPlayer", UIParent)
    f:SetSize(310, 138)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.playerPoint = { p, rp, x, y }
    end)
    Skin.Box(f, 12)
    f.fill:SetColor(0.06, 0.045, 0.03, 0.96)
    f.edge:SetColor(0.6, 0.48, 0.25, 1)
    local pt = ns.db and ns.db.playerPoint
    if pt then f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190) end

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(18, 18)
    f.icon:SetPoint("TOPLEFT", 10, -8)
    Skin.SetIcon(f.icon, Speech.SPEAKER_ATLAS, Speech.SPEAKER_FILE)
    f.title = f:CreateFontString(nil, "OVERLAY", "ForeverQuestsFontTileSmall")
    f.title:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    f.title:SetPoint("RIGHT", f, "RIGHT", -30, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    local close = Skin.IconButton(f, 16, nil, "Interface\\Buttons\\UI-StopButton", function() return L.PLAYER_CLOSE end)
    close:SetPoint("TOPRIGHT", -8, -9)
    close:SetScript("OnClick", function()
        Speech:Stop()
        f:Hide()
    end)

    f.now = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.now:SetPoint("TOPLEFT", 12, -32)
    f.now:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.now:SetJustifyH("LEFT")
    f.now:SetWordWrap(false)

    f.bar = Skin.ProgressBar(f, 5)
    f.bar:SetPoint("TOPLEFT", 12, -50)
    f.bar:SetPoint("RIGHT", f, "RIGHT", -74, 0)
    f.bar.text:Hide()
    f.time = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.time:SetPoint("LEFT", f.bar, "RIGHT", 6, 0)
    f.time:SetJustifyH("LEFT")

    -- previous / play-stop / next
    f.prev = transport(f, nil, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", L.PLAYER_PREV, function() Speech:Skip(-1) end)
    f.play = ns.UI.PanelButton(f, L.PLAYER_PLAY, 90, 22)
    f.play:SetScript("OnClick", function()
        if Speech.speaking then Speech:Stop() else Speech:Resume() end
    end)
    f.next = transport(f, nil, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", L.PLAYER_NEXT, function() Speech:Skip(1) end)
    f.play:SetPoint("TOP", f, "TOP", 0, -62)
    f.prev:SetPoint("RIGHT", f.play, "LEFT", -6, 0)
    f.next:SetPoint("LEFT", f.play, "RIGHT", 6, 0)

    -- what to read: the place, the selected quest, the whole chain
    f.zone = ctxButton(f, function() Player:PlayZone() end)
    f.quest = ctxButton(f, function() Player:PlayQuest() end)
    f.chain = ctxButton(f, function() Player:PlayChain() end)
    f.zone:SetPoint("BOTTOMLEFT", 10, 10)
    f.quest:SetPoint("LEFT", f.zone, "RIGHT", 6, 0)
    f.chain:SetPoint("LEFT", f.quest, "RIGHT", 6, 0)

    f:SetScript("OnUpdate", function(self, elapsed)
        self.acc = (self.acc or 0) + elapsed
        if self.acc < 0.2 then return end
        self.acc = 0
        Player:UpdateProgress()
    end)
    f:Hide()
    self.frame = f
    Speech.onChange = function() Player:Update() end
end

function Player:Context()
    return (ns.UI and ns.UI.playCtx) or {}
end

function Player:PlayZone()
    local ctx = self:Context()
    local item = ctx.cat and ns.Story:ZoneItem(ctx.cat)
    if item then Speech:Play({ item }, item.label) end
end

function Player:PlayQuest()
    local ctx = self:Context()
    if ctx.quest then Speech:Play({ ns.Story:QuestItem(ctx.quest) }, ns.QName(ctx.quest)) end
end

function Player:PlayChain()
    local ctx = self:Context()
    if not ctx.cid then return end
    local items = ns.Story:ChainItems(ctx.cid)
    -- start at the selected quest when there is one
    local start = 1
    for i, it in ipairs(items) do
        if ctx.quest and it.questID == ctx.quest then start = i end
    end
    Speech:Play(items, ns.ChainName(ctx.cid), start)
end

function Player:Update()
    local f = self.frame
    if not f then return end
    f.title:SetText(Speech.title or L.PLAYER_TITLE)
    local n, i = #Speech.items, Speech.index
    local item = Speech.items[i]
    if n == 0 then
        f.now:SetText(L.PLAYER_EMPTY)
    elseif Speech.finished then
        f.now:SetText(L.PLAYER_DONE)
    else
        f.now:SetText((n > 1 and ("%d/%d  ·  "):format(i, n) or "") .. (item and item.label or ""))
    end
    -- the middle button shows what it will do: stop while playing, play otherwise
    f.play:SetText(Speech.speaking and L.PLAYER_STOP or L.PLAYER_PLAY)
    f.play:SetEnabled(n > 0)
    f.prev:SetEnabled(n > 1 and i > 1)
    f.next:SetEnabled(n > 1 and i < n)
    local ctx = self:Context()
    f.zone:SetText(L.PLAYER_ZONE)
    f.quest:SetText(L.PLAYER_QUEST)
    f.chain:SetText(L.PLAYER_CHAIN)
    f.zone:SetEnabled(ctx.cat ~= nil and ns.ZoneLore(ctx.cat) ~= nil)
    f.quest:SetEnabled(ctx.quest ~= nil)
    f.chain:SetEnabled(ctx.cid ~= nil)
    self:UpdateProgress()
end

function Player:UpdateProgress()
    local f = self.frame
    if not f then return end
    local start, dur = Speech.clipStart, Speech.clipDur
    if Speech.speaking and start and dur and dur > 0 and GetTime then
        local el = math.min(dur, GetTime() - start)
        f.bar:SetMinMaxValues(0, dur)
        f.bar:SetValue(el)
        f.bar:SetStatusBarColor(0.85, 0.65, 0.1)
        f.time:SetText(fmt(el) .. " / " .. fmt(dur))
    else
        local n = #Speech.items
        f.bar:SetMinMaxValues(0, math.max(1, n))
        f.bar:SetValue(Speech.finished and n or math.max(0, Speech.index - 1))
        f.time:SetText("")
    end
end

function Player:Show()
    self:Create()
    self.frame:Show()
    self:Update()
end

function Player:Toggle()
    self:Create()
    if self.frame:IsShown() then self.frame:Hide() else self:Show() end
end
