local ADDON, ns = ...
local L = ns.L

ForeverQuests = ns -- public handle (for other addons / macros)
ns.REPO_URL = "https://github.com/SanchesIH/foreverquests"

-- Quest row field indices (see Data/Quests.lua)
local F_REQ, F_LVL, F_CAT, F_RACE, F_CLASS, F_FLAGS, F_NAME, F_OBJ = 1, 2, 3, 4, 5, 6, 7, 8
local F_SK, F_SID, F_SMAP, F_SX, F_SY = 9, 10, 11, 12, 13
local F_EK, F_EID, F_EMAP, F_EX, F_EY = 14, 15, 16, 17, 18
local F_PREALL, F_PREANY, F_CHAIN, F_EXCL, F_SORT, F_BCFOR = 19, 20, 21, 22, 23, 24
ns.F = {
    REQ = F_REQ, LVL = F_LVL, CAT = F_CAT, FLAGS = F_FLAGS, CHAIN = F_CHAIN,
    PREALL = F_PREALL, PREANY = F_PREANY, EXCL = F_EXCL, SORT = F_SORT, BCFOR = F_BCFOR,
}

ns.FLAG_REPEAT, ns.FLAG_CLASS, ns.FLAG_PROF, ns.FLAG_EVENT, ns.FLAG_ITEM, ns.FLAG_BREADCRUMB, ns.FLAG_WRIT, ns.FLAG_NEW =
    1, 2, 4, 8, 16, 32, 64, 128

local band = bit.band

local DEFAULTS = {
    showHigher = false,
    hideDone = false,
    showRepeat = false,
    otherClass = false,
    otherRace = false,
    openZone = true,
    tomtom = true,
    mapButton = true,
    minimap = true,
    minimapAngle = 215,
    lang = "auto",
    spoilerFree = false,
    storyChainView = true,
    storyView = false,
    loreCollapsed = false,
    storyPanel = true,
    pinned = {},
    ignored = {},
    collapsed = {},
    voicePT = nil,
    voiceEN = nil,
    ttsRate = 0,
    ttsVolume = 100,
    point = nil,
    size = nil,
}

-- ------------------------------------------------------------------ player
local RACE_BIT = { [2] = 1, [5] = 2, [6] = 4, [8] = 8, [96] = 16 } -- orc, undead, tauren, troll, skyborne
ns.player = { level = 1, raceBit = nil, classBit = 0 }

function ns:UpdatePlayer()
    local p = self.player
    p.level = UnitLevel("player") or 1
    local _, _, raceID = UnitRace("player")
    p.raceBit = raceID and RACE_BIT[raceID] or nil
    local _, _, classID = UnitClass("player")
    p.classBit = classID and (2 ^ (classID - 1)) or 0
end

-- ------------------------------------------------------------------ names
local titleCache = {}
local function wantPT() return ns.Lang() == "ptBR" end
ns.WantPT = wantPT

function ns.QName(id)
    local lq = wantPT() and ns.LQ and ns.LQ[id]
    if lq then return lq[1] end
    local c = titleCache[id]
    if c then return c end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
        if ok and t and t ~= "" then
            titleCache[id] = t
            return t
        end
    end
    local q = ns.Q[id]
    return q and q[F_NAME] or ("#" .. id)
end

function ns.QObjective(id)
    local lq = wantPT() and ns.LQ and ns.LQ[id]
    if lq and lq[2] then return lq[2] end
    local q = ns.Q[id]
    return q and q[F_OBJ]
end

function ns.EntityName(kind, id)
    if not id then return nil end
    if kind == 1 then return (wantPT() and ns.LN and ns.LN[id]) or ns.N[id] end
    if kind == 2 then return (wantPT() and ns.LO and ns.LO[id]) or ns.O[id] end
    if kind == 3 then
        local n
        if C_Item and C_Item.GetItemNameByID then
            local ok, r = pcall(C_Item.GetItemNameByID, id)
            if ok then n = r end
        end
        return n or ns.I[id]
    end
end

local mapNameCache = {}

--- Names come from the client and from the translation tables, so they change with the language.
function ns.ClearNameCaches()
    wipe(titleCache)
    wipe(mapNameCache)
end

function ns.MapName(uiMapID)
    if not uiMapID then return "?" end
    local c = mapNameCache[uiMapID]
    if c then return c end
    local name
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, uiMapID)
        if ok and info and info.name and info.name ~= "" then name = info.name end
    end
    name = name or ("Map " .. uiMapID)
    mapNameCache[uiMapID] = name
    return name
end

local CLASS_EN = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", nil, "Shaman", "Mage", "Warlock", nil, "Druid" }
ns.PROF_ICON = {
    [171] = "Interface\\Icons\\Trade_Alchemy", [164] = "Interface\\Icons\\Trade_BlackSmithing",
    [185] = "Interface\\Icons\\INV_Misc_Food_15", [333] = "Interface\\Icons\\Trade_Engraving",
    [202] = "Interface\\Icons\\Trade_Engineering", [129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    [356] = "Interface\\Icons\\Trade_Fishing", [182] = "Interface\\Icons\\Trade_Herbalism",
    [165] = "Interface\\Icons\\Trade_LeatherWorking", [186] = "Interface\\Icons\\Trade_Mining",
    [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", [197] = "Interface\\Icons\\Trade_Tailoring",
    [1] = "Interface\\Icons\\INV_Scroll_03",
}

--- Category kind: 1 Kalimdor, 2 Eastern Kingdoms, 3 new zones, 4 dungeon, 5 battleground, 6 other, 7 class, 8 profession
function ns.CatKind(cat)
    local m = ns.M[cat]
    return m and m[1] or 6
end

function ns.ClassOfCat(cat) return cat - 800000 end
function ns.ProfOfCat(cat) return cat - 900000 end

--- Category name. Positive = uiMapID, negative = dungeon area id, 0 = other, 8000xx class, 900xxx profession.
function ns.CatName(cat)
    if cat == 0 then return L.OTHER end
    if cat > 900000 then
        local id = cat - 900000
        return (L.PROF and L.PROF[id]) or ("Skill " .. id)
    end
    if cat > 800000 then
        local id = cat - 800000
        if GetClassInfo then
            local ok, name = pcall(GetClassInfo, id)
            if ok and name and name ~= "" then return name end
        end
        return (L.CLASS and L.CLASS[id]) or CLASS_EN[id] or ("Class " .. id)
    end
    if cat > 0 then return ns.MapName(cat) end
    local c = mapNameCache[cat]
    if c then return c end
    local name
    if C_Map and C_Map.GetAreaInfo then
        local ok, n = pcall(C_Map.GetAreaInfo, -cat)
        if ok and n and n ~= "" then name = n end
    end
    local m = ns.M[cat]
    name = name or (m and m[2]) or ("Area " .. -cat)
    mapNameCache[cat] = name
    return name
end

function ns.ChainName(cid)
    local c = ns.C[cid]
    return c and ns.QName(c[2]) or "?"
end

-- ------------------------------------------------------------------ state
local doneCache, activeCache = {}, {}
local turnedIn = {}

function ns:InvalidateStatus()
    wipe(doneCache)
    wipe(activeCache)
end

local IsCompleted = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted

function ns.IsDone(id)
    local v = doneCache[id]
    if v == nil then
        v = turnedIn[id] or (IsCompleted and IsCompleted(id)) or false
        doneCache[id] = v
    end
    return v
end

-- 0 = not in log, 1 = in progress, 2 = ready to turn in
function ns.LogState(id)
    local v = activeCache[id]
    if v ~= nil then return v end
    v = 0
    if C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) then
        v = 1
        local ready = (C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(id))
            or (C_QuestLog.IsComplete and C_QuestLog.IsComplete(id))
        if ready then v = 2 end
    end
    activeCache[id] = v
    return v
end

ns.ST = { DONE = 1, READY = 2, ACTIVE = 3, AVAILABLE = 4, LEVEL = 5, LOCKED = 6, EXCLUDED = 7, SKIPPED = 8 }
local ST = ns.ST

-- Display order: in progress first, then what can be picked up, then what is locked, completed last.
local ORDER = {
    [ST.READY] = 1, [ST.ACTIVE] = 2, [ST.AVAILABLE] = 3,
    [ST.LOCKED] = 4, [ST.LEVEL] = 5, [ST.SKIPPED] = 6, [ST.EXCLUDED] = 7, [ST.DONE] = 8,
}
function ns.StatusOrder(st) return ORDER[st] or 9 end

function ns.PrereqMet(id)
    local q = ns.Q[id]
    local all, any = q[F_PREALL], q[F_PREANY]
    if all then
        for i = 1, #all do
            local p = all[i]
            -- a step you can no longer take because you chose its alternative counts as done
            if not ns.IsDone(p) and ns.IsEligible(p) and not ns.TookOtherPath(p) then return false end
        end
    end
    if any then
        local ok, considered = false, false
        for i = 1, #any do
            if ns.IsEligible(any[i]) then
                considered = true
                if ns.IsDone(any[i]) then ok = true break end
            end
        end
        if considered and not ok then return false end
    end
    return true
end

--- True when one of the quests exclusive with this one was done or taken instead.
function ns.TookOtherPath(id)
    local q = ns.Q[id]
    local excl = q and q[F_EXCL]
    if not excl then return false end
    for i = 1, #excl do
        if ns.IsDone(excl[i]) or ns.LogState(excl[i]) > 0 then return true end
    end
    return false
end

function ns.Status(id)
    if ns.IsDone(id) then return ST.DONE end
    local log = ns.LogState(id)
    if log == 2 then return ST.READY end
    if log == 1 then return ST.ACTIVE end
    local q = ns.Q[id]
    local excl = q[F_EXCL]
    if excl then
        for i = 1, #excl do
            if ns.IsDone(excl[i]) or ns.LogState(excl[i]) > 0 then return ST.EXCLUDED end
        end
    end
    local bc = q[F_BCFOR]
    if bc and (ns.IsDone(bc) or ns.LogState(bc) > 0) then return ST.SKIPPED end
    if not ns.PrereqMet(id) then return ST.LOCKED end
    if ns.player.level < (q[F_REQ] or 0) then return ST.LEVEL end
    return ST.AVAILABLE
end

--- Race/class/category filters (independent of quest progress and level).
function ns.IsRepeatable(id)
    local q = ns.Q[id]
    return q and band(q[F_FLAGS] or 0, 1 + 64) ~= 0 or false
end

--- allowRepeat: the Repeatable section shows them whatever the option says.
function ns.IsEligible(id, allowRepeat)
    local q = ns.Q[id]
    if not q then return false end
    local db = ns.db
    local p = ns.player
    local race = q[F_RACE]
    if race and race ~= 0 and p.raceBit and not db.otherRace and band(race, p.raceBit) == 0 then return false end
    local cls = q[F_CLASS]
    if cls and cls ~= 0 and p.classBit ~= 0 and not db.otherClass and band(cls, p.classBit) == 0 then return false end
    local flags = q[F_FLAGS] or 0
    if not allowRepeat and not db.showRepeat and band(flags, 1 + 64) ~= 0 and not ns.IsDone(id) and ns.LogState(id) == 0 then return false end
    return true
end

--- Should a quest be shown given the level filter?
function ns.PassesLevel(id)
    if ns.db.showHigher then return true end
    local q = ns.Q[id]
    if (q[F_REQ] or 0) <= ns.player.level then return true end
    return ns.IsDone(id) or ns.LogState(id) > 0
end

function ns.IsVisible(id)
    return ns.IsEligible(id) and ns.PassesLevel(id)
end

-- ------------------------------------------------------------------ chain / map stats
--- Returns done, total, visibleTotal, bestStatus for a chain (eligible quests only).
function ns.ChainStats(cid)
    local c = ns.C[cid]
    local done, total, vis, hidden = 0, 0, 0, 0
    local best, bestOrder = ST.DONE, 99
    for _, id in ipairs(c[3]) do
        if ns.IsEligible(id) then
            total = total + 1
            local st = ns.Status(id)
            if st == ST.DONE then done = done + 1 end
            if st == ST.SKIPPED or st == ST.EXCLUDED then
                total = total - 1
            else
                local o = ns.StatusOrder(st)
                if o < bestOrder then best, bestOrder = st, o end
            end
            if ns.PassesLevel(id) then vis = vis + 1 else hidden = hidden + 1 end
        end
    end
    if total > 0 and done >= total then best = ST.DONE end
    return done, total, vis, best, hidden
end

function ns.ChainLevels(cid)
    local lo, hi
    for _, id in ipairs(ns.C[cid][3]) do
        if ns.IsEligible(id) then
            local l = ns.Q[id][F_LVL] or 0
            if l > 0 then
                lo = (not lo or l < lo) and l or lo
                hi = (not hi or l > hi) and l or hi
            end
        end
    end
    return lo or 0, hi or 0
end

function ns.CatStats(cat)
    local m = ns.M[cat]
    local done, total, avail = 0, 0, 0
    local function count(id)
        if ns.IsEligible(id) then
            local st = ns.Status(id)
            if st ~= ST.SKIPPED and st ~= ST.EXCLUDED then
                total = total + 1
                if st == ST.DONE then done = done + 1 end
                if st == ST.AVAILABLE then avail = avail + 1 end
            end
        end
    end
    for _, cid in ipairs(m[5]) do
        for _, id in ipairs(ns.C[cid][3]) do count(id) end
    end
    for _, id in ipairs(m[6]) do count(id) end
    return done, total, avail
end

-- ------------------------------------------------------------------ location / waypoints
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Forever Quests|r: " .. msg)
end
ns.Print = Print

function ns.QuestPoint(id, wantEnd)
    local q = ns.Q[id]
    if not q then return end
    local function start()
        if q[F_SMAP] then return q[F_SMAP], q[F_SX], q[F_SY], q[F_SK], q[F_SID], false end
    end
    local function finish()
        if q[F_EMAP] then return q[F_EMAP], q[F_EX], q[F_EY], q[F_EK], q[F_EID], true end
    end
    if wantEnd then
        local a, b, c, d, e, f = finish()
        if a then return a, b, c, d, e, f end
        return start()
    end
    local a, b, c, d, e, f = start()
    if a then return a, b, c, d, e, f end
    return finish()
end

local function OpenMapTo(mapID)
    if not WorldMapFrame or not mapID then return end
    local function setMap()
        pcall(function()
            if WorldMapFrame:GetMapID() ~= mapID then WorldMapFrame:SetMapID(mapID) end
        end)
    end
    pcall(function()
        if not WorldMapFrame:IsShown() then
            if OpenWorldMap then OpenWorldMap(mapID) else ShowUIPanel(WorldMapFrame) end
        end
        WorldMapFrame:SetMapID(mapID)
        if WorldMapFrame.Raise then WorldMapFrame:Raise() end
    end)
    -- the world map resets itself to the player's zone while opening; set our map again afterwards
    C_Timer.After(0, setMap)
    C_Timer.After(0.1, setMap)
    C_Timer.After(0.3, setMap)
end
ns.OpenMapTo = OpenMapTo

function ns:ShowLocation(id, forceEnd)
    local q = self.Q[id]
    if not q then return end
    local st = self.Status(id)
    local wantEnd = forceEnd or st == ST.ACTIVE or st == ST.READY
    local map, x, y, kind, eid, isEnd = self.QuestPoint(id, wantEnd)
    local qname = self.QName(id)
    if not map then
        Print(L.WAYPOINT_NONE:format(qname))
        return
    end
    local who = self.EntityName(kind, eid) or qname
    if kind == 3 then who = L.TT_ITEM:format(who) end
    local label = qname .. " — " .. who
    local placed = false

    if self.db.tomtom and TomTom and TomTom.AddWaypoint then
        pcall(TomTom.AddWaypoint, TomTom, map, x / 100, y / 100, { title = label, persistent = false, minimap = true, world = true, crazy = true })
        placed = true
    end
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local can = true
        if C_Map.CanSetUserWaypointOnMap then can = C_Map.CanSetUserWaypointOnMap(map) end
        if can then
            local ok = pcall(function()
                C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
                if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                end
            end)
            placed = placed or ok
        end
    end
    OpenMapTo(map)

    local link = ""
    if placed then
        link = (" |cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r"):format(map, math.floor(x * 100), math.floor(y * 100), L.OPEN_MAP)
        Print(L.WAYPOINT_SET:format(label, self.MapName(map), x, y) .. link)
    else
        Print(L.WAYPOINT_MAPONLY:format(label, self.MapName(map), x, y))
    end
end

-- ------------------------------------------------------------------ current map -> category
function ns.CategoryForMap(mapID)
    local guard = 0
    while mapID and guard < 10 do
        guard = guard + 1
        if ns.M[mapID] then return mapID end
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        if not info then return end
        mapID = info.parentMapID
    end
end

local function CurrentCategory()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    -- inside a dungeon: match by instance name against dungeon categories
    local cat = ns.CategoryForMap(mapID)
    if cat then return cat end
    local name = GetRealZoneText and GetRealZoneText()
    if name then
        for k in pairs(ns.M) do
            if k < 0 and k > -800000 and ns.CatName(k) == name then return k end
        end
    end
end

function ns.CurrentCategory()
    -- some unit/map APIs can be restricted in instances on the modern client: never let it break the UI
    local ok, cat = pcall(CurrentCategory)
    if ok then return cat end
end

-- ------------------------------------------------------------------ lore
--- Hand-written story for a zone/category, in the chosen language.
function ns.ZoneLore(cat)
    if wantPT() then return (ns.LZ and ns.LZ[cat]) or (ns.LZ_EN and ns.LZ_EN[cat]) end
    return (ns.LZ_EN and ns.LZ_EN[cat]) or (ns.LZ and ns.LZ[cat])
end

--- Hand-written intro for a chain (keyed by its title quest).
function ns.ChainLore(cid)
    local c = ns.C[cid]
    if not c then return nil end
    local id = c[2]
    if wantPT() then return (ns.LC and ns.LC[id]) or (ns.LC_EN and ns.LC_EN[id]) end
    return (ns.LC_EN and ns.LC_EN[id]) or (ns.LC and ns.LC[id])
end

--- A plain description of a chain, for the ones without a written story.
function ns.ChainSummary(cid)
    local c = ns.C[cid]
    if not c then return nil end
    local first, last
    for _, id in ipairs(c[3]) do
        if ns.IsEligible(id) then
            local r = ns.Q[id][ns.F.REQ] or 0
            if not first or r < (ns.Q[first][ns.F.REQ] or 0) then first = id end
        end
    end
    last = c[2]
    local lo, hi = ns.ChainLevels(cid)
    local n = 0
    for _, id in ipairs(c[3]) do if ns.IsEligible(id) then n = n + 1 end end
    local where = ns.CatName(c[1])
    if not first or first == last or not ns.ShowSpoilers(last) then
        return ns.L.CHAIN_SUMMARY_ONE:format(n, where, lo, hi)
    end
    return ns.L.CHAIN_SUMMARY:format(n, where, lo, hi, ns.QName(first), ns.QName(last))
end

--- Turns the game's own quest text tokens into readable text.
local sexTable = { [2] = 1, [3] = 2 }
function ns.FormatQuestText(text)
    if not text or text == "" then return nil end
    local name = UnitName("player") or ""
    local class = UnitClass("player") or ""
    local race = UnitRace("player") or ""
    local female = sexTable[UnitSex and UnitSex("player") or 2] == 2
    text = text:gsub("%$[Gg]([^:;]*):([^;]*);", function(m, f) return female and f or m end)
    text = text:gsub("%$[Bb]", "\n")
    text = text:gsub("%$[Nn]", name)
    text = text:gsub("%$[Cc]", class)
    text = text:gsub("%$[Rr]", race)
    text = text:gsub("\n%s*\n%s*\n+", "\n\n")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- The original words of the quest: what the giver says, and what they say on turn-in.
function ns.QuestOriginal(id)
    local t = ns.QT and ns.QT[id]
    if not t then return nil end
    return ns.FormatQuestText(t[1]), ns.FormatQuestText(t[2])
end

local function Place(id, wantEnd)
    local q = ns.Q[id]
    local kind, eid, map
    if wantEnd then kind, eid, map = q[14], q[15], q[16] else kind, eid, map = q[9], q[10], q[11] end
    local who = ns.EntityName(kind, eid)
    return who, map and ns.MapName(map) or nil, kind
end

--- Spoilers are on unless the player turned them off, and a quest you already finished
--- cannot be spoiled for you.
function ns.ShowSpoilers(id)
    if not ns.db.spoilerFree then return true end
    return id and ns.IsDone(id) or false
end

--- Everything the story view needs for one quest.
--- Returns: setup, outcome, original text, original turn-in text, objective.
--- "outcome" and the turn-in text are the parts that get hidden in spoiler-free mode.
function ns.QuestStory(id)
    local q = ns.Q[id]
    if not q then return end
    local function pick(a, b)
        if wantPT() then return a or b end
        return b or a
    end
    local hand = pick(ns.LQ2 and ns.LQ2[id], ns.LQ2_EN and ns.LQ2_EN[id])
    local setup, outcome
    if type(hand) == "table" then
        setup, outcome = hand[1], hand[2]
    else
        setup = hand
    end
    local original, onTurnIn = ns.QuestOriginal(id)
    local obj = ns.QObjective(id)
    if obj == "" then obj = nil end
    return setup, outcome, original, onTurnIn, obj
end

--- Who hands the quest out and who takes it back, with the map they are on.
function ns.QuestPeople(id)
    local q = ns.Q[id]
    if not q then return end
    local function one(kind, eid, map)
        if not eid then return nil end
        local who = ns.EntityName(kind, eid)
        if not who then return nil end
        if kind == 3 then who = ns.L.TT_ITEM:format(who) end
        if map then who = who .. " \194\183 " .. ns.MapName(map) end
        return who
    end
    return one(q[9], q[10], q[11]), one(q[14], q[15], q[16])
end

-- ------------------------------------------------------------------ data corrections
-- QuestieDB marks some quests as offered the moment another is accepted ("unlocks on accept"
-- on Wowhead, e.g. Shard of a Felhound / Shard of an Infernal after Fragments of the Orb of
-- Orahil). Those links were missing from the chains, so such quests showed up as standalone.
local function removeFrom(list, value)
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == value then table.remove(list, i) end
    end
end

local function hasEdge(flat, a, b)
    for i = 1, #flat, 3 do
        if flat[i] == a and flat[i + 1] == b then return true end
    end
    return false
end

function ns.ApplyDataPatches()
    if ns.patched or not ns.CHILD then return end
    ns.patched = true
    local Q, C, M = ns.Q, ns.C, ns.M
    for parent, kids in pairs(ns.CHILD) do
        local pq = Q[parent]
        local cid = pq and pq[F_CHAIN]
        local c = cid and C[cid]
        if c then
            for _, kid in ipairs(kids) do
                local kq = Q[kid]
                if kq then
                    local other = kq[F_CHAIN]
                    local oc = other and C[other]
                    local sameCat = kq[F_CAT] == c[1]
                    if other == cid then
                        c[4] = c[4] or {}
                        if not hasEdge(c[4], parent, kid) then
                            local flat = c[4]
                            flat[#flat + 1], flat[#flat + 2], flat[#flat + 3] = parent, kid, 2
                        end
                    elseif sameCat and (not oc or #oc[3] == 1) then
                        if oc then removeFrom(M[oc[1]] and M[oc[1]][5], other) end
                        removeFrom(M[kq[F_CAT]] and M[kq[F_CAT]][6], kid)
                        table.insert(c[3], kid)
                        c[4] = c[4] or {}
                        local flat = c[4]
                        flat[#flat + 1], flat[#flat + 2], flat[#flat + 3] = parent, kid, 2
                        kq[F_CHAIN] = cid
                    end
                end
            end
        end
    end
end
ns.ApplyDataPatches()

-- ------------------------------------------------------------------ bridges
-- A bridge quest has no objective of its own: it only sends you to someone in another region.
-- That is how the story moves from one map to the next, so they are marked everywhere.
local CITY_REGION = { [1454] = 1411, [1456] = 1412, [1458] = 1420, [1453] = 1429, [1455] = 1426, [1457] = 1438 }
function ns.Region(map) return map and (CITY_REGION[map] or map) end

--- Region the bridge quest takes you to, or nil when it is not a bridge.
function ns.BridgeTo(id)
    return ns.BRIDGE and ns.BRIDGE[id]
end

--- Bridges that bring you into this map, and bridges that take you out of it.
function ns.CatBridges(cat)
    ns.bridgeIndex = ns.bridgeIndex or {}
    local cached = ns.bridgeIndex[cat]
    if cached then return cached.arrive, cached.leave end
    local arrive, leave = {}, {}
    if cat > 0 and cat < 800000 and ns.BRIDGE then
        local region = ns.Region(cat)
        local m = ns.M[cat]
        local lo, hi = (m and m[3] or 1) - 4, (m and m[4] or 60) + 4
        for id, dest in pairs(ns.BRIDGE) do
            local q = ns.Q[id]
            -- only the zones' own story: class and profession errands are not how a map is reached
            local kind = q and ns.CatKind(q[F_CAT])
            local lvl = q and (q[F_LVL] or 0)
            if q and kind and kind <= 4 and lvl >= lo and lvl <= hi then
                local from = ns.Region(q[F_SMAP])
                if dest == region and from ~= region then arrive[#arrive + 1] = id end
                if from == region and dest ~= region then leave[#leave + 1] = id end
            end
        end
        local function byLevel(a, b)
            local ra, rb = ns.Q[a][F_REQ] or 0, ns.Q[b][F_REQ] or 0
            if ra ~= rb then return ra < rb end
            return a < b
        end
        table.sort(arrive, byLevel)
        table.sort(leave, byLevel)
    end
    ns.bridgeIndex[cat] = { arrive = arrive, leave = leave }
    return arrive, leave
end

-- ------------------------------------------------------------------ story order
--- Chains of a map in the order the story is told: a chain whose quests unlock another one's
--- comes first; among independent chains the lower level goes first.
function ns.ChainStoryOrder(cids)
    local inSet, member = {}, {}
    for _, cid in ipairs(cids) do
        inSet[cid] = true
        for _, id in ipairs(ns.C[cid][3]) do member[id] = cid end
    end
    local after, indeg = {}, {}
    for _, cid in ipairs(cids) do after[cid], indeg[cid] = {}, 0 end
    local function link(a, b)
        if a and b and a ~= b and inSet[a] and inSet[b] and not after[a][b] then
            after[a][b] = true
            indeg[b] = indeg[b] + 1
        end
    end
    for _, cid in ipairs(cids) do
        for _, id in ipairs(ns.C[cid][3]) do
            local q = ns.Q[id]
            for _, list in ipairs({ q[F_PREALL] or {}, q[F_PREANY] or {} }) do
                for _, p in ipairs(list) do link(member[p], cid) end
            end
        end
        local outs = ns.C[cid][5]
        if outs then
            for i = 1, #outs, 3 do link(cid, member[outs[i + 1]]) end
        end
    end
    -- chains the story reaches the map through (a link or a bridge from another map) are the
    -- map's main thread: they go before side chains of the same level band
    local first = {}
    for _, cid in ipairs(cids) do
        local c = ns.C[cid]
        local region = ns.Region(c[1])
        local entry = c[6] and #c[6] > 0
        local lo = select(1, ns.ChainLevels(cid))
        local minReq
        for _, id in ipairs(c[3]) do
            local r = ns.Q[id][F_REQ] or 0
            if not minReq or r < minReq then minReq = r end
            local dest = ns.BRIDGE and ns.BRIDGE[id]
            if dest and dest == region and ns.Region(ns.Q[id][F_SMAP]) ~= region then entry = true end
        end
        local level = (lo > 0 and lo or (minReq or 0)) - (entry and 6 or 0)
        first[cid] = level * 1000 + (entry and 0 or 500) + (minReq or lo)
    end
    local function better(a, b)
        if first[a] ~= first[b] then return first[a] < first[b] end
        return a < b
    end
    local ready, out = {}, {}
    for _, cid in ipairs(cids) do if indeg[cid] == 0 then ready[#ready + 1] = cid end end
    while #ready > 0 do
        table.sort(ready, better)
        local cid = table.remove(ready, 1)
        out[#out + 1] = cid
        for b in pairs(after[cid]) do
            indeg[b] = indeg[b] - 1
            if indeg[b] == 0 then ready[#ready + 1] = b end
        end
    end
    -- anything left is in a cycle: keep it, by level
    if #out < #cids then
        local placed = {}
        for _, cid in ipairs(out) do placed[cid] = true end
        local rest = {}
        for _, cid in ipairs(cids) do if not placed[cid] then rest[#rest + 1] = cid end end
        table.sort(rest, better)
        for _, cid in ipairs(rest) do out[#out + 1] = cid end
    end
    return out
end

--- Started = at least one quest done or in the log, and not finished.
function ns.ChainStarted(cid)
    local d, t, _, best = ns.ChainStats(cid)
    if t > 0 and d >= t then return false end
    if d > 0 then return true end
    return best == ns.ST.ACTIVE or best == ns.ST.READY
end

-- ------------------------------------------------------------------ pins / ignores
function ns.IsPinned(key) return ns.db.pinned and ns.db.pinned[key] or false end
function ns.IsIgnored(key) return ns.db.ignored and ns.db.ignored[key] or false end
function ns.TogglePin(key)
    ns.db.pinned = ns.db.pinned or {}
    ns.db.pinned[key] = not ns.db.pinned[key] or nil
end
function ns.ToggleIgnore(key)
    ns.db.ignored = ns.db.ignored or {}
    ns.db.ignored[key] = not ns.db.ignored[key] or nil
end

-- ------------------------------------------------------------------ search
function ns.Search(text)
    text = text and text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local res = {}
    if not text or #text < 2 then return res end
    local plain = true
    for id in pairs(ns.Q) do
        if ns.IsEligible(id) then
            local n = ns.QName(id)
            local en = ns.Q[id][F_NAME]
            if (n and n:lower():find(text, 1, plain)) or (en and en:lower():find(text, 1, plain)) then
                res[#res + 1] = id
            end
        end
    end
    table.sort(res, function(a, b)
        local qa, qb = ns.Q[a], ns.Q[b]
        if qa[F_REQ] ~= qb[F_REQ] then return qa[F_REQ] < qb[F_REQ] end
        return a < b
    end)
    return res
end

-- ------------------------------------------------------------------ events
local ev = CreateFrame("Frame")
ns.eventFrame = ev
local pending = false
local function ScheduleRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0.25, function()
        pending = false
        ns:InvalidateStatus()
        if ns.UI and ns.UI.frame and ns.UI.frame:IsShown() then ns.UI:Refresh() end
    end)
end
ns.ScheduleRefresh = ScheduleRefresh

ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            ForeverQuestsDB = ForeverQuestsDB or {}
            for k, v in pairs(DEFAULTS) do
                if ForeverQuestsDB[k] == nil then ForeverQuestsDB[k] = v end
            end
            ns.db = ForeverQuestsDB
            ns.ApplyLanguage()
        elseif arg1 == "Blizzard_WorldMap" and ns.UI then
            ns.UI:SetupMapButton()
        end
    elseif event == "PLAYER_LOGIN" then
        ns:UpdatePlayer()
        for _, e in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_LOG_UPDATE",
            "PLAYER_LEVEL_UP", "UNIT_QUEST_LOG_CHANGED", "QUEST_DATA_LOAD_RESULT" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
        if ns.UI then
            ns.UI:SetupMapButton()
            ns.UI:SetupMinimapButton()
        end
        if UnitFactionGroup("player") ~= "Horde" then
            Print(L.NOT_HORDE)
        end
    elseif event == "QUEST_TURNED_IN" then
        if arg1 then turnedIn[arg1] = true end
        ScheduleRefresh()
    elseif event == "PLAYER_LEVEL_UP" then
        ns:UpdatePlayer()
        if arg1 then ns.player.level = arg1 end
        ScheduleRefresh()
    elseif event == "UNIT_QUEST_LOG_CHANGED" then
        if arg1 == "player" then ScheduleRefresh() end
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        if arg1 then titleCache[arg1] = nil end
    else
        ScheduleRefresh()
    end
end)

-- ------------------------------------------------------------------ slash + compartment
SLASH_FOREVERQUESTS1 = "/fq"
SLASH_FOREVERQUESTS2 = "/foreverquests"
SlashCmdList.FOREVERQUESTS = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", "")
    if msg == "reset" then
        ns.db.point, ns.db.size = nil, nil
        ns.UI:ResetPosition()
        ns.UI:Show()
    elseif msg == "zona" or msg == "zone" then
        ns.UI:Show()
        ns.UI:OpenCurrentZone()
    elseif msg == "help" or msg == "ajuda" or msg == "?" then
        Print(L.HELP)
    else
        ns.UI:Toggle()
    end
end

function ForeverQuests_OnAddonCompartmentClick()
    ns.UI:Toggle()
end

function ForeverQuests_OnAddonCompartmentEnter(_, button)
    local owner = button or (MouseIsOver and AddonCompartmentFrame) or UIParent
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(L.TITLE)
    GameTooltip:AddLine(L.COMPARTMENT_TT, 1, 1, 1)
    GameTooltip:Show()
end

function ForeverQuests_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

BINDING_HEADER_FOREVERQUESTS = "Forever Quests"
BINDING_NAME_FOREVERQUESTS_TOGGLE = L.TITLE
