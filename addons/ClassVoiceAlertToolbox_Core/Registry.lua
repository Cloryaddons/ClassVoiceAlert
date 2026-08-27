local CVA = _G.ClassVoiceAlert
if not CVA then return end

local CLASS_ORDER = {"DEATHKNIGHT","DEMONHUNTER","DRUID","EVOKER","HUNTER","MAGE","MONK","PALADIN","PRIEST","ROGUE","SHAMAN","WARLOCK","WARRIOR"}
local CLASS_NAMES = {DEATHKNIGHT="死亡骑士",DEMONHUNTER="恶魔猎手",DRUID="德鲁伊",EVOKER="唤魔师",HUNTER="猎人",MAGE="法师",MONK="武僧",PALADIN="圣骑士",PRIEST="牧师",ROGUE="潜行者",SHAMAN="萨满祭司",WARLOCK="术士",WARRIOR="战士"}

local frame, classList, moduleList, contentHost, contentTitle, emptyText, globalPanel
local classButtons, moduleButtons, panelCache = {}, {}, {}
local settingsCategory, settingsPanel, settingsModuleCount

local function HideButtons(buttons)
    for _, button in ipairs(buttons) do button:Hide(); button:UnlockHighlight() end
end

local function SortedClasses()
    local seen, result = {}, {}
    for _, id in ipairs(CLASS_ORDER) do
        if CVA.modules[id] and next(CVA.modules[id]) then result[#result+1]=id; seen[id]=true end
    end
    for id, mods in pairs(CVA.modules) do if not seen[id] and next(mods) then result[#result+1]=id end end
    return result
end

local function SortedModules(classID)
    local result = {}
    for _, desc in pairs(CVA.modules[classID] or {}) do result[#result+1] = desc end
    table.sort(result, function(a,b)
        local ao, bo = tonumber(a.order) or 100, tonumber(b.order) or 100
        if ao ~= bo then return ao < bo end
        return tostring(a.moduleName) < tostring(b.moduleName)
    end)
    return result
end

local function CountModules()
    local count = 0
    for _, modules in pairs(CVA.modules) do
        for _ in pairs(modules) do count = count + 1 end
    end
    return count
end

function CVA:RegisterModule(desc)
    if type(desc) ~= "table" or type(desc.classID) ~= "string" or type(desc.moduleID) ~= "string" then return false, "invalid descriptor" end
    if desc.requiredCoreAPI and tonumber(desc.requiredCoreAPI) > self.API_VERSION then return false, "core API too old" end
    if type(desc.getDB) ~= "function" then return false, "getDB callback required" end
    if type(desc.alerts) ~= "table" then return false, "alerts table required" end
    self.modules[desc.classID] = self.modules[desc.classID] or {}
    self.modules[desc.classID][desc.moduleID] = desc
    self.classInfo[desc.classID] = desc.className or CLASS_NAMES[desc.classID] or desc.classID
    if frame and frame:IsShown() then self:RefreshNavigation() end
    if settingsPanel and settingsPanel:IsShown() and settingsPanel.Refresh then settingsPanel:Refresh() end
    return true
end

function CVA:GetModule(classID, moduleID)
    return self.modules[classID] and self.modules[classID][moduleID] or nil
end

function CVA:RefreshNavigation()
    if not frame then return end
    HideButtons(classButtons); HideButtons(moduleButtons)
    local y = -12
    for index, classID in ipairs(SortedClasses()) do
        local button = classButtons[index]
        if not button then button = CreateFrame("Button", nil, classList, "UIPanelButtonTemplate"); button:SetHeight(30); classButtons[index] = button end
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", 8, y); button:SetPoint("TOPRIGHT", -8, y)
        button:SetText(self.classInfo[classID] or CLASS_NAMES[classID] or classID)
        if classID == self.currentClassID then button:LockHighlight() else button:UnlockHighlight() end
        button:SetScript("OnClick", function() self:SelectClass(classID) end); button:Show(); y = y - 34
    end
    y = -12
    for index, desc in ipairs(SortedModules(self.currentClassID)) do
        local button = moduleButtons[index]
        if not button then button = CreateFrame("Button", nil, moduleList, "UIPanelButtonTemplate"); button:SetHeight(30); moduleButtons[index] = button end
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", 8, y); button:SetPoint("TOPRIGHT", -8, y)
        button:SetText(desc.moduleName or desc.moduleID)
        if desc.moduleID == self.currentModuleID then button:LockHighlight() else button:UnlockHighlight() end
        local classID, moduleID = self.currentClassID, desc.moduleID
        button:SetScript("OnClick", function() self:ShowModule(classID, moduleID) end); button:Show(); y = y - 34
    end
end

local function HideContentPanels()
    -- Release focus BEFORE hiding a panel. A hidden focused EditBox continues
    -- consuming keybinds such as C and ESC.
    if CVA.UI and type(CVA.UI.ClearKeyboardFocus) == "function" then
        if globalPanel then CVA.UI:ClearKeyboardFocus(globalPanel) end
        for _, p in pairs(panelCache) do CVA.UI:ClearKeyboardFocus(p) end
    end
    if globalPanel then globalPanel:Hide() end
    for _, p in pairs(panelCache) do p:Hide() end
    if emptyText then emptyText:Hide() end
end

function CVA:ShowGlobalSettings()
    if not contentHost then return end
    HideContentPanels(); self.currentModuleID = nil
    contentTitle:SetText("全局播报设置")
    if not globalPanel then globalPanel = self.UI:BuildGlobalPanel(contentHost) end
    globalPanel:SetParent(contentHost); globalPanel:ClearAllPoints(); globalPanel:SetAllPoints(contentHost); globalPanel:Show(); globalPanel:Refresh()
    self:RefreshNavigation()
end

function CVA:ShowModule(classID, moduleID)
    if not contentHost then return end
    local desc = self:GetModule(classID, moduleID)
    HideContentPanels(); self.currentClassID, self.currentModuleID = classID, moduleID
    if not desc then emptyText:SetText("未检测到该提醒模块。请确认模块已经安装并启用。"); emptyText:Show(); self:RefreshNavigation(); return end
    contentTitle:SetText((self.classInfo[classID] or classID) .. " / " .. (desc.moduleName or moduleID))
    local key = classID .. ":" .. moduleID
    local panel = panelCache[key]
    if not panel then
        if type(desc.buildPanel) == "function" then
            local ok, result = pcall(desc.buildPanel, contentHost)
            if ok then panel = result end
        else
            local ok, result = pcall(self.UI.BuildStandardModulePanel, self.UI, contentHost, desc)
            if ok then panel = result end
        end
        if not panel then emptyText:SetText("模块设置页面加载失败。"); emptyText:Show(); return end
        panelCache[key] = panel
    end
    panel:SetParent(contentHost); panel:ClearAllPoints(); panel:SetAllPoints(contentHost); panel:Show()
    if type(panel.Refresh) == "function" then panel:Refresh() end
    self:RefreshNavigation()
end

function CVA:SelectClass(classID)
    self.currentClassID = classID
    local mods = SortedModules(classID)
    if #mods > 0 then self:ShowModule(classID, mods[1].moduleID)
    else HideContentPanels(); self.currentModuleID=nil; contentTitle:SetText(self.classInfo[classID] or classID); emptyText:SetText("该职业当前没有已安装的提醒模块。"); emptyText:Show(); self:RefreshNavigation() end
end

local function CreateMainFrame()
    if frame then return frame end
    frame = CreateFrame("Frame", "ClassVoiceAlertToolboxFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1000,650); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:SetMovable(true); frame:EnableMouse(true); frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton"); frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
    local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOPLEFT",24,-20); title:SetText("职业语音提示工具箱")
    local globalButton = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate"); globalButton:SetPoint("TOPRIGHT",-48,-18); globalButton:SetSize(120,28); globalButton:SetText("全局播报设置"); globalButton:SetScript("OnClick",function() CVA:ShowGlobalSettings() end)
    local close = CreateFrame("Button",nil,frame,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-5)
    if CVA.UI and type(CVA.UI.AddSpecialFrame) == "function" then CVA.UI.AddSpecialFrame("ClassVoiceAlertToolboxFrame") end
    local h1=frame:CreateFontString(nil,"OVERLAY","GameFontNormal"); h1:SetPoint("TOPLEFT",24,-58); h1:SetText("职业")
    local h2=frame:CreateFontString(nil,"OVERLAY","GameFontNormal"); h2:SetPoint("TOPLEFT",183,-58); h2:SetText("提醒模块")
    contentTitle=frame:CreateFontString(nil,"OVERLAY","GameFontNormal"); contentTitle:SetPoint("TOPLEFT",378,-58); contentTitle:SetText("设置")
    classList=CreateFrame("Frame",nil,frame,"BackdropTemplate"); classList:SetPoint("TOPLEFT",20,-78); classList:SetPoint("BOTTOMLEFT",20,20); classList:SetWidth(145); classList:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); classList:SetBackdropColor(0,0,0,0.18)
    moduleList=CreateFrame("Frame",nil,frame,"BackdropTemplate"); moduleList:SetPoint("TOPLEFT",175,-78); moduleList:SetPoint("BOTTOMLEFT",175,20); moduleList:SetWidth(185); moduleList:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); moduleList:SetBackdropColor(0,0,0,0.18)
    contentHost=CreateFrame("Frame",nil,frame,"BackdropTemplate"); contentHost:SetPoint("TOPLEFT",370,-78); contentHost:SetPoint("BOTTOMRIGHT",-20,20); contentHost:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); contentHost:SetBackdropColor(0,0,0,0.10)
    emptyText=contentHost:CreateFontString(nil,"ARTWORK","GameFontHighlight"); emptyText:SetPoint("CENTER"); emptyText:SetWidth(520); emptyText:SetJustifyH("CENTER")
    frame:SetScript("OnShow",function()
        local sx=math.min(1,math.max(0.70,(UIParent:GetWidth()-40)/1000)); local sy=math.min(1,math.max(0.70,(UIParent:GetHeight()-40)/650)); frame:SetScale(math.min(sx,sy)); CVA:RefreshNavigation()
    end)
    frame:SetScript("OnHide",function(self)
        if CVA.UI and type(CVA.UI.ClearKeyboardFocus) == "function" then CVA.UI:ClearKeyboardFocus(self) end
        local browser = _G.ClassVoiceAlertSoundBrowser
        if browser and browser:IsShown() then browser:Hide() end
    end)
    frame:Hide(); return frame
end

function CVA:Open()
    CreateMainFrame(); frame:Show(); frame:Raise()
    local classes = SortedClasses()
    if not self.currentClassID or not self.modules[self.currentClassID] then self.currentClassID = classes[1] end
    if self.currentClassID then self:SelectClass(self.currentClassID) else self:ShowGlobalSettings() end
end

function CVA:OpenModule(classID, moduleID)
    CreateMainFrame(); frame:Show(); frame:Raise(); self:ShowModule(classID,moduleID)
end
