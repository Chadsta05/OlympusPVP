--[[
  OlympusPVP.PvpLayout
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.PvpLayout = OlympusPVP.PvpLayout or {}

---@type table
local PvpLayout = OlympusPVP.PvpLayout

PvpLayout.COLUMN_SIZE = 5
PvpLayout.FRAME_BASE_PX = 48
PvpLayout.FRAME_STEP_PX = 10
PvpLayout.FRAME_MIN_PX = 18
PvpLayout.FRAME_GAP_PX = 3
PvpLayout.FRAME_BASE_WIDTH_PX = 176

---@param count number
---@return number
function PvpLayout.ScaleTier(count)
  if count < 1 then
    return 0
  end

  return math.floor((count - 1) / 10)
end

---@param count number
---@return number
function PvpLayout.FrameSizePx(count)
  local size = PvpLayout.FRAME_BASE_PX - PvpLayout.ScaleTier(count) * PvpLayout.FRAME_STEP_PX

  if size < PvpLayout.FRAME_MIN_PX then
    return PvpLayout.FRAME_MIN_PX
  end

  return size
end

---@param count number
---@return number
function PvpLayout.FrameWidthPx(count)
  local width = PvpLayout.FRAME_BASE_WIDTH_PX - PvpLayout.ScaleTier(count) * PvpLayout.FRAME_STEP_PX
  local minWidth = PvpLayout.FRAME_MIN_PX * 3

  if width < minWidth then
    return minWidth
  end

  return width
end

---@param count number
---@return number
function PvpLayout.GridHeightPx(count)
  local frame = PvpLayout.FrameSizePx(count)

  return PvpLayout.COLUMN_SIZE * frame + (PvpLayout.COLUMN_SIZE - 1) * PvpLayout.FRAME_GAP_PX
end
