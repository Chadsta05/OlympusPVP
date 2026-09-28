--[[
  OlympusPVP.PvpLayout
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.PvpLayout = OlympusPVP.PvpLayout or {}

---@type table
local PvpLayout = OlympusPVP.PvpLayout

PvpLayout.COLUMN_SIZE = 5
PvpLayout.WIDE_COLUMN_SIZE = 10
PvpLayout.WIDE_AT_COUNT = 15
PvpLayout.FRAME_BASE_PX = 48
PvpLayout.FRAME_STEP_PX = 12
PvpLayout.FRAME_MIN_PX = 22
PvpLayout.FRAME_GAP_PX = 3
PvpLayout.FRAME_BASE_WIDTH_PX = 176

---@param count number
---@return number
function PvpLayout.ColumnSize(count)
  if count >= PvpLayout.WIDE_AT_COUNT then
    return PvpLayout.WIDE_COLUMN_SIZE
  end

  return PvpLayout.COLUMN_SIZE
end

---@param count number
---@return number
function PvpLayout.ScaleTier(count)
  if count < PvpLayout.WIDE_AT_COUNT then
    return 0
  end

  return math.floor((count - PvpLayout.WIDE_AT_COUNT) / 10) + 1
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
  local columnSize = PvpLayout.ColumnSize(count)

  return columnSize * frame + (columnSize - 1) * PvpLayout.FRAME_GAP_PX
end
