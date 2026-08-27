local CVA = _G.ClassVoiceAlert
if not CVA then return end

local cachedLSM = nil
local TTS_RATE = 0

local BLIZZARD_SOUND_PRESETS = {
    { name = "团队警报", key = "RAID_WARNING" },
    { name = "就绪确认", key = "READY_CHECK" },
    { name = "Boss 警报", key = "RAID_BOSS_EMOTE_WARNING" },
    { name = "闹钟警报 1", key = "ALARM_CLOCK_WARNING_1" },
    { name = "闹钟警报 2", key = "ALARM_CLOCK_WARNING_2" },
    { name = "闹钟警报 3", key = "ALARM_CLOCK_WARNING_3" },
    { name = "私聊提示", key = "TELL_MESSAGE" },
    { name = "地图标记", key = "MAP_PING" },
    { name = "任务完成", key = "IG_QUEST_LIST_COMPLETE" },
    { name = "寻找队伍职责确认", key = "LFG_ROLE_CHECK" },
    { name = "寻找队伍奖励", key = "LFG_REWARDS" },
    { name = "战场倒计时", key = "UI_BATTLEGROUND_COUNTDOWN_TIMER" },
    { name = "战场倒计时结束", key = "UI_BATTLEGROUND_COUNTDOWN_FINISHED" },
    { name = "史诗拾取提示", key = "UI_EPICLOOT_TOAST" },
    { name = "场景阶段完成", key = "UI_SCENARIO_STAGE_END" },
}

local CUSTOM_SOUND_MANIFEST = {
    { name = "!Wind-OnePlusSurprise", file = "!Wind-OnePlusSurprise.ogg" },
    { name = "1", file = "【露露】1.ogg" },
    { name = "2", file = "【露露】2.ogg" },
    { name = "3", file = "【露露】3.ogg" },
    { name = "3层", file = "【露露】3层.ogg" },
    { name = "3层咯", file = "【露露】3层咯.ogg" },
    { name = "4", file = "【露露】4.ogg" },
    { name = "5", file = "【露露】5.ogg" },
    { name = "54321", file = "【露露】54321.ogg" },
    { name = "BIU", file = "【露露】BIU.ogg" },
    { name = "BUFF没咯~", file = "【露露】BUFF没咯~.ogg" },
    { name = "Pirorirorin", file = "【露露】Pirorirorin.ogg" },
    { name = "Tada~", file = "【露露】Tada~.ogg" },
    { name = "Tararan", file = "【露露】Tararan.ogg" },
    { name = "Wakuwaku", file = "【露露】Wakuwaku.ogg" },
    { name = "宝宝好了", file = "【露露】宝宝好了.ogg" },
    { name = "暴击", file = "【露露】暴击.ogg" },
    { name = "爆发好了", file = "【露露】爆发好了.ogg" },
    { name = "变！身！", file = "【露露】变！身！.ogg" },
    { name = "沉默", file = "【露露】沉默.ogg" },
    { name = "橙斧好啦", file = "【露露】橙斧好啦.ogg" },
    { name = "冲冲冲", file = "【露露】冲冲冲.ogg" },
    { name = "冲鸭~", file = "【露露】冲鸭~.ogg" },
    { name = "春哥", file = "【露露】春哥.ogg" },
    { name = "春哥好了", file = "【露露】春哥好了.ogg" },
    { name = "春哥没啦~", file = "【露露】春哥没啦~.ogg" },
    { name = "大迅捷", file = "【露露】大迅捷.ogg" },
    { name = "恶龙咆哮，嗷呜~", file = "【露露】恶龙咆哮，嗷呜~.ogg" },
    { name = "风暴", file = "【露露】风暴.ogg" },
    { name = "福星高照", file = "【露露】福星高照.ogg" },
    { name = "复制", file = "【露露】复制.ogg" },
    { name = "混沌暗影", file = "【露露】混沌暗影.ogg" },
    { name = "火花", file = "【露露】火花.ogg" },
    { name = "火箭靴好了", file = "【露露】火箭靴好了.ogg" },
    { name = "火来", file = "【露露】火来.ogg" },
    { name = "急速", file = "【露露】急速.ogg" },
    { name = "捡球咯~", file = "【露露】捡球咯~.ogg" },
    { name = "减伤", file = "【露露】减伤.ogg" },
    { name = "剑来", file = "【露露】剑来.ogg" },
    { name = "结界", file = "【露露】结界.ogg" },
    { name = "结界好啦", file = "【露露】结界好啦.ogg" },
    { name = "解散宝宝", file = "【露露】解散宝宝.ogg" },
    { name = "精通", file = "【露露】精通.ogg" },
    { name = "镜像", file = "【露露】镜像.ogg" },
    { name = "狂暴好了", file = "【露露】狂暴好了.ogg" },
    { name = "狂乱", file = "【露露】狂乱.ogg" },
    { name = "狂乱好了", file = "【露露】狂乱好了.ogg" },
    { name = "冷却", file = "【露露】冷却.ogg" },
    { name = "力量触发", file = "【露露】力量触发.ogg" },
    { name = "连祷", file = "【露露】连祷.ogg" },
    { name = "烈焰好了", file = "【露露】烈焰好了.ogg" },
    { name = "龙神の剣を喰らえ！", file = "【露露】龙神の剣を喰らえ！.ogg" },
    { name = "竜が我が敌を喰らう！", file = "【露露】竜が我が敌を喰らう！.ogg" },
    { name = "乱舞", file = "【露露】乱舞.ogg" },
    { name = "乱舞断了", file = "【露露】乱舞断了.ogg" },
    { name = "盟约就绪", file = "【露露】盟约就绪.ogg" },
    { name = "猛虎好了", file = "【露露】猛虎好了.ogg" },
    { name = "敏捷触发", file = "【露露】敏捷触发.ogg" },
    { name = "你狗没啦！", file = "【露露】你狗没啦！.ogg" },
    { name = "欧皇附体", file = "【露露】欧皇附体.ogg" },
    { name = "跑快快", file = "【露露】跑快快.ogg" },
    { name = "披风好了", file = "【露露】披风好了.ogg" },
    { name = "屏障", file = "【露露】屏障.ogg" },
    { name = "破碎", file = "【露露】破碎.ogg" },
    { name = "锵锵~", file = "【露露】锵锵~.ogg" },
    { name = "群盾", file = "【露露】群盾.ogg" },
    { name = "饰品好了", file = "【露露】饰品好了.ogg" },
    { name = "手套好了", file = "【露露】手套好了.ogg" },
    { name = "无敌", file = "【露露】无敌.ogg" },
    { name = "吸血鬼", file = "【露露】吸血鬼.ogg" },
    { name = "咻~", file = "【露露】咻~.ogg" },
    { name = "续满咯", file = "【露露】续满咯.ogg" },
    { name = "迅捷", file = "【露露】迅捷.ogg" },
    { name = "呀吼~", file = "【露露】呀吼~.ogg" },
    { name = "腰带好了", file = "【露露】腰带好了.ogg" },
    { name = "移动施法", file = "【露露】移动施法.ogg" },
    { name = "有BUFF啦", file = "【露露】有BUFF啦.ogg" },
    { name = "增效", file = "【露露】增效.ogg" },
    { name = "智力触发", file = "【露露】智力触发.ogg" },
    { name = "竹子", file = "【露露】竹子.ogg" },
    { name = "祝福", file = "【露露】祝福.ogg" },
    { name = "冰封之韧", file = "【露露】冰封之韧.ogg" },
    { name = "冰龙吐息", file = "【露露】冰龙吐息.ogg" },
    { name = "冰雨", file = "【露露】冰雨.ogg" },
    { name = "冰柱好了", file = "【露露】冰柱好了.ogg" },
    { name = "补镰刀", file = "【露露】补镰刀.ogg" },
    { name = "大军好了", file = "【露露】大军好了.ogg" },
    { name = "凋零没咯", file = "【露露】凋零没咯.ogg" },
    { name = "反魔法领域", file = "【露露】反魔法领域.ogg" },
    { name = "符文刃舞", file = "【露露】符文刃舞.ogg" },
    { name = "骨盾", file = "【露露】骨盾.ogg" },
    { name = "骨盾没咯", file = "【露露】骨盾没咯.ogg" },
    { name = "天启", file = "【露露】天启.ogg" },
    { name = "邪恶突袭", file = "【露露】邪恶突袭.ogg" },
    { name = "血兽来咯！", file = "【露露】血兽来咯！.ogg" },
    { name = "血兽来咯", file = "【露露】血兽来咯.ogg" },
    { name = "血兽来啦", file = "【露露】血兽来啦.ogg" },
}

local CUSTOM_SOUND_PROVIDERS = {
    { addon = "Rurutia", root = "Interface\\AddOns\\Rurutia\\", name = "露露语音包" },
}

-- Load-order safety invariant: ONLY a successfully resolved LSM object is cached.
-- A failed/nil lookup is never cached, so a later LibSharedMedia load can recover.
function CVA:GetLSM()
    if cachedLSM then return cachedLSM end
    local libStub = _G.LibStub
    if not libStub then return nil end
    local ok, lib = pcall(libStub, "LibSharedMedia-3.0", true)
    if ok and lib then
        cachedLSM = lib
        return lib
    end
    return nil
end

function CVA:GetLSMSounds()
    local LSM = self:GetLSM()
    if not LSM then return {} end
    local ok, list = pcall(LSM.List, LSM, "sound")
    if not ok or type(list) ~= "table" then return {} end
    local result = {}
    for _, name in ipairs(list) do result[#result + 1] = name end
    table.sort(result)
    return result
end

function CVA:FetchLSMSound(name)
    if type(name) ~= "string" or name == "" then return nil end
    local LSM = self:GetLSM()
    if not LSM then return nil end
    local ok, path = pcall(LSM.Fetch, LSM, "sound", name, true)
    if ok and type(path) == "string" and path ~= "" then return path end
    return nil
end

function CVA:GetCustomSoundProvider()
    for _, provider in ipairs(CUSTOM_SOUND_PROVIDERS) do
        if C_AddOns and C_AddOns.DoesAddOnExist then
            local ok, exists = pcall(C_AddOns.DoesAddOnExist, provider.addon)
            if ok and exists then return provider end
        end
    end
    return nil
end

function CVA:GetCustomSounds()
    if not self:GetCustomSoundProvider() then return {} end
    local result = {}
    for _, entry in ipairs(CUSTOM_SOUND_MANIFEST) do
        result[#result + 1] = { name = entry.name, file = entry.file, source = "custom" }
    end
    return result
end

function CVA:GetCustomSoundEntry(name)
    if type(name) ~= "string" then return nil end
    for _, entry in ipairs(CUSTOM_SOUND_MANIFEST) do
        if entry.name == name then return entry end
    end
    return nil
end

function CVA:GetBlizzardSounds()
    local result = {}
    for _, entry in ipairs(BLIZZARD_SOUND_PRESETS) do
        local id = SOUNDKIT and SOUNDKIT[entry.key]
        if type(id) == "number" and id > 0 then
            result[#result + 1] = { name = entry.name, key = entry.key, soundKitID = id, source = "blizzard" }
        end
    end
    return result
end

function CVA:GetBlizzardSoundEntry(key)
    for _, entry in ipairs(BLIZZARD_SOUND_PRESETS) do
        if entry.key == key then return entry end
    end
    return nil
end

function CVA:GetTTSVoices()
    if not C_VoiceChat or type(C_VoiceChat.GetTtsVoices) ~= "function" then return {} end
    local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
    if not ok or type(voices) ~= "table" then return {} end
    local result = {}
    for _, voice in ipairs(voices) do
        if type(voice) == "table" and type(voice.voiceID) == "number" and type(voice.name) == "string" and voice.name ~= "" then
            result[#result + 1] = { voiceID = voice.voiceID, name = voice.name }
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function CVA:GetTTSVoice()
    local voices = self:GetTTSVoices()
    if #voices == 0 then return nil, nil end
    local global = self:GetGlobalDB()
    if type(global.ttsVoiceID) == "number" then
        for _, voice in ipairs(voices) do
            if voice.voiceID == global.ttsVoiceID then return voice.voiceID, voice.name end
        end
    end

    if C_TTSSettings and type(C_TTSSettings.GetVoiceOptionID) == "function" then
        local voiceType = 0
        if Enum and Enum.TtsVoiceType and Enum.TtsVoiceType.Standard ~= nil then voiceType = Enum.TtsVoiceType.Standard end
        local ok, preferredID = pcall(C_TTSSettings.GetVoiceOptionID, voiceType)
        if ok and type(preferredID) == "number" then
            for _, voice in ipairs(voices) do
                if voice.voiceID == preferredID then return voice.voiceID, voice.name end
            end
        end
    end
    return voices[1].voiceID, voices[1].name
end

function CVA:GetAlertSoundLabel(profile)
    if type(profile) ~= "table" then return "未配置" end
    if profile.mode == "custom" then return profile.selectedCustomSound or "选择露露语音..." end
    if profile.mode == "lsm" then return profile.selectedSound or "选择 LibSharedMedia 声音..." end
    if profile.mode == "blizzard" then
        local entry = self:GetBlizzardSoundEntry(profile.selectedBlizzardSound or "RAID_WARNING")
        return entry and entry.name or "团队警报"
    end
    return profile.ttsText or "提醒"
end

function CVA:GetAlertSourceStatus(profile)
    if type(profile) ~= "table" then return "" end
    if profile.mode == "custom" then
        return self:GetCustomSoundProvider() and "|cff00ff00露露语音包已检测|r" or "|cffffaa00未检测到露露语音包；已保留选择|r"
    elseif profile.mode == "lsm" then
        if self:GetLSM() then return string.format("|cff00ff00LSM 已检测（%d 个声音）|r", #self:GetLSMSounds()) end
        return "|cffffaa00LSM 当前不可用；已保留选择|r"
    elseif profile.mode == "tts" then
        local voiceID = self:GetTTSVoice()
        return voiceID and "" or "|cffff4444未检测到可用 TTS 语音|r"
    end
    return ""
end

function CVA:PlayDefaultWarning()
    local entry = self:GetBlizzardSoundEntry("RAID_WARNING")
    local id = entry and SOUNDKIT and SOUNDKIT[entry.key]
    if type(id) ~= "number" then return false end
    local ok, result = pcall(PlaySound, id, self:GetGlobalDB().soundChannel or "Master")
    return ok and result ~= false
end

function CVA:PlayAlert(profile, options)
    options = options or {}
    if type(profile) ~= "table" then return false end
    local showError = options.showError == true
    local channel = self:GetGlobalDB().soundChannel or "Master"
    local success = false

    if profile.mode == "custom" then
        local provider = self:GetCustomSoundProvider()
        local entry = self:GetCustomSoundEntry(profile.selectedCustomSound)
        if provider and entry then
            local ok, result = pcall(PlaySoundFile, provider.root .. entry.file, channel)
            success = ok and result ~= false
        elseif showError then
            self:Print(provider and "还没有选择露露语音。" or "未检测到露露语音包。")
        end
    elseif profile.mode == "lsm" then
        local path = self:FetchLSMSound(profile.selectedSound)
        if path then
            local ok, result = pcall(PlaySoundFile, path, channel)
            success = ok and result ~= false
        elseif showError then
            self:Print(self:GetLSM() and "还没有选择 LibSharedMedia 声音。" or "未检测到 LibSharedMedia-3.0。")
        end
    elseif profile.mode == "blizzard" then
        local entry = self:GetBlizzardSoundEntry(profile.selectedBlizzardSound or "RAID_WARNING") or self:GetBlizzardSoundEntry("RAID_WARNING")
        local id = entry and SOUNDKIT and SOUNDKIT[entry.key]
        if type(id) == "number" then
            local ok, result = pcall(PlaySound, id, channel)
            success = ok and result ~= false
        end
        if not success and showError then self:Print("暴雪内置音效播放失败。") end
    elseif profile.mode == "tts" then
        if C_VoiceChat and type(C_VoiceChat.SpeakText) == "function" then
            local voiceID = self:GetTTSVoice()
            local text = type(profile.ttsText) == "string" and strtrim(profile.ttsText) or ""
            if text == "" then text = options.defaultText or "提醒" end
            if voiceID then
                local volume = self:GetGlobalDB().ttsVolume or 100
                success = pcall(C_VoiceChat.SpeakText, voiceID, text, TTS_RATE, volume, false)
            end
        end
        if not success and showError then self:Print("TTS 播放失败或没有可用 TTS 语音。") end
    end

    if not success and options.fallback ~= false then success = self:PlayDefaultWarning() end
    return success
end
