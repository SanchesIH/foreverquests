local _, ns = ...
local L = ns.L

-- Reads the story aloud with the game's own text-to-speech, which uses the voices installed in
-- Windows. Portuguese text goes to a Brazilian Portuguese voice and English text to a British
-- English one; both can be picked in the options.
local Speech = {}
ns.Speech = Speech

local VC = C_VoiceChat

-- names Windows gives its voices (desktop and natural ones)
local MATCH = {
    ptBR = { "portugu[eê]s %(bra", "brazil", "brasil", "pt%-br", "francisca", "thalita", "antonio", "maria", "daniel" },
    enGB = { "english %(united kingdom", "united kingdom", "great britain", "british", "en%-gb", "sonia", "ryan", "libby", "maisie", "thomas", "hazel", "george", "susan" },
    en = { "english", "en%-" },
}

function Speech:Available()
    return VC and VC.SpeakText and VC.GetTtsVoices and true or false
end

--- Something can be read: recorded narration or the Windows voices.
function Speech:CanRead()
    return self:Available() or ns.AUDIO ~= nil
end

function Speech:Voices()
    if not self:Available() then return {} end
    local ok, list = pcall(VC.GetTtsVoices)
    if not ok or type(list) ~= "table" then return {} end
    return list
end

local function find(list, patterns)
    for _, pat in ipairs(patterns) do
        for _, v in ipairs(list) do
            if v.name and v.name:lower():find(pat) then return v end
        end
    end
end

--- The voice for a language: the one picked in the options, else the best match by name.
function Speech:VoiceFor(lang)
    local list = self:Voices()
    if #list == 0 then return nil end
    local saved = ns.db and (lang == "ptBR" and ns.db.voicePT or ns.db.voiceEN)
    if saved then
        for _, v in ipairs(list) do
            if v.name == saved then return v end
        end
    end
    if lang == "ptBR" then
        -- never read Portuguese with an English voice
        return find(list, MATCH.ptBR)
    end
    return find(list, MATCH.enGB) or find(list, MATCH.en) or list[1]
end

--- Cycles the voice used for a language through every installed voice.
function Speech:NextVoice(lang)
    local list = self:Voices()
    if #list == 0 then return nil end
    local cur = self:VoiceFor(lang)
    local idx = 0
    for i, v in ipairs(list) do if cur and v.voiceID == cur.voiceID then idx = i end end
    local nxt = list[idx % #list + 1]
    if lang == "ptBR" then ns.db.voicePT = nxt.name else ns.db.voiceEN = nxt.name end
    return nxt
end

local function clean(text)
    if not text then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("%s*\n+%s*", ". "):gsub("%.%.+", "."):gsub("%s+", " ")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
Speech.Clean = clean

--- Splits long text at sentence ends, so each piece is spoken in one go.
local function chunks(text, out, lang)
    local marked = text:gsub("([%.!%?])%s+", "%1\1")
    local buf = ""
    for piece in (marked .. "\1"):gmatch("(.-)\1") do
        if piece:match("%S") then
            if buf ~= "" and #buf + #piece > 280 then
                out[#out + 1] = { text = buf, lang = lang }
                buf = piece
            else
                buf = (buf == "" and piece) or (buf .. " " .. piece)
            end
        end
    end
    if buf:match("%S") then out[#out + 1] = { text = buf, lang = lang } end
end

-- ------------------------------------------------------------------ playlist
-- A playlist is a list of items { label = ..., segments = { {text, lang, audio, optional}, ... } }:
-- the place, one quest, or a whole chain (its introduction and then each quest). Playback keeps
-- going when the journal is closed; the player window (Player.lua) controls it.
local queue = {}          -- pieces of the current item still to play
local token = 0
local soundHandle
Speech.items = {}
Speech.index = 0
Speech.speaking = false

local AUDIO_DIR = "Interface\\AddOns\\ForeverQuests\\Sounds\\"
local function audioCode(lang) return lang == "ptBR" and "pt" or "en" end

--- Seconds of recorded narration for a key, or nil.
function Speech:Recorded(key, lang)
    local t = key and ns.AUDIO and ns.AUDIO[audioCode(lang)]
    return t and t[key]
end

local function changed()
    if Speech.onChange then Speech.onChange(Speech.speaking) end
end

local speakNext

--- Turns one item into playable pieces: recordings where they exist, the Windows voice for
--- the rest. When part of the item is recorded, optional pieces (titles) are skipped.
local function loadItem(item)
    wipe(queue)
    local segments = item.segments or {}
    local anyRecorded = false
    for _, seg in ipairs(segments) do
        if Speech:Recorded(seg.audio, seg.lang or ns.Lang()) then anyRecorded = true end
    end
    for _, seg in ipairs(segments) do
        local lang = seg.lang or ns.Lang()
        local dur = Speech:Recorded(seg.audio, lang)
        if dur then
            queue[#queue + 1] = { audio = seg.audio, dur = dur, lang = lang, text = seg.text }
        elseif not (anyRecorded and seg.optional) then
            local t = clean(seg.text)
            if t ~= "" then chunks(t, queue, lang) end
        end
    end
end

local function nextItem()
    Speech.index = Speech.index + 1
    local item = Speech.items[Speech.index]
    if not item then
        Speech.speaking = false
        Speech.index = #Speech.items
        Speech.finished = true
        changed()
        return
    end
    loadItem(item)
    speakNext()
end

local function playRecorded(piece)
    token = token + 1
    local mine = token
    local ok, willPlay, handle = pcall(PlaySoundFile, AUDIO_DIR .. audioCode(piece.lang) .. "\\" .. piece.audio .. ".ogg", "Dialog")
    if not ok or not willPlay then
        -- the file is not there (new files need a full game restart): fall back to the voice
        local t = clean(piece.text)
        local fallback = {}
        if t ~= "" then chunks(t, fallback, piece.lang) end
        for i = #fallback, 1, -1 do table.insert(queue, 1, fallback[i]) end
        return speakNext()
    end
    soundHandle = handle
    Speech.speaking = true
    Speech.clipStart, Speech.clipDur = GetTime and GetTime() or 0, piece.dur
    changed()
    C_Timer.After(piece.dur + 0.35, function()
        if mine == token and Speech.speaking then speakNext() end
    end)
end

speakNext = function()
    local piece = table.remove(queue, 1)
    if not piece then return nextItem() end
    if piece.audio then return playRecorded(piece) end
    token = token + 1
    Speech.clipStart, Speech.clipDur = nil, nil
    local voice = Speech:Available() and Speech:VoiceFor(piece.lang)
    if not voice then
        if not Speech.warned then
            Speech.warned = true
            ns.Print(not Speech:Available() and L.TTS_UNAVAILABLE or (piece.lang == "ptBR" and L.TTS_NO_PT or L.TTS_NO_VOICES))
        end
        return speakNext()
    end
    local rate = (ns.db and ns.db.ttsRate) or 0
    local vol = (ns.db and ns.db.ttsVolume) or 100
    -- current signature (voiceID, text, rate, volume, overlap); older clients had a
    -- destination argument before the rate
    local ok = pcall(VC.SpeakText, voice.voiceID, piece.text, rate, vol, false)
    if not ok then
        local dest = Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback or 1
        ok = pcall(VC.SpeakText, voice.voiceID, piece.text, dest, rate, vol)
    end
    if not ok then
        ns.Print(L.TTS_FAILED)
        return speakNext()
    end
    Speech.speaking = true
    changed()
end

local function halt()
    wipe(queue)
    token = token + 1
    if soundHandle and StopSound then pcall(StopSound, soundHandle, 300) end
    soundHandle = nil
    if VC and VC.StopSpeakingText then pcall(VC.StopSpeakingText) end
end

--- Plays a playlist from the start (or from item `start`), replacing whatever was playing.
function Speech:Play(items, title, start)
    halt()
    self.items = items or {}
    self.title = title
    self.finished = false
    self.warned = false
    self.index = (start or 1) - 1
    if #self.items == 0 then return end
    if ns.Player then ns.Player:Show() end
    nextItem()
end

--- Jumps to another item of the playlist (delta -1 = previous, +1 = next).
function Speech:Skip(delta)
    if #self.items == 0 then return end
    halt()
    self.finished = false
    self.index = math.max(0, math.min(#self.items - 1, self.index - 1 + delta))
    nextItem()
end

--- Plays the current item again from its start (the "play" button after a stop).
function Speech:Resume()
    if #self.items == 0 then return end
    halt()
    if self.finished then self.index = 0 end
    self.finished = false
    self.index = math.max(0, self.index - 1)
    nextItem()
end

function Speech:Stop()
    halt()
    if self.speaking then
        self.speaking = false
        changed()
    end
end

--- Old entry points: a single list of pieces becomes a one-item playlist.
function Speech:SpeakSegments(segments, label)
    self:Play({ { label = label or "", segments = segments } }, label)
end

function Speech:Speak(text, lang)
    self:SpeakSegments({ { text = text, lang = lang } })
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "VOICE_CHAT_TTS_PLAYBACK_FINISHED", "VOICE_CHAT_TTS_PLAYBACK_FAILED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function()
    if Speech.speaking and not Speech.clipDur then speakNext() end
end)

-- ------------------------------------------------------------------ the speaker button
local SPEAKER_ATLAS, SPEAKER_FILE = "chatframe-button-icon-TTS", "Interface\\Common\\VoiceChat-Speaker"
Speech.SPEAKER_ATLAS, Speech.SPEAKER_FILE = SPEAKER_ATLAS, SPEAKER_FILE

--- A small speaker button; getPlaylist returns items, title (or a plain list of pieces).
function Speech:Button(parent, size, getPlaylist)
    local b = ns.Skin.IconButton(parent, size or 16, SPEAKER_ATLAS, SPEAKER_FILE, function() return L.TTS_READ end)
    b:SetScript("OnClick", function()
        local items, title = getPlaylist()
        if not items or #items == 0 then return end
        if items[1].segments then
            Speech:Play(items, title)
        else
            Speech:SpeakSegments(items, title)
        end
    end)
    b:SetShown(self:CanRead())
    return b
end
