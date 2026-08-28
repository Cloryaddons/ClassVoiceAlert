local ADDON_NAME = ...
local ROOT_VERSION = "0.1.1"
local CORE_ADDON = "ClassVoiceAlertToolbox_Core"

local settingsCategory
local settingsPanel

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc41e3a[职业语音提示]|r " .. tostring(message))
    end
end

local function GetCore(loadIfNeeded)
    local core = _G.ClassVoiceAlert
    if core then return core end

    if loadIfNeeded and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, CORE_ADDON)
        core = _G.ClassVoiceAlert
    end
    return core
end

local function OpenToolbox()
    local core = GetCore(true)
    if core and type(core.Open) == "function" then
        core:Open()
        return true
    end

    Print("工具箱核心未加载。请在插件列表中启用“工具箱核心”。")
    return false
end

local function CreateSettingsPanel()
    if settingsPanel then return settingsPanel end

    local panel = CreateFrame("Frame", "ClassVoiceAlertToolboxSettingsPanel")
    panel.name = "ClassVoiceAlert Toolbox"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("ClassVoiceAlert Toolbox")

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -22)
    version:SetText("套件版本：v" .. ROOT_VERSION)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -20)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText("统一管理已安装的职业语音提醒模块与全局播报设置。")

    local coreStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    coreStatus:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetPoint("TOPLEFT", coreStatus, "BOTTOMLEFT", 0, -24)
    openButton:SetSize(210, 32)
    openButton:SetText("打开设置面板")
    openButton:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then
            SettingsPanel:Hide()
        end
        OpenToolbox()
    end)

    function panel:Refresh()
        local core = GetCore(false)
        if core then
            local count = 0
            for _, modules in pairs(core.modules or {}) do
                for _ in pairs(modules) do count = count + 1 end
            end
            coreStatus:SetText(string.format("工具箱核心：|cff00ff00已加载|r    已检测到 %d 个提醒模块。", count))
        else
            coreStatus:SetText("工具箱核心：|cffffaa00尚未加载|r")
        end
    end

    panel:SetScript("OnShow", function(self) self:Refresh() end)
    settingsPanel = panel
    return panel
end

local function RegisterBlizzardSettings()
    if settingsCategory then return settingsCategory end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return nil
    end

    local panel = CreateSettingsPanel()
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
    return category
end

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon ~= ADDON_NAME then return end
    RegisterBlizzardSettings()
end)
RegisterBlizzardSettings()

SLASH_CLASSVOICEALERTTOOLBOX1 = "/cvat"
SlashCmdList.CLASSVOICEALERTTOOLBOX = function()
    OpenToolbox()
end
