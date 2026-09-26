--[[
  OlympusPVP.GankPointer
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.GankPointer = OlympusPVP.GankPointer or {}

---@type table
local GankPointer = OlympusPVP.GankPointer

---@param fromX number
---@param fromY number
---@param toX number
---@param toY number
---@return number
function GankPointer.BearingDegrees(fromX, fromY, toX, toY)
  local dx = toX - fromX
  local dy = toY - fromY
  local atan2 = math.atan2

  if not atan2 then
    atan2 = math.atan
  end

  local degrees = math.deg(atan2(dx, -dy))

  if degrees < 0 then
    degrees = degrees + 360
  end

  return degrees
end

---@param playerFacingDegrees number
---@param targetBearingDegrees number
---@return number
function GankPointer.NeedleRotationDegrees(playerFacingDegrees, targetBearingDegrees)
  local relative = targetBearingDegrees - playerFacingDegrees

  while relative < 0 do
    relative = relative + 360
  end

  while relative >= 360 do
    relative = relative - 360
  end

  return relative
end

---@param x number
---@param y number
---@return string
---@param value number
---@return string
local function OneDecimal(value)
  return string.format("%.1f", math.floor(value * 10 + 0.5) / 10)
end

---@param x number
---@param y number
---@return string
function GankPointer.FormatMapCoords(x, y)
  return OneDecimal(x) .. ", " .. OneDecimal(y)
end
