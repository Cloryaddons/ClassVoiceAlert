local ADDON_NAME = ...
local CVA = _G.ClassVoiceAlert
if not CVA then return end
local DVA = CreateFrame("Frame")
local PREFIX = "|cffc41e3a[DnDVoiceAlert]|r "
local CLASS_ID, MODULE_ID = "DEATHKNIGHT", "dnd"

local SPELL_DEATH_AND_DECAY=43265
local SPELL_CLEAVING_STRIKES=316916
local AURA_DND_GROUND=43265
local AURA_CLEAVING_STRIKES=188290
local GROUND_DURATION=10.0
local STICKY_DURATION=4.0
local INIT_IGNORE_WINDOW=0.75
local ROLLOVER_PAIR_WINDOW=0.45
local GROUND_END_GUARD=0.60
local STICKY_END_EVENT_GUARD=0.15

local LOC_INSIDE="INSIDE"
local LOC_OUTSIDE_STICKY="OUTSIDE_STICKY"
local LOC_OUTSIDE_EMPTY="OUTSIDE_EMPTY"

local BUFF_VIEWER_NAME="BuffIconCooldownViewer"
local DND_BUFF_COOLDOWN_ID=50002

local defaults={enabled=true,debug=false,alerts={
    enter={enabled=false,warnBefore=1.0,mode="blizzard",selectedSound=nil,selectedCustomSound=nil,selectedBlizzardSound="RAID_WARNING",ttsText="快进凋零地面"},
    recast={enabled=true,warnBefore=1.0,mode="blizzard",selectedSound=nil,selectedCustomSound="凋零没咯",selectedBlizzardSound="RAID_WARNING",ttsText="快补凋零地面"},
}}
local db
local state={
    groundActive=false,groundStart=nil,groundExpire=nil,
    location=LOC_OUTSIDE_EMPTY,
    insideGround=false,benefitObserved=false,
    stickyActive=false,stickyStart=nil,stickyExpire=nil,stickySource=nil,
    lastStickyExpiredAt=nil,
    enterWarned=false,recastWarned=false,
    pendingRolloverAt=nil,lastBenefitClearAt=nil
}
local timers={ground=nil,stickyExpire=nil,enterWarn=nil,recastWarn=nil,rolloverConfirm=nil}
local hookedItems=setmetatable({}, {__mode="k"})

-- A CLEAR/SET mutation and an UPDATED callback can occur during the same
-- Blizzard aura-processing pass. Only an UPDATED callback from a later pass
-- is allowed to mean "the player re-entered DnD".
local mutationEpoch=0
local mutationOpen=false

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg)) end
local function Debug(msg) if db and db.debug then Print("|cffaaaaaaDEBUG:|r " .. tostring(msg)) end end
local function IsBloodDK() local _,class=UnitClass("player"); if class~="DEATHKNIGHT" then return false end local spec=GetSpecialization(); return spec and GetSpecializationInfo(spec)==250 or false end
local function HasCleavingStrikes()
    if C_SpellBook and type(C_SpellBook.IsSpellKnown)=="function" then
        local ok,known=pcall(C_SpellBook.IsSpellKnown,SPELL_CLEAVING_STRIKES)
        if ok then return known==true end
    end
    if type(IsPlayerSpell)=="function" then
        local ok,known=pcall(IsPlayerSpell,SPELL_CLEAVING_STRIKES)
        if ok then return known==true end
    end
    -- If the spellbook API cannot be queried, preserve the established
    -- 4-second behavior rather than generating false immediate alerts.
    return true
end
local function CanRead(value) if canaccessvalue then local ok,r=pcall(canaccessvalue,value); if ok then return r end end if issecretvalue then local ok,s=pcall(issecretvalue,value); if ok then return not s end end return true end
local function SafeNumber(value) if value==nil or not CanRead(value) then return nil end return type(value)=="number" and value or nil end
local function CancelTimer(key) local timer=timers[key]; if timer and timer.Cancel then timer:Cancel() end timers[key]=nil end
local function CancelAllTimers() for key in pairs(timers) do CancelTimer(key) end end
local function FormatSeconds(value) value=tonumber(value) or 0; if math.abs(value-math.floor(value+0.5))<0.001 then return string.format("%d 秒",math.floor(value+0.5)) end return string.format("%.1f 秒",value) end

local function InitializeDB()
    db=CVA:GetModuleDB(CLASS_ID,MODULE_ID,defaults)
    db.enabled=db.enabled~=false; db.debug=db.debug==true
    CVA:NormalizeAlertProfile(db.alerts.enter,{defaultEnabled=false,minWarnBefore=0,maxWarnBefore=4,defaultWarnBefore=1,warnStep=1,defaultText="快进凋零地面"})
    CVA:NormalizeAlertProfile(db.alerts.recast,{defaultEnabled=true,minWarnBefore=0,maxWarnBefore=4,defaultWarnBefore=1,warnStep=1,defaultText="快补凋零地面"})
    local legacy=_G.DnDVoiceAlertDB
    if type(legacy)=="table" and not db._legacyMigratedV1 then
        CVA:OfferLegacyGlobalSettings(ADDON_NAME,20,legacy)
        db.enabled=legacy.enabled~=false; db.debug=legacy.debug==true
        if type(legacy.alerts)=="table" then
            for _,key in ipairs({"enter","recast"}) do
                local old=legacy.alerts[key]; local p=db.alerts[key]
                if type(old)=="table" then
                    for _,field in ipairs({"enabled","warnBefore","mode","selectedSound","selectedCustomSound","selectedBlizzardSound","ttsText"}) do if old[field]~=nil then p[field]=old[field] end end
                end
            end
        end
        CVA:NormalizeAlertProfile(db.alerts.enter,{defaultEnabled=false,minWarnBefore=0,maxWarnBefore=4,defaultWarnBefore=1,warnStep=1,defaultText="快进凋零地面"})
        CVA:NormalizeAlertProfile(db.alerts.recast,{defaultEnabled=true,minWarnBefore=0,maxWarnBefore=4,defaultWarnBefore=1,warnStep=1,defaultText="快补凋零地面"})
        db._legacyMigratedV1=true
    end
    return db
end
local function GetProfile(key) return db and db.alerts and db.alerts[key] end
local function PlayProfile(key,showError,force) local p=GetProfile(key); if not p then return end if not force and (not db.enabled or not p.enabled) then return end CVA:PlayAlert(p,{showError=showError,defaultText=key=="enter" and "快进凋零地面" or "快补凋零地面"}) end

local function ClearStickyRuntime(reason)
    Debug("ClearSticky: "..tostring(reason)); CancelTimer("stickyExpire"); CancelTimer("enterWarn"); CancelTimer("recastWarn")
    state.stickyActive=false; state.stickyStart=nil; state.stickyExpire=nil; state.stickySource=nil; state.enterWarned=false; state.recastWarned=false
end
local function ResetRuntime(reason)
    Debug("ResetRuntime: "..tostring(reason)); CancelAllTimers()
    state.groundActive=false; state.groundStart=nil; state.groundExpire=nil
    state.location=LOC_OUTSIDE_EMPTY
    state.insideGround=false; state.benefitObserved=false
    state.stickyActive=false; state.stickyStart=nil; state.stickyExpire=nil; state.stickySource=nil
    state.lastStickyExpiredAt=nil
    state.enterWarned=false; state.recastWarned=false
    state.pendingRolloverAt=nil; state.lastBenefitClearAt=nil
    mutationEpoch=mutationEpoch+1; mutationOpen=false
end
local function FireEnterWarning(reason,allowWithoutSticky)
    if state.enterWarned or not db.enabled or not IsBloodDK() or not state.groundActive or state.insideGround then return end
    if not state.stickyActive and not allowWithoutSticky then return end
    local p=GetProfile("enter"); if not p or not p.enabled then return end state.enterWarned=true; Debug("ENTER warning: "..tostring(reason)); PlayProfile("enter",false)
end
local function FireRecastWarning(reason)
    if state.recastWarned or not db.enabled or not IsBloodDK() or state.groundActive then return end
    local p=GetProfile("recast"); if not p or not p.enabled then return end state.recastWarned=true; Debug("RECAST warning: "..tostring(reason)); PlayProfile("recast",false)
end
local function ScheduleWarningForCurrentPhase()
    CancelTimer("enterWarn"); CancelTimer("recastWarn"); if not state.stickyActive or not state.stickyExpire then return end local now=GetTime()
    if state.groundActive then
        local p=GetProfile("enter"); if not p or not p.enabled or state.insideGround then return end local delay=(state.stickyExpire-p.warnBefore)-now
        if delay<=0 then FireEnterWarning("threshold already reached") else timers.enterWarn=C_Timer.NewTimer(delay,function() timers.enterWarn=nil; FireEnterWarning("sticky threshold") end) end
    else
        local p=GetProfile("recast"); if not p or not p.enabled then return end local delay=(state.stickyExpire-p.warnBefore)-now
        if delay<=0 then FireRecastWarning("threshold already reached") else timers.recastWarn=C_Timer.NewTimer(delay,function() timers.recastWarn=nil; FireRecastWarning("sticky threshold") end) end
    end
end
local function OnStickyExpired()
    timers.stickyExpire=nil; if not state.stickyActive then return end

    local expiredAt=state.stickyExpire or GetTime()

    if state.groundActive then
        FireEnterWarning("sticky expired while ground active")
    else
        FireRecastWarning("sticky expired after ground ended")
    end

    state.stickyActive=false
    state.stickyStart=nil
    state.stickyExpire=nil
    state.stickySource=nil
    state.lastStickyExpiredAt=expiredAt
    state.location=LOC_OUTSIDE_EMPTY
    state.insideGround=false
    state.benefitObserved=false

    CancelTimer("enterWarn")
    CancelTimer("recastWarn")
end
local function StartSticky(startTime,source)
    startTime=tonumber(startTime) or GetTime()
    state.location=LOC_OUTSIDE_STICKY
    state.insideGround=false
    state.benefitObserved=true
    state.lastStickyExpiredAt=nil
    state.enterWarned=false
    state.recastWarned=false

    if not HasCleavingStrikes() then
        ClearStickyRuntime("Cleaving Strikes not talented")
        state.location=LOC_OUTSIDE_EMPTY
        state.insideGround=false
        state.benefitObserved=false
        if state.groundActive then
            FireEnterWarning("exit without Cleaving Strikes",true)
        else
            FireRecastWarning("ground ended without Cleaving Strikes")
        end
        return
    end

    state.stickyActive=true
    state.stickyStart=startTime
    state.stickyExpire=startTime+STICKY_DURATION
    state.stickySource=source

    CancelTimer("stickyExpire")
    timers.stickyExpire=C_Timer.NewTimer(
        math.max(0,state.stickyExpire-GetTime()),
        OnStickyExpired
    )

    Debug(string.format(
        "Sticky start %.3f -> %.3f (%s)",
        startTime,state.stickyExpire,tostring(source)
    ))
    ScheduleWarningForCurrentPhase()
end

local function OnReenteredGround(reason)
    if not state.groundActive then return end
    if state.location==LOC_INSIDE and not state.stickyActive then return end

    Debug("Re-enter ground: "..tostring(reason))

    state.pendingRolloverAt=nil
    CancelTimer("rolloverConfirm")
    ClearStickyRuntime("re-enter")

    state.location=LOC_INSIDE
    state.insideGround=true
    state.benefitObserved=true
    state.lastStickyExpiredAt=nil
end
local function OnGroundExpired(expectedExpire)
    timers.ground=nil; if not state.groundActive then return end if expectedExpire and state.groundExpire and math.abs(expectedExpire-state.groundExpire)>0.01 then return end
    state.groundActive=false; state.pendingRolloverAt=nil; CancelTimer("rolloverConfirm"); CancelTimer("enterWarn")

    -- Without Cleaving Strikes there is no 4-second grace period. The DnD
    -- bonus ends with the ground effect, so recast warning must fire now.
    if not HasCleavingStrikes() then
        ClearStickyRuntime("ground expired without Cleaving Strikes")
        state.insideGround=false
        state.benefitObserved=false
        FireRecastWarning("ground expired without Cleaving Strikes")
        return
    end

    if state.stickyActive then
        ScheduleWarningForCurrentPhase()
        return
    end

    if state.location==LOC_INSIDE or state.insideGround then
        StartSticky(state.groundExpire or GetTime(),"ground_expire")
        return
    end

    FireRecastWarning("ground expired while outside with no sticky")
end
local function BeginGround(castTime)
    ResetRuntime("new Death and Decay")
    state.groundActive=true
    state.groundStart=castTime
    state.groundExpire=castTime+GROUND_DURATION
    state.location=LOC_OUTSIDE_EMPTY
    state.insideGround=false
    state.benefitObserved=false
    local expected=state.groundExpire; timers.ground=C_Timer.NewTimer(math.max(0,expected-GetTime()),function() OnGroundExpired(expected) end); Debug(string.format("DnD cast %.3f groundExpire=%.3f",castTime,expected))
end
local function OnConfirmedExit(firstAt) if not state.groundActive then return end if state.groundExpire and (state.groundExpire-firstAt)<=GROUND_END_GUARD then return end StartSticky(firstAt,"exit") end
local function ArmRolloverCandidate(now)
    state.pendingRolloverAt=now
    CancelTimer("rolloverConfirm")
    timers.rolloverConfirm=C_Timer.NewTimer(
        ROLLOVER_PAIR_WINDOW+0.05,
        function()
            timers.rolloverConfirm=nil
            if state.pendingRolloverAt==now then
                state.pendingRolloverAt=nil
            end
        end
    )
end

local function OnBenefitRollover(now)
    if not state.groundActive or not state.groundStart then return end

    -- The first benefit rollover after casting confirms that the player is
    -- actually receiving DnD's benefit. The standalone SET at cast time is not
    -- enough because DnD may have been placed away from the player.
    if (now-state.groundStart)<INIT_IGNORE_WINDOW then
        state.location=LOC_INSIDE
        state.insideGround=true
        state.benefitObserved=true
        state.pendingRolloverAt=nil
        CancelTimer("rolloverConfirm")
        Debug("Location -> INSIDE (initial benefit rollover)")
        return
    end

    -- Ground-expiry transitions create their own CLEAR/SET activity. The
    -- 10-second ground timer is authoritative in this short window.
    if state.groundExpire and (state.groundExpire-now)<=GROUND_END_GUARD then
        state.pendingRolloverAt=nil
        CancelTimer("rolloverConfirm")
        return
    end

    -- Sticky expiry itself produces a rollover while the ground still exists.
    -- It is not movement.
    if state.location==LOC_OUTSIDE_STICKY then
        if state.stickyExpire and now >= (state.stickyExpire-STICKY_END_EVENT_GUARD) then
            state.pendingRolloverAt=nil
            CancelTimer("rolloverConfirm")
            if state.stickyActive and now >= state.stickyExpire then
                OnStickyExpired()
            end
        end
        return
    end

    -- If the local sticky timer fired just before Blizzard delivered its
    -- matching rollover, ignore that rollover instead of using it as movement.
    if state.location==LOC_OUTSIDE_EMPTY
        and state.lastStickyExpiredAt
        and math.abs(now-state.lastStickyExpiredAt)<=STICKY_END_EVENT_GUARD
    then
        state.pendingRolloverAt=nil
        CancelTimer("rolloverConfirm")
        return
    end

    local first=state.pendingRolloverAt
    if first and (now-first)>0 and (now-first)<=ROLLOVER_PAIR_WINDOW then
        state.pendingRolloverAt=nil
        CancelTimer("rolloverConfirm")

        if state.location==LOC_INSIDE then
            Debug("Location INSIDE -> OUTSIDE_STICKY (double rollover)")
            OnConfirmedExit(first)
        elseif state.location==LOC_OUTSIDE_EMPTY then
            Debug("Location OUTSIDE_EMPTY -> INSIDE (double rollover)")
            OnReenteredGround("double rollover after sticky expired")
        end
        return
    end

    -- In the trace, both leaving while inside and re-entering after sticky has
    -- fully expired are represented by TWO rollovers about 0.2-0.3s apart.
    -- The current stable location tells us which direction the transition goes.
    if state.location==LOC_INSIDE or state.location==LOC_OUTSIDE_EMPTY then
        ArmRolloverCandidate(now)
    end
end

local function ItemMatchesDnDBuff(item)
    if not item then return false end
    local cooldownID=SafeNumber(item.cooldownID)
    if cooldownID==DND_BUFF_COOLDOWN_ID then return true end
    local info=item.cooldownInfo
    if type(info)=="table" and SafeNumber(info.spellID)==SPELL_DEATH_AND_DECAY then return true end
    return false
end

local function IsHookedDnDItem(item)
    if not item or not hookedItems[item] then return false end
    local cooldownID=SafeNumber(item.cooldownID)
    if cooldownID~=nil then return cooldownID==DND_BUFF_COOLDOWN_ID end
    return true
end

local function MarkAuraMutation()
    mutationEpoch=mutationEpoch+1
    mutationOpen=true
    local epoch=mutationEpoch
    C_Timer.After(0,function()
        if mutationEpoch==epoch then mutationOpen=false end
    end)
end

local function HookDnDItem(item)
    if not item or not ItemMatchesDnDBuff(item) then return false end
    if hookedItems[item] then return true end
    hookedItems[item]=true

    if type(item.OnAuraInstanceInfoCleared)=="function" then
        hooksecurefunc(item,"OnAuraInstanceInfoCleared",function(self,auraSpellID)
            if not IsHookedDnDItem(self) then return end
            MarkAuraMutation()

            local readableAuraSpellID=SafeNumber(auraSpellID)
            if readableAuraSpellID~=nil
                and readableAuraSpellID~=AURA_CLEAVING_STRIKES
            then
                return
            end

            state.lastBenefitClearAt=GetTime()
        end)
    end

    if type(item.OnAuraInstanceInfoSet)=="function" then
        hooksecurefunc(item,"OnAuraInstanceInfoSet",function(self,auraSpellID)
            if not IsHookedDnDItem(self) then return end
            MarkAuraMutation()

            local now=GetTime()
            local readableAuraSpellID=SafeNumber(auraSpellID)

            -- Out of combat, use the readable 188290 SET as direct evidence of
            -- re-entry when we were outside and the sticky has already ended.
            if readableAuraSpellID==AURA_CLEAVING_STRIKES
                and state.groundActive
                and state.location==LOC_OUTSIDE_EMPTY
                and state.groundStart
                and (now-state.groundStart)>=INIT_IGNORE_WINDOW
            then
                state.lastBenefitClearAt=nil
                OnReenteredGround("readable 188290 SET")
                return
            end

            if readableAuraSpellID~=nil
                and readableAuraSpellID~=AURA_CLEAVING_STRIKES
            then
                state.lastBenefitClearAt=nil
                return
            end

            state.benefitObserved=true
            local clearAt=state.lastBenefitClearAt
            state.lastBenefitClearAt=nil

            if clearAt and (now-clearAt)>=0 and (now-clearAt)<=0.08 then
                OnBenefitRollover(clearAt)
                return
            end
        end)
    end

    if type(item.OnUnitAuraUpdatedEvent)=="function" then
        hooksecurefunc(item,"OnUnitAuraUpdatedEvent",function(self)
            if not IsHookedDnDItem(self) then return end
            if not state.groundActive or state.location==LOC_INSIDE then return end

            -- The trace shows the genuine fast re-entry UPDATE arriving in a
            -- later aura pass (mutationOpen=false). Ignore only an UPDATE that
            -- occurs inside the same CLEAR/SET processing pass.
            if mutationOpen then
                Debug("Ignore same-pass CDM UPDATED")
                return
            end

            OnReenteredGround("independent CDM UPDATED")
        end)
    end

    return true
end
local function ScanBuffViewer()
    local viewer=_G[BUFF_VIEWER_NAME]; if not viewer then return false end local found=false; local pool=viewer.itemFramePool
    if pool and type(pool.EnumerateActive)=="function" then
        local okEnum,iter,enumState,control=pcall(pool.EnumerateActive,pool)
        if okEnum and type(iter)=="function" then
            local okWalk=pcall(function() for item in iter,enumState,control do if HookDnDItem(item) then found=true end end end)
            if not okWalk then Debug("CDM pool enumeration failed") end
        end
    end
    if not found and type(viewer.GetChildren)=="function" then local ok,children=pcall(function() return {viewer:GetChildren()} end); if ok and children then for _,child in ipairs(children) do if HookDnDItem(child) then found=true end end end end
    return found
end
local function ScheduleBuffViewerScans(...) local delays={...}; for _,delay in ipairs(delays) do C_Timer.After(delay,ScanBuffViewer) end end

local descriptor={addon=ADDON_NAME,requiredCoreAPI=1,classID=CLASS_ID,className="死亡骑士",moduleID=MODULE_ID,moduleName="凋零地板提醒",order=20,
    description="在需要回到凋零地板或重新施放凋零时语音提醒。",enabledLabel="启用凋零提醒",
    getDB=function() if not db then InitializeDB() end return db end,
    alerts={
        {key="enter",title="回地板提醒",description="粘滞凋零即将结束且地板还在时，提醒回到地板",showEnabled=true,showWarnBefore=true,minWarnBefore=0,maxWarnBefore=4,warnStep=1,defaultText="快进凋零地面"},
        {key="recast",title="补凋零提醒",description="地板消失后，在粘滞凋零结束前提醒补凋零",showEnabled=true,showWarnBefore=true,minWarnBefore=0,maxWarnBefore=4,warnStep=1,defaultText="快补凋零地面"},
    },
    testAlert=function(key) PlayProfile(key,true,true) end,
    onModuleEnabledChanged=function(enabled) if not enabled then ResetRuntime("disabled") end end,
    onAlertChanged=function(_,field) if field=="warnBefore" or field=="enabled" then if state.stickyActive then ScheduleWarningForCurrentPhase() end end end,
}
local ok,err=CVA:RegisterModule(descriptor); if not ok then CVA:Print("凋零模块注册失败："..tostring(err)) end

DVA:RegisterEvent("ADDON_LOADED"); DVA:RegisterEvent("PLAYER_LOGIN"); DVA:RegisterEvent("PLAYER_ENTERING_WORLD"); DVA:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED"); DVA:RegisterEvent("TRAIT_CONFIG_UPDATED"); DVA:RegisterEvent("PLAYER_DEAD"); DVA:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player")
DVA:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        local loaded=...; if loaded~=ADDON_NAME then if loaded=="Blizzard_CooldownViewer" then ScheduleBuffViewerScans(0,0.25) end return end
        InitializeDB(); ScheduleBuffViewerScans(0.5,1.5); return
    end
    if not db then InitializeDB() end
    if event=="PLAYER_LOGIN" then ScheduleBuffViewerScans(1.0,2.0); return end
    if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_SPECIALIZATION_CHANGED" or event=="TRAIT_CONFIG_UPDATED" then ResetRuntime(event); ScheduleBuffViewerScans(0.25,1.0); return end
    if event=="PLAYER_DEAD" then ResetRuntime("player dead"); return end
    if event=="UNIT_SPELLCAST_SUCCEEDED" then local unit,_,spellID=...; if unit~="player" or not db.enabled or not IsBloodDK() then return end if SafeNumber(spellID)==SPELL_DEATH_AND_DECAY then BeginGround(GetTime()); ScheduleBuffViewerScans(0,0.15,0.5) end end
end)