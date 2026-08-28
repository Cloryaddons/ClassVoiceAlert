local ADDON_NAME = ...

local CVA = _G.ClassVoiceAlert or _G.ClassVoiceAlertToolbox or {}
_G.ClassVoiceAlert = CVA
_G.ClassVoiceAlertToolbox = CVA -- compatibility alias for 0.1.x modules

CVA.ADDON_NAME = ADDON_NAME
CVA.VERSION = "0.1.1"
CVA.API_VERSION = 1
CVA.modules = CVA.modules or {}
CVA.classInfo = CVA.classInfo or {}
CVA.UI = CVA.UI or {}
CVA._modulePanels = CVA._modulePanels or {}

local PREFIX = "|cffc41e3a[职业语音提示]|r "

function CVA:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(message))
    end
end

function CVA:GetAPIVersion()
    return self.API_VERSION
end

function CVA:CopyDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then return target end
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            self:CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function CVA:ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if value == nil then value = fallback end
    value = tonumber(value) or 0
    if minValue ~= nil and value < minValue then value = minValue end
    if maxValue ~= nil and value > maxValue then value = maxValue end
    return value
end

-- Normalize every "warnBefore" value to the framework's integer-second rule:
-- 1) parse as number; invalid input falls back to the supplied valid value,
-- 2) round any fractional value upward,
-- 3) clamp to the alert's declared valid lifetime range.
function CVA:NormalizeWarningSeconds(value, minValue, maxValue, fallback)
    local minWarn = math.ceil(tonumber(minValue) or 0)
    local maxWarn = math.floor(tonumber(maxValue) or minWarn)
    if maxWarn < minWarn then maxWarn = minWarn end

    local number = tonumber(value)
    if number == nil then number = tonumber(fallback) end
    if number == nil then number = minWarn end

    number = math.ceil(number)
    if number < minWarn then number = minWarn end
    if number > maxWarn then number = maxWarn end
    return number
end
