local CVA = _G.ClassVoiceAlert
if not CVA then return end
local UI = CVA.UI

local soundBrowser
local browserRows = {}
local browserItems = {}
local browserFiltered = {}
local browserOffset = 0
local browserProfile
local browserSource
local browserOnChanged
local VISIBLE_ROWS = 11
local ROW_HEIGHT = 29

-- Keyboard-focus safety -------------------------------------------------------
-- A focused EditBox consumes normal keybinds (for example C) before the game
-- sees them.  If that EditBox is then hidden without releasing focus, the
-- player can appear to have "lost" ESC / character-panel / other bindings.
-- Keep all focus management in Core so feature modules do not reimplement it.
local function IsDescendantOf(object, ancestor)
    local current = object
    while current do
        if current == ancestor then return true end
        if type(current.GetParent) ~= "function" then break end
        current = current:GetParent()
    end
    return false
end

function UI:ClearKeyboardFocus(root)
    if type(GetCurrentKeyBoardFocus) ~= "function" then return false end
    local focus = GetCurrentKeyBoardFocus()
    if not focus then return false end
    if root and not IsDescendantOf(focus, root) then return false end
    if type(focus.ClearFocus) == "function" then
        focus:ClearFocus()
        return true
    end
    return false
end

local function AddSpecialFrame(frameName)
    if type(frameName) ~= "string" or frameName == "" or type(UISpecialFrames) ~= "table" then return end
    for _, existing in ipairs(UISpecialFrames) do
        if existing == frameName then return end
    end
    table.insert(UISpecialFrames, frameName)
end
UI.AddSpecialFrame = AddSpecialFrame

local function CreateLabel(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text or "")
    return fs
end
UI.CreateLabel = CreateLabel

local function BuildBrowserItems(source)
    if source == "custom" then return CVA:GetCustomSounds() end
    if source == "lsm" then
        local result = {}
        for _, name in ipairs(CVA:GetLSMSounds()) do result[#result + 1] = { name = name, source = "lsm" } end
        return result
    end
    if source == "blizzard" then return CVA:GetBlizzardSounds() end
    return {}
end

local function IsSelected(item)
    if not browserProfile or not item then return false end
    if browserSource == "custom" then return browserProfile.selectedCustomSound == item.name end
    if browserSource == "lsm" then return browserProfile.selectedSound == item.name end
    if browserSource == "blizzard" then return browserProfile.selectedBlizzardSound == item.key end
    return false
end

local function RefreshBrowserRows()
    if not soundBrowser then return end
    for i, row in ipairs(browserRows) do
        local item = browserFiltered[browserOffset + i]
        if item then
            row.item = item
            row:SetText((IsSelected(item) and "[已选] " or "") .. item.name)
            row:Show()
        else
            row.item = nil
            row:Hide()
        end
    end
    local maxOffset = math.max(0, #browserFiltered - VISIBLE_ROWS)
    soundBrowser.slider:SetMinMaxValues(0, maxOffset)
    soundBrowser.slider:SetValue(browserOffset)
    soundBrowser.count:SetText(string.format("%d 个声音", #browserFiltered))
end

local function FilterBrowser()
    if not soundBrowser then return end
    local query = strtrim(soundBrowser.search:GetText() or ""):lower()
    wipe(browserFiltered)
    for _, item in ipairs(browserItems) do
        if query == "" or tostring(item.name):lower():find(query, 1, true) then
            browserFiltered[#browserFiltered + 1] = item
        end
    end
    browserOffset = 0
    RefreshBrowserRows()
end

local function CreateSoundBrowser()
    if soundBrowser then return soundBrowser end
    local f = CreateFrame("Frame", "ClassVoiceAlertSoundBrowser", UIParent, "BackdropTemplate")
    f:SetSize(630, 440); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11,right=12,top=12,bottom=11}})
    local title = CreateLabel(f, "选择声音", 22, -18, "GameFontNormalLarge")
    f.title = title
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -5, -5)

    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 22, -52); search:SetSize(500, 28); search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", FilterBrowser)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.search = search
    local count = CreateLabel(f, "", 530, -58, "GameFontHighlightSmall"); f.count = count

    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        row:SetPoint("TOPLEFT", 22, -88 - (i - 1) * ROW_HEIGHT); row:SetSize(548, 25)
        row:SetScript("OnClick", function(self)
            local item = self.item
            if not item or not browserProfile then return end
            if browserSource == "custom" then browserProfile.selectedCustomSound = item.name
            elseif browserSource == "lsm" then browserProfile.selectedSound = item.name
            elseif browserSource == "blizzard" then browserProfile.selectedBlizzardSound = item.key end
            CVA:PlayAlert(browserProfile, {showError=true})
            if type(browserOnChanged) == "function" then browserOnChanged() end
            RefreshBrowserRows()
        end)
        browserRows[i] = row
    end

    local slider = CreateFrame("Slider", nil, f, "UIPanelScrollBarTemplate")
    slider:SetPoint("TOPLEFT", 580, -88); slider:SetPoint("BOTTOMLEFT", 580, 32); slider:SetWidth(18)
    slider:SetMinMaxValues(0,0); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged", function(_, value)
        browserOffset = math.floor((tonumber(value) or 0) + 0.5)
        RefreshBrowserRows()
    end)
    f.slider = slider
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        local _, maxOffset = slider:GetMinMaxValues()
        browserOffset = math.max(0, math.min(maxOffset, browserOffset - delta * 2))
        slider:SetValue(browserOffset)
    end)
    f:SetScript("OnHide", function(self)
        UI:ClearKeyboardFocus(self)
        browserProfile = nil
        browserSource = nil
        browserOnChanged = nil
    end)
    AddSpecialFrame("ClassVoiceAlertSoundBrowser")
    f:Hide(); soundBrowser = f; return f
end

function CVA:OpenSoundBrowser(profile, source, onChanged)
    if source == "tts" then return end
    local f = CreateSoundBrowser()
    browserProfile = profile; browserSource = source; browserOnChanged = onChanged
    local sourceName = source == "custom" and "露露语音包" or source == "lsm" and "LibSharedMedia" or "暴雪内置音效"
    f.title:SetText("选择声音 - " .. sourceName)
    f.search:SetText("")
    browserItems = BuildBrowserItems(source)
    wipe(browserFiltered)
    for _, item in ipairs(browserItems) do browserFiltered[#browserFiltered + 1] = item end
    browserOffset = 0; f.slider:SetValue(0); RefreshBrowserRows(); f:Show(); f:Raise()
end

local function ModeMenu(dropdown, profile, refresh)
    dropdown:SetupMenu(function(_, rootDescription)
        local options = {}
        if CVA:GetCustomSoundProvider() then options[#options + 1] = {"露露语音包", "custom"} end
        options[#options + 1] = {"LibSharedMedia（LSM）", "lsm"}
        options[#options + 1] = {"TTS", "tts"}
        options[#options + 1] = {"暴雪内置音效", "blizzard"}
        for _, option in ipairs(options) do
            rootDescription:CreateRadio(option[1],
                function(value) return profile.mode == value end,
                function(value) profile.mode = value; refresh() end,
                option[2])
        end
    end)
end

-- Interaction-state safety ----------------------------------------------------
-- The standard UI is hierarchical:
-- module enabled -> alert enabled -> alert detail controls.
-- A disabled parent must never leave editable child controls active.
local function SetControlEnabled(control, enabled, enabledAlpha, disabledAlpha)
    if not control then return end
    enabled = enabled and true or false

    if type(control.SetEnabled) == "function" then
        control:SetEnabled(enabled)
    elseif enabled and type(control.Enable) == "function" then
        control:Enable()
    elseif not enabled and type(control.Disable) == "function" then
        control:Disable()
    end

    if type(control.SetAlpha) == "function" then
        control:SetAlpha(enabled and (enabledAlpha or 1.0) or (disabledAlpha or 0.45))
    end
end
UI.SetControlEnabled = SetControlEnabled

local function SetVisualEnabled(region, enabled, disabledAlpha)
    if region and type(region.SetAlpha) == "function" then
        region:SetAlpha(enabled and 1.0 or (disabledAlpha or 0.55))
    end
end

function UI:BuildStandardModulePanel(parent, descriptor)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints(parent)
    local db = descriptor.getDB()
    local widgets = { alerts = {} }

    CreateLabel(panel, descriptor.moduleName, 18, -18, "GameFontNormalLarge")
    local desc = CreateLabel(panel, descriptor.description or "", 18, -47, "GameFontHighlight")
    desc:SetWidth(600); desc:SetJustifyH("LEFT"); desc:SetWordWrap(true)

    widgets.enabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    widgets.enabled:SetPoint("TOPLEFT", 14, -78); widgets.enabled:SetSize(26,26)
    widgets.enabled.text = widgets.enabled:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    widgets.enabled.text:SetPoint("LEFT", widgets.enabled, "RIGHT", 4, 0)
    widgets.enabled.text:SetText(descriptor.enabledLabel or ("启用" .. descriptor.moduleName))
    widgets.enabled:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() and true or false
        if not db.enabled and soundBrowser and soundBrowser:IsShown() then soundBrowser:Hide() end
        if type(descriptor.onModuleEnabledChanged) == "function" then descriptor.onModuleEnabledChanged(db.enabled) end
        panel:Refresh()
    end)

    local y = -124
    for _, alertSpec in ipairs(descriptor.alerts or {}) do
        local profile = db.alerts[alertSpec.key]
        local w = {}; widgets.alerts[alertSpec.key] = w
        w.title = CreateLabel(panel, alertSpec.title or alertSpec.key, 18, y, "GameFontNormalLarge")
        y = y - 29

        if alertSpec.showEnabled ~= false then
            w.enabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            w.enabled:SetPoint("TOPLEFT", 14, y); w.enabled:SetSize(26,26)
            w.enabled.text = w.enabled:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            w.enabled.text:SetPoint("LEFT", w.enabled, "RIGHT", 4, 0)
            w.enabled.text:SetText(alertSpec.description or "启用此提醒")
            w.enabled:SetScript("OnClick", function(self)
                profile.enabled = self:GetChecked() and true or false
                if not profile.enabled and browserProfile == profile and soundBrowser and soundBrowser:IsShown() then soundBrowser:Hide() end
                if type(descriptor.onAlertChanged) == "function" then descriptor.onAlertChanged(alertSpec.key, "enabled", profile.enabled) end
                panel:Refresh()
            end)
            y = y - 37
        elseif alertSpec.description and alertSpec.description ~= "" then
            w.help = CreateLabel(panel, alertSpec.description, 18, y + 1, "GameFontHighlight")
            w.help:SetWidth(600); w.help:SetJustifyH("LEFT"); y = y - 28
        end

        if alertSpec.showWarnBefore ~= false then
            local minWarn = math.ceil(tonumber(alertSpec.minWarnBefore) or 0)
            local maxWarn = math.floor(tonumber(alertSpec.maxWarnBefore) or 10)
            if maxWarn < minWarn then maxWarn = minWarn end

            w.warnLabel = CreateLabel(panel, "提前时间", 34, y, "GameFontNormal")
            w.slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
            w.slider:SetPoint("TOPLEFT", 103, y + 3); w.slider:SetWidth(178)
            w.slider:SetMinMaxValues(minWarn, maxWarn)
            w.slider:SetValueStep(1); w.slider:SetObeyStepOnDrag(true)
            w.slider.Low:SetText(tostring(minWarn)); w.slider.High:SetText(tostring(maxWarn)); w.slider.Text:SetText("")

            -- Editable integer-second value. We intentionally do not call
            -- SetNumeric(true): users may type a minus sign or decimal, then
            -- Core normalizes it on commit (ceil -> clamp).
            w.warnInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
            w.warnInput:SetPoint("TOPLEFT", 294, y + 8); w.warnInput:SetSize(48, 24)
            w.warnInput:SetAutoFocus(false); w.warnInput:SetMaxLetters(10)
            w.warnInput:SetJustifyH("CENTER"); w.warnInput:SetTextColor(1,1,1,1)
            w.warnSuffix = CreateLabel(panel, "秒", 347, y, "GameFontHighlight")

            local function RefreshWarnInput()
                local value = CVA:NormalizeWarningSeconds(profile.warnBefore, minWarn, maxWarn, minWarn)
                profile.warnBefore = value
                w.warnInput:SetText(tostring(value))
                w.warnInput:SetCursorPosition(0)
            end

            local function ApplyWarnValue(value, notify)
                local current = CVA:NormalizeWarningSeconds(profile.warnBefore, minWarn, maxWarn, minWarn)
                local normalized = CVA:NormalizeWarningSeconds(value, minWarn, maxWarn, current)
                profile.warnBefore = normalized

                w._settingWarn = true
                w.slider:SetValue(normalized)
                w.warnInput:SetText(tostring(normalized))
                w.warnInput:SetCursorPosition(0)
                w._settingWarn = false

                if notify and type(descriptor.onAlertChanged) == "function" then
                    descriptor.onAlertChanged(alertSpec.key, "warnBefore", normalized)
                end
            end

            w.slider:SetScript("OnValueChanged", function(_, value)
                if w._settingWarn then return end
                ApplyWarnValue(value, true)
            end)

            local function CommitWarnInput(self)
                local raw = strtrim(self:GetText() or "")
                local number = tonumber(raw)
                if number == nil then
                    RefreshWarnInput()
                    return
                end
                ApplyWarnValue(number, true)
            end

            w.warnInput:SetScript("OnShow", RefreshWarnInput)
            w.warnInput:SetScript("OnEnterPressed", function(self)
                -- Focus loss is the single commit path, avoiding duplicate
                -- onAlertChanged callbacks.
                self:ClearFocus()
            end)
            w.warnInput:SetScript("OnEditFocusLost", function(self)
                if w._cancelWarnEdit then
                    w._cancelWarnEdit = false
                    RefreshWarnInput()
                    return
                end
                CommitWarnInput(self)
            end)
            w.warnInput:SetScript("OnEscapePressed", function(self)
                -- Escape cancels the unfinished edit instead of committing it.
                w._cancelWarnEdit = true
                self:ClearFocus()
                RefreshWarnInput()
            end)

            w.modeLabel = CreateLabel(panel, "声音来源", 365, y, "GameFontNormal")
            w.mode = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
            w.mode:SetPoint("TOPLEFT", 435, y + 10); w.mode:SetWidth(165); w.mode:SetDefaultText("声音来源")
            y = y - 40
        else
            w.modeLabel = CreateLabel(panel, "声音来源", 34, y, "GameFontNormal")
            w.mode = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
            w.mode:SetPoint("TOPLEFT", 103, y + 10); w.mode:SetWidth(178); w.mode:SetDefaultText("声音来源")
            y = y - 40
        end

        w.sound = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        w.sound:SetPoint("TOPLEFT", 34, y); w.sound:SetSize(394, 28)
        w.sound:SetScript("OnClick", function()
            CVA:OpenSoundBrowser(profile, profile.mode, function() panel:Refresh() end)
        end)

        w.tts = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        w.tts:SetPoint("TOPLEFT", 34, y); w.tts:SetSize(394, 28); w.tts:SetAutoFocus(false); w.tts:SetMaxLetters(120); w.tts:SetTextColor(1,1,1,1)
        local function RefreshTTS()
            local text = type(profile.ttsText) == "string" and profile.ttsText or alertSpec.defaultText or "提醒"
            w.tts:SetText(text); w.tts:SetCursorPosition(0); w.tts:SetTextColor(1,1,1,1)
        end
        local function SaveTTS()
            local text = strtrim(w.tts:GetText() or "")
            if text == "" then text = alertSpec.defaultText or "提醒" end
            profile.ttsText = text; RefreshTTS()
            if type(descriptor.onAlertChanged) == "function" then descriptor.onAlertChanged(alertSpec.key, "ttsText", text) end
        end
        w.tts:SetScript("OnShow", RefreshTTS)
        w.tts:SetScript("OnEnterPressed", function(self) SaveTTS(); self:ClearFocus() end)
        w.tts:SetScript("OnEditFocusLost", SaveTTS)
        w.tts:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshTTS() end)

        w.test = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        w.test:SetPoint("TOPLEFT", 442, y); w.test:SetSize(82,28); w.test:SetText("测试")
        w.test:SetScript("OnClick", function()
            if type(descriptor.testAlert) == "function" then descriptor.testAlert(alertSpec.key) else CVA:PlayAlert(profile, {showError=true, defaultText=alertSpec.defaultText}) end
        end)
        y = y - 34
        w.status = CreateLabel(panel, "", 34, y, "GameFontHighlightSmall"); w.status:SetWidth(550); w.status:SetWordWrap(false)
        y = y - 36
        ModeMenu(w.mode, profile, function()
            if type(descriptor.onAlertChanged) == "function" then descriptor.onAlertChanged(alertSpec.key, "mode", profile.mode) end
            panel:Refresh()
        end)
    end

    function panel:Refresh()
        db = descriptor.getDB()
        local moduleEnabled = db.enabled and true or false
        widgets.enabled:SetChecked(moduleEnabled)

        for _, alertSpec in ipairs(descriptor.alerts or {}) do
            local profile = db.alerts[alertSpec.key]
            local w = widgets.alerts[alertSpec.key]
            local alertEnabled = (alertSpec.showEnabled == false) or (profile.enabled and true or false)
            local detailEnabled = moduleEnabled and alertEnabled

            -- A module-level disable locks the entire child alert. When the
            -- module is enabled, an alert's own checkbox remains usable even
            -- if that alert is currently disabled.
            if w.enabled then
                w.enabled:SetChecked(profile.enabled)
                SetControlEnabled(w.enabled, moduleEnabled, 1.0, 0.45)
                SetVisualEnabled(w.enabled.text, moduleEnabled, 0.45)
            end

            SetVisualEnabled(w.title, moduleEnabled and alertEnabled, moduleEnabled and 0.60 or 0.45)
            SetVisualEnabled(w.help, detailEnabled, 0.45)
            SetVisualEnabled(w.warnLabel, detailEnabled, 0.45)
            SetVisualEnabled(w.modeLabel, detailEnabled, 0.45)
            SetVisualEnabled(w.warnSuffix, detailEnabled, 0.45)
            SetVisualEnabled(w.status, detailEnabled, 0.45)

            if w.slider then
                local minWarn = math.ceil(tonumber(alertSpec.minWarnBefore) or 0)
                local maxWarn = math.floor(tonumber(alertSpec.maxWarnBefore) or 10)
                if maxWarn < minWarn then maxWarn = minWarn end
                profile.warnBefore = CVA:NormalizeWarningSeconds(profile.warnBefore, minWarn, maxWarn, minWarn)

                w._settingWarn = true
                w.slider:SetValue(profile.warnBefore)
                if w.warnInput then
                    w.warnInput:SetText(tostring(profile.warnBefore))
                    w.warnInput:SetCursorPosition(0)
                end
                w._settingWarn = false

                SetControlEnabled(w.slider, detailEnabled)
                if w.warnInput then
                    if not detailEnabled then UI:ClearKeyboardFocus(w.warnInput) end
                    SetControlEnabled(w.warnInput, detailEnabled)
                end
                if w.slider.Low then SetVisualEnabled(w.slider.Low, detailEnabled, 0.45) end
                if w.slider.High then SetVisualEnabled(w.slider.High, detailEnabled, 0.45) end
            end

            if w.mode then
                SetControlEnabled(w.mode, detailEnabled)
                if w.mode.SignalUpdate then w.mode:SignalUpdate() end
            end

            SetControlEnabled(w.test, detailEnabled)

            if profile.mode == "tts" then
                w.sound:Hide()
                w.tts:Show()
                w.tts:SetText(profile.ttsText or alertSpec.defaultText or "提醒")
                w.tts:SetCursorPosition(0)
                if not detailEnabled then UI:ClearKeyboardFocus(w.tts) end
                SetControlEnabled(w.tts, detailEnabled)
            else
                UI:ClearKeyboardFocus(w.tts)
                w.tts:Hide()
                w.sound:SetText(CVA:GetAlertSoundLabel(profile))
                w.sound:Show()
                SetControlEnabled(w.sound, detailEnabled)
            end

            w.status:SetText(CVA:GetAlertSourceStatus(profile))
        end
    end
    panel:SetScript("OnShow", function(self) self:Refresh() end)
    panel:SetScript("OnHide", function(self) UI:ClearKeyboardFocus(self) end)
    panel:Refresh(); return panel
end

function UI:BuildGlobalPanel(parent)
    local panel = CreateFrame("Frame", nil, parent); panel:SetAllPoints(parent)
    local global = CVA:GetGlobalDB()
    CreateLabel(panel, "全局播报设置", 18, -18, "GameFontNormalLarge")
    local desc = CreateLabel(panel, "这些设置由所有职业语音提醒模块共同使用。", 18, -48, "GameFontHighlight")
    desc:SetWidth(600); desc:SetJustifyH("LEFT")

    CreateLabel(panel, "声音频道", 18, -102)
    local channel = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    channel:SetPoint("TOPLEFT", 18, -126); channel:SetWidth(200); channel:SetDefaultText("声音频道")
    channel:SetupMenu(function(_, rootDescription)
        local channels = {{"Master（推荐）","Master"},{"SFX","SFX"},{"Music","Music"},{"Ambience","Ambience"},{"Dialog","Dialog"}}
        for _, option in ipairs(channels) do
            rootDescription:CreateRadio(option[1], function(v) return global.soundChannel == v end,
                function(v) global.soundChannel = v; panel:Refresh() end, option[2])
        end
    end)

    CreateLabel(panel, "TTS 语音", 250, -102)
    local voice = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    voice:SetPoint("TOPLEFT", 250, -126); voice:SetWidth(300); voice:SetDefaultText("选择 TTS 语音")
    voice:SetupMenu(function(_, rootDescription)
        local voices = CVA:GetTTSVoices()
        if #voices == 0 then rootDescription:CreateTitle("未检测到可用 TTS 语音"); return end
        for _, v in ipairs(voices) do
            rootDescription:CreateRadio(v.name,
                function(id) local current = CVA:GetTTSVoice(); return current == id end,
                function(id) global.ttsVoiceID = id; panel:Refresh() end,
                v.voiceID)
        end
    end)

    CreateLabel(panel, "TTS 音量", 18, -194)
    local volume = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    volume:SetPoint("TOPLEFT", 18, -218); volume:SetWidth(280); volume:SetMinMaxValues(0,100); volume:SetValueStep(5); volume:SetObeyStepOnDrag(true)
    volume.Low:SetText("0"); volume.High:SetText("100"); volume.Text:SetText("")
    local volumeText = CreateLabel(panel, "100%", 315, -221, "GameFontHighlight")
    volume:SetScript("OnValueChanged", function(_, value)
        value = math.max(0, math.min(100, math.floor((tonumber(value) or 100) + 0.5)))
        global.ttsVolume = value; volumeText:SetText(string.format("%d%%", value))
    end)

    CreateLabel(panel, "声音来源状态", 18, -286, "GameFontNormalLarge")
    local lsmStatus = CreateLabel(panel, "", 18, -324, "GameFontHighlight")
    local customStatus = CreateLabel(panel, "", 18, -352, "GameFontHighlight")
    local ttsStatus = CreateLabel(panel, "", 18, -380, "GameFontHighlight")

    function panel:Refresh()
        global = CVA:GetGlobalDB()
        if channel.SignalUpdate then channel:SignalUpdate() end
        if voice.SignalUpdate then voice:SignalUpdate() end
        volume:SetValue(global.ttsVolume); volumeText:SetText(string.format("%d%%", global.ttsVolume))
        lsmStatus:SetText(CVA:GetLSM() and string.format("LibSharedMedia：|cff00ff00已检测（%d 个声音）|r", #CVA:GetLSMSounds()) or "LibSharedMedia：|cffffaa00当前不可用|r")
        customStatus:SetText(CVA:GetCustomSoundProvider() and "露露语音包：|cff00ff00已检测|r" or "露露语音包：|cffffaa00未检测|r")
        local _, voiceName = CVA:GetTTSVoice(); ttsStatus:SetText(voiceName and ("TTS：|cff00ff00" .. tostring(voiceName) .. "|r") or "TTS：|cffff4444未检测到可用语音|r")
    end
    panel:SetScript("OnShow", function(self) self:Refresh() end); panel:Refresh(); return panel
end
