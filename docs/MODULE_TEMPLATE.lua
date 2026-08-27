-- ClassVoiceAlert feature module template
-- Runtime Core API: 1
--
-- Required physical layout:
-- addons/ClassVoiceAlertToolbox_Module_<ShortModuleName>/
--   ClassVoiceAlertToolbox_Module_<ShortModuleName>.toc
--   <ModuleLogic>.lua
--
-- Required TOC:
-- ## Dependencies: ClassVoiceAlertToolbox_Core
-- ## Group: ClassVoiceAlertToolbox
--
-- Module = when to alert. Core = how to store/display/play it.

local ADDON_NAME = ...
local CVA = _G.ClassVoiceAlert
if not CVA or CVA:GetAPIVersion() < 1 then return end

local CLASS_ID = "DEATHKNIGHT"
local MODULE_ID = "example"

local defaults = {
    enabled = true,
    alerts = {
        main = {
            enabled = true,
            warnBefore = 2,
            mode = "blizzard",
            selectedSound = nil,
            selectedCustomSound = nil,
            selectedBlizzardSound = "RAID_WARNING",
            ttsText = "示例提醒",
        },
    },
}

local db = CVA:GetModuleDB(CLASS_ID, MODULE_ID, defaults)

CVA:NormalizeAlertProfile(db.alerts.main, {
    defaultEnabled = true,
    minWarnBefore = 0,
    maxWarnBefore = 10, -- set to the real meaningful maximum lifetime
    defaultWarnBefore = 2,
    warnStep = 1,
    defaultText = "示例提醒",
})

local function FireAlert()
    if not db.enabled or not db.alerts.main.enabled then return end

    CVA:PlayAlert(db.alerts.main, {
        showError = false,
        defaultText = "示例提醒",
    })
end

CVA:RegisterModule({
    addon = ADDON_NAME,
    requiredCoreAPI = 1,
    classID = CLASS_ID,
    className = "死亡骑士",
    moduleID = MODULE_ID,
    moduleName = "示例提醒",
    order = 30,
    description = "只写用户需要知道的功能说明。",
    enabledLabel = "启用示例提醒",
    getDB = function() return db end,
    alerts = {
        {
            key = "main",
            title = "示例提醒",
            description = "达到条件时进行提醒。",
            showEnabled = true,
            showWarnBefore = true,
            minWarnBefore = 0,
            maxWarnBefore = 10,
            warnStep = 1,
            defaultText = "示例提醒",
        },
    },
    testAlert = function()
        CVA:PlayAlert(db.alerts.main, {
            showError = true,
            defaultText = "示例提醒",
        })
    end,
})

-- Put only module-specific event/state/trigger logic below this line.
-- Do not register slash commands or Blizzard Settings categories.
-- Do not duplicate Core LSM/TTS/media/browser/global-audio code.
-- Do not add permanent polling unless it is unavoidable and documented.
