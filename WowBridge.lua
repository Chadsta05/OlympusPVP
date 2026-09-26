--[[
  OlympusPVP.WowBridge

  Client adapter. Never call TargetUnit/TargetByName from scanner code.
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.WowBridge = OlympusPVP.WowBridge or {}

---@type table
local WowBridge = OlympusPVP.WowBridge
---@type table
local TypeGuards = OlympusPVP.TypeGuards

if not TypeGuards then
  error("OlympusPVP.TypeGuards must load before WowBridge")
end

---@type any?
local eventFrame
---@type OlympusPVPEventHandler?
local eventHandler
---@type string?
local pendingTargetName

local function PrintToChat(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(message, 1.0, 0.82, 0.0)
  else
    print(message)
  end
end

TypeGuards.SetPrinter(PrintToChat)

local function ShowRaidWarning(message)
  if RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    return
  end

  PrintToChat(message)
end

local function PlayRaidWarningSound()
  if PlaySound then
    if SOUNDKIT and SOUNDKIT.RAID_WARNING then
      PlaySound(SOUNDKIT.RAID_WARNING)
    else
      PlaySound("RaidWarning")
    end
  end
end

---@return string?
local function UnitNameSafe(unit)
  if not TypeGuards.ExpectPublicString("UnitNameSafe.unit", unit) then
    return nil
  end

  if UnitName then
    ---@type boolean, string?
    local ok, firstName = pcall(UnitName, unit)

    if ok then
      return TypeGuards.ExpectPublicString("UnitNameSafe.UnitName", firstName)
    end
  end

  return nil
end

---@param unit string
---@return boolean
local function UnitExistsSafe(unit)
  if not UnitExists then
    return false
  end

  return UnitExists(unit) == true
end

---@return string
local function GetInstanceTypeSafe()
  if not GetInstanceInfo then
    return "none"
  end

  local _, instanceType = GetInstanceInfo()

  if type(instanceType) == "string" then
    return instanceType
  end

  return "none"
end

---@param unit string
---@return OlympusPVPUnitInfo?
local function InspectPvpUnit(unit)
  if not UnitExistsSafe(unit) then
    return nil
  end

  local className = nil

  if UnitClass then
    local _, classFile = UnitClass(unit)

    if type(classFile) == "string" then
      className = classFile
    end
  end

  local level = nil

  if UnitLevel then
    local unitLevel = UnitLevel(unit)

    if type(unitLevel) == "number" then
      level = unitLevel
    end
  end

  local healthPercent = 100
  local powerPercent = 100

  if UnitHealth and UnitHealthMax then
    local maxHealth = UnitHealthMax(unit)

    if type(maxHealth) == "number" then
      if maxHealth > 0 then
        healthPercent = (UnitHealth(unit) / maxHealth) * 100
      end
    end
  end

  if UnitPower and UnitPowerMax then
    local maxPower = UnitPowerMax(unit)

    if type(maxPower) == "number" then
      if maxPower > 0 then
        powerPercent = (UnitPower(unit) / maxPower) * 100
      end
    end
  end

  return {
    className = className,
    level = level,
    healthPercent = healthPercent,
    powerPercent = powerPercent,
  }
end

---@param unit string
---@return boolean
local function UnitTargetsPlayer(unit)
  if not UnitIsUnit then
    return false
  end

  return UnitIsUnit(unit .. "target", "player") == true
end

local function RequestTarget(name)
  if not TypeGuards.ExpectPublicString("RequestTarget.name", name) then
    return
  end

  pendingTargetName = name:match("^%s*(.-)%s*$")
end

---@return number
local function NowMs()
  if GetTime then
    return GetTime() * 1000
  end

  return time() * 1000
end

---@param ... unknown
---@return OlympusPVPEventPayload
local function BuildCombatLogPayload(...)
  local args = { ... }

  if CombatLogGetCurrentEventInfo then
    local _, subevent, _, _, sourceName, _, _, _, destinationName = CombatLogGetCurrentEventInfo()

    return {
      sourceName = TypeGuards.ExpectPublicString("CombatLog.sourceName", sourceName),
      destinationName = TypeGuards.ExpectPublicString("CombatLog.destinationName", destinationName),
      subevent = TypeGuards.ExpectPublicString("CombatLog.subevent", subevent),
    }
  end

  return {
    sourceName = TypeGuards.ExpectPublicString("CombatLog.sourceName", args[5] or args[4]),
    destinationName = TypeGuards.ExpectPublicString("CombatLog.destinationName", args[8] or args[9]),
  }
end

local function OnEvent(_, event, ...)
  if not eventHandler then
    return
  end

  ---@type OlympusPVPEventPayload
  local payload = {}

  if event == "NAME_PLATE_UNIT_ADDED" then
    local unit = TypeGuards.ExpectPublicString("NAME_PLATE_UNIT_ADDED.unit", ...)

    if unit then
      payload.unit = unit
    end
  elseif event == "UNIT_TARGET" then
    local unit = TypeGuards.ExpectPublicString("UNIT_TARGET.unit", ...)

    if unit then
      payload.unit = unit
    end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    payload = BuildCombatLogPayload(...)
  end

  eventHandler(event, payload)
end

---@param event string
---@param handler OlympusPVPEventHandler
local function RegisterEvent(event, handler)
  eventHandler = handler

  if not eventFrame then
    if CreateFrame then
      eventFrame = CreateFrame("Frame", "OlympusPVPEventFrame")
      eventFrame:SetScript("OnEvent", OnEvent)
    end
  end

  if eventFrame then
    eventFrame:RegisterEvent(event)
  end
end

---@param handler fun(input?: string)
local function RegisterSlashCommand(handler)
  SLASH_OLYMPUSPVP1 = "/olympus"
  SLASH_OLYMPUSPVP2 = "/opvp"

  if not SlashCmdList then
    SlashCmdList = {}
  end

  SlashCmdList["OLYMPUSPVP"] = function(msg)
    handler(msg)
  end
end

function WowBridge.GetPendingTargetName()
  return pendingTargetName
end

function WowBridge.CreateDependencies()
  return {
    getZoneText = function()
      if GetZoneText then
        return TypeGuards.ExpectPublicString("GetZoneText", GetZoneText())
      end

      return nil
    end,
    getSubZoneText = function()
      if GetSubZoneText then
        return TypeGuards.ExpectPublicString("GetSubZoneText", GetSubZoneText())
      end

      return nil
    end,
    getPlayerPosition = function()
      return nil
    end,
    unitExists = UnitExistsSafe,
    unitName = UnitNameSafe,
    showRaidWarning = ShowRaidWarning,
    printToChat = PrintToChat,
    playRaidWarningSound = PlayRaidWarningSound,
    requestTarget = RequestTarget,
    registerEvent = RegisterEvent,
    now = NowMs,
    getPlayerName = function()
      return UnitNameSafe("player")
    end,
    unitIsPlayer = function(unit)
      if not UnitIsPlayer then
        return true
      end

      return UnitIsPlayer(unit) == true
    end,
    unitTargetsPlayer = UnitTargetsPlayer,
    inspectPvpUnit = InspectPvpUnit,
    getInstanceType = GetInstanceTypeSafe,
    registerSlashCommand = RegisterSlashCommand,
  }
end
