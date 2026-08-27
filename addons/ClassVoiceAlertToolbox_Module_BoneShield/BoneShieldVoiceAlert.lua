local ADDON_NAME = ...
local CVA = _G.ClassVoiceAlert
if not CVA then return end

local BSA = CreateFrame("Frame")
local PREFIX = "|cffc41e3a[BoneShieldAlert]|r "
local CLASS_ID, MODULE_ID = "DEATHKNIGHT", "boneshield"

local BONE_SHIELD_ID = 195181
local BONE_SHIELD_DURATION = 30
local SPELL_MARROWREND = 195182
local SPELL_DEATHS_CARESS = 195292
local SPELL_DEATH_GRIP = 49576
local SPELL_GOREFIENDS_GRASP = 108199
local TALENT_BONE_COLLECTOR = 458572
local SPELL_DANCING_RUNE_WEAPON = 49028
local TALENT_INSATIABLE_BLADE = 377637
local SPELL_REAPERS_MARK = 439843
local TALENT_GRIM_REAPER = 434905

local defaults = {
    enabled = true,
    debug = false,
    alerts = {
        expire = {
            enabled = true,
            warnBefore = 5,
            mode = "blizzard",
            selectedSound = nil,
            selectedCustomSound = nil,
            selectedBlizzardSound = "RAID_WARNING",
            ttsText = "骨盾",
        },
    },
}

local db
local warningTimer
local timerSerial = 0
local lastKnownExpiration
local lastSource = "none"

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg)) end
local function Debug(msg) if db and db.debug then Print("|cffaaaaaaDEBUG:|r " .. tostring(msg)) end end

local function IsBloodDK()
    local _, class = UnitClass("player"); if class ~= "DEATHKNIGHT" then return false end
    local spec = GetSpecialization(); if not spec then return false end
    return GetSpecializationInfo(spec) == 250
end

local function PlayerKnowsSpell(spellID)
    if IsPlayerSpell then local ok, known = pcall(IsPlayerSpell, spellID); if ok and known then return true end end
    if IsSpellKnownOrOverridesKnown then local ok, known = pcall(IsSpellKnownOrOverridesKnown, spellID); if ok and known then return true end end
    return false
end

local function InitializeDB()
    db = CVA:GetModuleDB(CLASS_ID, MODULE_ID, defaults)
    CVA:NormalizeAlertProfile(db.alerts.expire, {defaultEnabled=true,minWarnBefore=0,maxWarnBefore=BONE_SHIELD_DURATION,defaultWarnBefore=5,warnStep=1,defaultText="骨盾"})
    db.enabled = db.enabled ~= false
    db.debug = db.debug == true

    local legacy = _G.BoneShieldVoiceAlertDB
    if type(legacy) == "table" and not db._legacyMigratedV1 then
        CVA:OfferLegacyGlobalSettings(ADDON_NAME, 10, legacy)
        db.enabled = legacy.enabled ~= false
        db.debug = legacy.debug == true
        local p = db.alerts.expire
        if legacy.warnBefore ~= nil then p.warnBefore = legacy.warnBefore end
        if legacy.mode then p.mode = legacy.mode == "cdm" and "blizzard" or legacy.mode == "default" and "blizzard" or legacy.mode end
        if legacy.selectedSound ~= nil then p.selectedSound = legacy.selectedSound end
        if legacy.selectedCustomSound ~= nil then p.selectedCustomSound = legacy.selectedCustomSound end
        if legacy.selectedBlizzardSound ~= nil then p.selectedBlizzardSound = legacy.selectedBlizzardSound end
        if legacy.ttsText ~= nil then p.ttsText = legacy.ttsText end
        CVA:NormalizeAlertProfile(p, {defaultEnabled=true,minWarnBefore=0,maxWarnBefore=BONE_SHIELD_DURATION,defaultWarnBefore=5,warnStep=1,defaultText="骨盾"})
        db._legacyMigratedV1 = true
    end
    return db
end

local function Profile() return db and db.alerts and db.alerts.expire end
local function PlayAlert(showError) CVA:PlayAlert(Profile(), {showError=showError, defaultText="骨盾"}) end

local BONE_SHIELD_BUFF_VIEWERS = {"BuffIconCooldownViewer","BuffBarCooldownViewer"}
local function IsSecretValue(value)
    if not issecretvalue then return false end
    local ok, secret = pcall(issecretvalue, value); return ok and secret == true
end

local function CooldownInfoMatchesBoneShield(info)
    if type(info) ~= "table" then return false end
    local function hit(value) return type(value)=="number" and (value==BONE_SHIELD_ID or value==SPELL_MARROWREND) end
    if hit(info.spellID) or hit(info.overrideSpellID) or hit(info.overrideTooltipSpellID) or hit(info.linkedSpellID) then return true end
    if type(info.linkedSpellIDs)=="table" then for i=1,#info.linkedSpellIDs do if hit(info.linkedSpellIDs[i]) then return true end end end
    return false
end

local function ResolveBoneShieldCooldownIDs()
    local result, CV = {}, C_CooldownViewer
    if not (CV and CV.GetCooldownViewerCategorySet and CV.GetCooldownViewerCooldownInfo) then return result end
    local maxCategory = 3; local categoryEnum = Enum and Enum.CooldownViewerCategory
    if type(categoryEnum)=="table" then for _,value in pairs(categoryEnum) do if type(value)=="number" and value>maxCategory then maxCategory=value end end end
    for category=0,maxCategory do
        local okSet, cooldownIDs = pcall(CV.GetCooldownViewerCategorySet, category, true)
        if okSet and type(cooldownIDs)=="table" then
            for i=1,#cooldownIDs do
                local cooldownID=cooldownIDs[i]
                if type(cooldownID)=="number" then
                    local okInfo, info=pcall(CV.GetCooldownViewerCooldownInfo,cooldownID)
                    if okInfo and CooldownInfoMatchesBoneShield(info) then result[cooldownID]=true end
                end
            end
        end
    end
    return result
end

local function GetBoneShieldCDMState()
    local wanted=ResolveBoneShieldCooldownIDs(); if not next(wanted) then return nil end
    local sawInactive=false
    for _,viewerName in ipairs(BONE_SHIELD_BUFF_VIEWERS) do
        local viewer=_G[viewerName]; local shown=false
        if viewer and viewer.IsShown then local ok,v=pcall(viewer.IsShown,viewer); shown=ok and v==true end
        local pool=shown and viewer.itemFramePool
        if pool and pool.EnumerateActive then
            local okEnum,iter,state,control=pcall(pool.EnumerateActive,pool)
            if okEnum and type(iter)=="function" then
                for item in iter,state,control do
                    local getter=item and item.GetCooldownID
                    if getter then
                        local okID,cooldownID=pcall(getter,item)
                        if okID and type(cooldownID)=="number" and wanted[cooldownID] then
                            local active=item.isActive
                            if not IsSecretValue(active) then if active==true then return true elseif active==false then sawInactive=true end end
                        end
                    end
                end
            end
        end
    end
    if sawInactive then return false end
    return nil
end

local function CancelWarning()
    timerSerial=timerSerial+1
    if warningTimer and warningTimer.Cancel then warningTimer:Cancel() end
    warningTimer=nil
end

local function FireWarning()
    if not db.enabled or not IsBloodDK() then return end
    local state=GetBoneShieldCDMState()
    if state==false then Debug("warning suppressed: CDM reports inactive"); return end
    PlayAlert(false)
end

local function ScheduleDelay(delay,source,expiration)
    CancelWarning(); if not db.enabled or not IsBloodDK() then return end
    delay=math.max(0.05,delay); local serial=timerSerial; lastSource=source or "unknown"; lastKnownExpiration=expiration
    warningTimer=C_Timer.NewTimer(delay,function() if serial~=timerSerial then return end warningTimer=nil; FireWarning() end)
    Debug(string.format("scheduled in %.2fs; source=%s",delay,tostring(source)))
end

local function ScheduleFromRefresh(source)
    local warnBefore=CVA:NormalizeWarningSeconds(Profile().warnBefore,0,BONE_SHIELD_DURATION,5)
    ScheduleDelay(BONE_SHIELD_DURATION-warnBefore,source,GetTime()+BONE_SHIELD_DURATION)
end

local function TrySyncReadableAura(source)
    if not db.enabled or not IsBloodDK() then CancelWarning(); return false end
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false end
    local okAura,aura=pcall(C_UnitAuras.GetPlayerAuraBySpellID,BONE_SHIELD_ID); if not okAura or not aura then return false end
    local okExp,expirationTime=pcall(function() return aura.expirationTime end); if not okExp or expirationTime==nil then return false end
    if issecretvalue and issecretvalue(expirationTime) then return false end
    if type(expirationTime)~="number" or expirationTime<=0 then return false end
    local remaining=expirationTime-GetTime(); if remaining<=0 then CancelWarning(); lastKnownExpiration=nil; return true end
    local warnBefore=CVA:NormalizeWarningSeconds(Profile().warnBefore,0,BONE_SHIELD_DURATION,5); local delay=remaining-warnBefore; if delay<=0 then delay=0.15 end
    ScheduleDelay(delay,source or "readable aura sync",expirationTime); return true
end

local function IsGeneratorSpell(spellID)
    if spellID==SPELL_MARROWREND then return true,"Marrowrend" end
    if spellID==SPELL_DEATHS_CARESS then return true,"Death's Caress" end
    if PlayerKnowsSpell(TALENT_BONE_COLLECTOR) then
        if spellID==SPELL_DEATH_GRIP then return true,"Death Grip + Bone Collector" end
        if spellID==SPELL_GOREFIENDS_GRASP then return true,"Gorefiend's Grasp + Bone Collector" end
    end
    if spellID==SPELL_DANCING_RUNE_WEAPON and PlayerKnowsSpell(TALENT_INSATIABLE_BLADE) then return true,"Dancing Rune Weapon + Insatiable Blade" end
    if spellID==SPELL_REAPERS_MARK and PlayerKnowsSpell(TALENT_GRIM_REAPER) then return true,"Reaper's Mark + Grim Reaper" end
    return false
end

local function RescheduleForNewThreshold()
    if not db.enabled or not IsBloodDK() then CancelWarning(); return end
    if not TrySyncReadableAura("setting changed") and lastKnownExpiration and lastKnownExpiration>GetTime() then
        local delay=lastKnownExpiration-GetTime()-(Profile().warnBefore or 5); ScheduleDelay(math.max(0.15,delay),"setting changed",lastKnownExpiration)
    end
end

local descriptor = {
    addon=ADDON_NAME, requiredCoreAPI=1, classID=CLASS_ID, className="死亡骑士", moduleID=MODULE_ID,
    moduleName="白骨之盾提醒", order=10, description="白骨之盾即将结束时提前语音提醒。", enabledLabel="启用白骨之盾提醒",
    getDB=function() if not db then InitializeDB() end return db end,
    alerts={{key="expire",title="白骨之盾提醒",description="设置白骨之盾即将结束时的提醒。",showEnabled=false,showWarnBefore=true,minWarnBefore=0,maxWarnBefore=BONE_SHIELD_DURATION,warnStep=1,defaultText="骨盾"}},
    testAlert=function() PlayAlert(true) end,
    onModuleEnabledChanged=function(enabled) if enabled then TrySyncReadableAura("enabled") else CancelWarning() end end,
    onAlertChanged=function(_,field) if field=="warnBefore" then RescheduleForNewThreshold() end end,
}

local ok, err = CVA:RegisterModule(descriptor)
if not ok then CVA:Print("白骨之盾模块注册失败：" .. tostring(err)) end

BSA:RegisterEvent("ADDON_LOADED"); BSA:RegisterEvent("PLAYER_LOGIN"); BSA:RegisterEvent("PLAYER_ENTERING_WORLD"); BSA:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED"); BSA:RegisterEvent("TRAIT_CONFIG_UPDATED"); BSA:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED"); BSA:RegisterEvent("PLAYER_REGEN_ENABLED")
BSA:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then local loaded=...; if loaded~=ADDON_NAME then return end InitializeDB(); return end
    if not db then InitializeDB() end
    if event=="PLAYER_LOGIN" then C_Timer.After(1.0,function() if db.enabled and IsBloodDK() then TrySyncReadableAura("login") end end); return end
    if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_SPECIALIZATION_CHANGED" or event=="TRAIT_CONFIG_UPDATED" or event=="PLAYER_REGEN_ENABLED" then
        C_Timer.After(0.2,function() if not db.enabled or not IsBloodDK() then CancelWarning(); return end TrySyncReadableAura(event) end); return
    end
    if event=="UNIT_SPELLCAST_SUCCEEDED" then
        local unit,_,spellID=...; if unit~="player" or not db.enabled or not IsBloodDK() then return end
        local isGenerator,source=IsGeneratorSpell(spellID); if isGenerator then ScheduleFromRefresh(source) end
    end
end)
