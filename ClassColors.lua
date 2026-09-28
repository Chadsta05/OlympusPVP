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
  deathknight = "#C41F3B",
  monk = "#00FF96",
  demonhunter = "#A330C9",
  evoker = "#33937F",
  unknown = "#888888",
}

---@param className? string
---@return string
function ClassColors.NormalizeClassKey(className)
  if not className then
    return "unknown"
  end

  local key = string.lower(className)
  key = string.gsub(key, "[%s_%-]", "")

  if key == "dk" then
    return "deathknight"
  end

  if key == "dh" then
    return "demonhunter"
  end

  return key
end

---@param value? number
---@return number
function ClassColors.ClampPercent(value)
  local TypeGuards = OlympusPVP.TypeGuards

  if TypeGuards then
    if not TypeGuards.IsFiniteNumber(value) then
      return 100
    end
  else
    if type(value) ~= "number" then
      return 100
    end
  end

  local ok, clamped = pcall(function()
    if value < 0 then
      return 0
    end

    if value > 100 then
      return 100
    end

    return value
  end)

  if not ok then
    return 100
  end

  return clamped
end

---@param className? string
---@return boolean
function ClassColors.IsPlayerClass(className)
  if not className then
    return false
  end

  local key = ClassColors.NormalizeClassKey(className)

  if key == "unknown" then
    return false
  end

  if ClassColors.CLASS_COLORS[key] then
    return true
  end

  return false
end

---@param className? string
---@return string
function ClassColors.PowerTypeForClass(className)
  if not className then
    return "mana"
  end

  local key = ClassColors.NormalizeClassKey(className)

  if key == "warrior" then
    return "rage"
  end

  if key == "rogue" then
    return "energy"
  end

  if key == "deathknight" then
    return "runic_power"
  end

  if key == "monk" then
    return "energy"
  end

  if key == "demonhunter" then
    return "fury"
  end

  if key == "hunter" then
    return "mana"
  end

  return "mana"
end

---@param className? string
---@return string
function ClassColors.ColorForClass(className)
  if not className then
    return ClassColors.CLASS_COLORS.unknown
  end

  local key = ClassColors.NormalizeClassKey(className)
  local color = ClassColors.CLASS_COLORS[key]

  if color then
    return color
  end

  return ClassColors.CLASS_COLORS.unknown
end

---@param hex string
---@return number r
---@return number g
---@return number b
function ClassColors.HexToRgb(hex)
  local cleaned = hex

  if string.sub(hex, 1, 1) == "#" then
    cleaned = string.sub(hex, 2)
  end

  local red = tonumber(string.sub(cleaned, 1, 2), 16)
  local green = tonumber(string.sub(cleaned, 3, 4), 16)
  local blue = tonumber(string.sub(cleaned, 5, 6), 16)

  if not red then
    return 0.5, 0.5, 0.5
  end

  if not green then
    return 0.5, 0.5, 0.5
  end

  if not blue then
    return 0.5, 0.5, 0.5
  end

  return red / 255, green / 255, blue / 255
end
