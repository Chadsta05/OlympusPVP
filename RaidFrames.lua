--[[
  OlympusPVP.RaidFrames

  Clickable /targetexact frames. Tests can call Refresh without CreateFrame.
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.RaidFrames = OlympusPVP.RaidFrames or {}

---@type table
local RaidFrames = OlympusPVP.RaidFrames
---@type table
local PvpLayout = OlympusPVP.PvpLayout
---@type table
local TypeGuards = OlympusPVP.TypeGuards

---@type number
local MAX_FRAMES = 40

---@type OlympusPVPCombatant[]
local lastCombatants = {}

---@param combatants OlympusPVPCombatant[]
function RaidFrames.Refresh(combatants)
  lastCombatants = combatants
end

---@return OlympusPVPCombatant[]
function RaidFrames.GetLastCombatants()
  return lastCombatants
end

---@param count number
---@return table
function RaidFrames.LayoutForCount(count)
  return {
    columnSize = PvpLayout.COLUMN_SIZE,
    frameSize = PvpLayout.FrameSizePx(count),
    frameWidth = PvpLayout.FrameWidthPx(count),
    gridHeight = PvpLayout.GridHeightPx(count),
  }
end

---Build /cleartarget + /targetexact macro text.
---@param name string
---@return string?
function RaidFrames.BuildTargetMacro(name)
  if not TypeGuards then
    local trimmed = name:match("^%s*(.-)%s*$")

    if trimmed == "" then
      return nil
    end

    return "/cleartarget\n/targetexact " .. trimmed
  end

  local trimmed = TypeGuards.ExpectPublicString("RaidFrames.BuildTargetMacro", name)

  if not trimmed then
    return nil
  end

  trimmed = trimmed:match("^%s*(.-)%s*$")

  if not TypeGuards.ExpectPublicString("RaidFrames.BuildTargetMacro.trimmed", trimmed) then
    return nil
  end

  return "/cleartarget\n/targetexact " .. trimmed
end

RaidFrames.MAX_FRAMES = MAX_FRAMES
