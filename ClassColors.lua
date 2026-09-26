--[[
  OlympusPVP.ClassColors
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.ClassColors = OlympusPVP.ClassColors or {}

---@type table
local ClassColors = OlympusPVP.ClassColors

---@type table<string, string>
ClassColors.CLASS_COLORS = {
  warrior = "#C79C6E",
  paladin = "#F58CBA",
  hunter = "#ABD473",
  rogue = "#FFF569",
  priest = "#FFFFFF",
  shaman = "#0070DE",
  mage = "#69CCF0",
  warlock = "#9482C9",
  druid = "#FF7D0A",
  unknown = "#888888",
}

---@param value? number
---@return number
function ClassColors.ClampPercent(value)
  if type(value) ~= "number" then
    return 100
  end

  if value ~= value then
    return 100
  end

  if value < 0 then
    return 0
  end

  if value > 100 then
    return 100
  end

  return value
end

---@param className? string
---@return string
function ClassColors.PowerTypeForClass(className)
  if not className then
    return "mana"
  end

  local key = string.lower(className)

  if key == "warrior" then
    return "rage"
  end

  if key == "rogue" then
    return "energy"
  end

  return "mana"
end

---@param className? string
---@return string
function ClassColors.ColorForClass(className)
  if not className then
    return ClassColors.CLASS_COLORS.unknown
  end

  local key = string.lower(className)
  local color = ClassColors.CLASS_COLORS[key]

  if color then
    return color
  end

  return ClassColors.CLASS_COLORS.unknown
end
