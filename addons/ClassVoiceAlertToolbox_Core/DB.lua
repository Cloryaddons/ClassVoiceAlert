local CVA = _G.ClassVoiceAlert
if not CVA then return end

local GLOBAL_DEFAULTS = {
    soundChannel = "Master",
    ttsVoiceID = nil,
    ttsVolume = 100,
}

local VALID_CHANNELS = {
    Master = true, SFX = true, Music = true, Ambience = true, Dialog = true,
}

local function EnsureDB()
    if type(ClassVoiceAlertDB) ~= "table" then ClassVoiceAlertDB = {} end
    local db = ClassVoiceAlertDB
    if type(db.schemaVersion) ~= "number" then db.schemaVersion = 1 end
    if type(db.global) ~= "table" then db.global = {} end
    if type(db.modules) ~= "table" then db.modules = {} end
    if type(db.migrations) ~= "table" then db.migrations = {} end
    CVA:CopyDefaults(db.global, GLOBAL_DEFAULTS)

    if not VALID_CHANNELS[db.global.soundChannel] then db.global.soundChannel = "Master" end
    if type(db.global.ttsVoiceID) ~= "number" then db.global.ttsVoiceID = nil end
    db.global.ttsVolume = math.floor(CVA:ClampNumber(db.global.ttsVolume, 0, 100, 100) + 0.5)
    CVA.db = db
    return db
end

function CVA:GetDB()
    return EnsureDB()
end

function CVA:GetGlobalDB()
    return EnsureDB().global
end

function CVA:GetModuleDB(classID, moduleID, defaults)
    assert(type(classID) == "string" and classID ~= "", "classID required")
    assert(type(moduleID) == "string" and moduleID ~= "", "moduleID required")
    local root = EnsureDB().modules
    if type(root[classID]) ~= "table" then root[classID] = {} end
    if type(root[classID][moduleID]) ~= "table" then root[classID][moduleID] = {} end
    local result = root[classID][moduleID]
    if type(defaults) == "table" then CVA:CopyDefaults(result, defaults) end
    return result
end

-- Modules can offer their old addon-level audio settings during the migration
-- window. Lower priority wins (Bone Shield uses 10, DnD uses 20). The core
-- applies the best candidate, then freezes the migration at PLAYER_LOGIN.
function CVA:OfferLegacyGlobalSettings(sourceName, priority, legacy)
    local root = EnsureDB()
    if root.migrations.globalAudioV1 then return false end
    if type(legacy) ~= "table" then return false end
    priority = tonumber(priority) or 100

    local candidate = self._legacyGlobalCandidate
    if candidate and candidate.priority <= priority then return false end

    candidate = {
        source = tostring(sourceName or "unknown"),
        priority = priority,
        soundChannel = legacy.soundChannel,
        ttsVoiceID = legacy.ttsVoiceID,
        ttsVolume = legacy.ttsVolume,
    }
    self._legacyGlobalCandidate = candidate

    local g = root.global
    if VALID_CHANNELS[candidate.soundChannel] then g.soundChannel = candidate.soundChannel end
    if type(candidate.ttsVoiceID) == "number" then g.ttsVoiceID = candidate.ttsVoiceID end
    if candidate.ttsVolume ~= nil then
        g.ttsVolume = math.floor(self:ClampNumber(candidate.ttsVolume, 0, 100, 100) + 0.5)
    end
    return true
end

function CVA:FinalizeLegacyGlobalMigration()
    local root = EnsureDB()
    if root.migrations.globalAudioV1 then return end
    root.migrations.globalAudioV1 = true
    root.migrations.globalAudioSource = self._legacyGlobalCandidate and self._legacyGlobalCandidate.source or "defaults"
end

function CVA:NormalizeAlertProfile(profile, spec)
    if type(profile) ~= "table" then return end
    spec = spec or {}
    if type(profile.enabled) ~= "boolean" then profile.enabled = spec.defaultEnabled ~= false end

    local minWarn = math.ceil(tonumber(spec.minWarnBefore) or 0)
    local maxWarn = math.floor(tonumber(spec.maxWarnBefore) or 60)
    if maxWarn < minWarn then maxWarn = minWarn end
    local defaultWarn = self:NormalizeWarningSeconds(spec.defaultWarnBefore, minWarn, maxWarn, minWarn)
    profile.warnBefore = self:NormalizeWarningSeconds(profile.warnBefore, minWarn, maxWarn, defaultWarn)

    if profile.mode ~= "custom" and profile.mode ~= "lsm" and profile.mode ~= "tts" and profile.mode ~= "blizzard" then
        profile.mode = spec.defaultMode or "blizzard"
    end
    if type(profile.selectedBlizzardSound) ~= "string" or profile.selectedBlizzardSound == "" then
        profile.selectedBlizzardSound = "RAID_WARNING"
    end
    local defaultText = spec.defaultText or "提醒"
    if type(profile.ttsText) ~= "string" or strtrim(profile.ttsText) == "" then profile.ttsText = defaultText end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == CVA.ADDON_NAME then EnsureDB() end
    elseif event == "PLAYER_LOGIN" then
        CVA:FinalizeLegacyGlobalMigration()
    end
end)
