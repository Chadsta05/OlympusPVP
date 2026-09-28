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
---@type table
local ClassColors = OlympusPVP.ClassColors

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

  if GetUnitName then
    ---@type boolean, string?
    local nameOk, displayedName = pcall(GetUnitName, unit, true)
    if nameOk then
      local publicDisplayedName = TypeGuards.ExpectPublicString(
        "UnitNameSafe.GetUnitName",
        displayedName
      )
      if publicDisplayedName then
        return publicDisplayedName
      end
    end
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

---@param guid unknown
---@return boolean
local function GuidLooksLikePlayer(guid)
  local publicGuid = TypeGuards.AsPublicString(guid)

  if not publicGuid then
    return false
  end

  if string.sub(publicGuid, 1, 7) == "Player-" then
    return true
  end

  if string.sub(string.lower(publicGuid), 1, 7) == "player-" then
    return true
  end

  return false
end

---@param unit string
---@return boolean
local function UnitIsPlayerSafe(unit)
  if UnitIsPlayer then
    local playerOk, isPlayer = pcall(UnitIsPlayer, unit)

    if playerOk then
      if TypeGuards.IsWowTruthy(isPlayer) then
        return true
      end
    end
  end

  if UnitGUID then
    local guidOk, guid = pcall(UnitGUID, unit)

    if guidOk then
      if GuidLooksLikePlayer(guid) then
        return true
      end
    end
  end

  if not UnitIsPlayer then
    return true
  end

  return false
end

---@param unit string
---@return boolean
local function UnitExistsSafe(unit)
  if not UnitExists then
    return false
  end

  return TypeGuards.IsWowTruthy(UnitExists(unit))
end

---@return OlympusPVPMapPosition?
local function GetPlayerPositionSafe()
  if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
    local mapId = TypeGuards.ExpectFiniteNumber(
      "C_Map.GetBestMapForUnit",
      C_Map.GetBestMapForUnit("player")
    )

    if mapId then
      local position = TypeGuards.ExpectRecord(
        "C_Map.GetPlayerMapPosition",
        C_Map.GetPlayerMapPosition(mapId, "player")
      )

      if position then
        if position.GetXY then
          local x, y = position:GetXY()

          local publicX = TypeGuards.AsPublicNumber(x)
          local publicY = TypeGuards.AsPublicNumber(y)

          if publicX then
            if publicY then
              return {
                x = math.floor(publicX * 10000 + 0.5) / 100,
                y = math.floor(publicY * 10000 + 0.5) / 100,
                mapId = tostring(mapId),
              }
            end
          end
        end
      end
    end
  end

  return nil
end

---@param unit string
---@return OlympusPVPMapPosition?
local function GetUnitPositionSafe(unit)
  if not TypeGuards.ExpectPublicString("GetUnitPositionSafe.unit", unit) then
    return nil
  end

  if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
    local mapId = TypeGuards.ExpectFiniteNumber(
      "C_Map.GetBestMapForUnit.unit",
      C_Map.GetBestMapForUnit("player")
    )

    if mapId then
      local position = C_Map.GetPlayerMapPosition(mapId, unit)

      if position then
        if position.GetXY then
          local x, y = position:GetXY()

          local publicX = TypeGuards.AsPublicNumber(x)
          local publicY = TypeGuards.AsPublicNumber(y)

          if publicX then
            if publicY then
              return {
                x = math.floor(publicX * 10000 + 0.5) / 100,
                y = math.floor(publicY * 10000 + 0.5) / 100,
                mapId = tostring(mapId),
              }
            end
          end
        end
      end
    end
  end

  return nil
end

---@return number
local function GetPlayerFacingDegreesSafe()
  if not GetPlayerFacing then
    return 0
  end

  local facing = TypeGuards.AsPublicNumber(GetPlayerFacing())

  if not facing then
    return 0
  end

  local ok, clockwise = pcall(function()
    return (360 - math.deg(facing)) % 360
  end)

  if not ok then
    return 0
  end

  if not TypeGuards.IsFiniteNumber(clockwise) then
    return 0
  end

  return clockwise
end

---@type number
local SCAN_INTERVAL_SECONDS = 0.2
---@type number
local scanElapsed = 0
---@type number
local MAX_NAMEPLATES = 40
---@type (fun())?
local uiRefresh

local function ScanUnitToken(unit, event)
  if not eventHandler then
    return
  end

  if not UnitExistsSafe(unit) then
    return
  end

  if event == "NAME_PLATE_UNIT_ADDED" then
    eventHandler(event, {
      unit = unit,
    })
    return
  end

  if event == "UNIT_TARGET" then
    eventHandler(event, {
      unit = unit,
    })
    return
  end

  eventHandler(event, {})
end

local function ScanVisibleUnits()
  ScanUnitToken("player", "NAME_PLATE_UNIT_ADDED")
  ScanUnitToken("target", "PLAYER_TARGET_CHANGED")
  ScanUnitToken("focus", "PLAYER_FOCUS_CHANGED")
  ScanUnitToken("mouseover", "UPDATE_MOUSEOVER_UNIT")

  local index = 1

  while index <= MAX_NAMEPLATES do
    local unit = "nameplate" .. tostring(index)
    ScanUnitToken(unit, "NAME_PLATE_UNIT_ADDED")

    if eventHandler then
      if UnitExistsSafe(unit) then
        eventHandler("UNIT_TARGET", {
          unit = unit,
        })
      end
    end

    index = index + 1
  end
end

local function OnUpdate(_, elapsed)
  if type(elapsed) ~= "number" then
    return
  end

  scanElapsed = scanElapsed + elapsed

  if scanElapsed < SCAN_INTERVAL_SECONDS then
    return
  end

  scanElapsed = 0
  ScanVisibleUnits()

  if uiRefresh then
    uiRefresh()
  end
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
  local powerTypeName = nil

  if UnitClass then
    local classOk, localizedName, classFile = pcall(UnitClass, unit)

    if classOk then
      className = TypeGuards.AsPublicString(classFile)

      if not className then
        className = TypeGuards.AsPublicString(localizedName)
      end
    end
  end

  local level = nil

  if UnitLevel then
    local levelOk, unitLevel = pcall(UnitLevel, unit)

    if levelOk then
      level = TypeGuards.AsPublicNumber(unitLevel)
    end
  end

  ---@param currentFn function
  ---@param maxFn function
  ---@param powerIndex? number
  ---@return number?
  local function UnitResourcePercent(currentFn, maxFn, powerIndex)
    local ok, percent = pcall(function()
      local maxValue
      local currentValue

      if powerIndex then
        maxValue = maxFn(unit, powerIndex)
        currentValue = currentFn(unit, powerIndex)
      else
        maxValue = maxFn(unit)
        currentValue = currentFn(unit)
      end

      local publicMax = TypeGuards.AsPublicNumber(maxValue)
      local publicCurrent = TypeGuards.AsPublicNumber(currentValue)

      if publicMax then
        if publicCurrent then
          if publicMax <= 0 then
            return nil
          end

          return (publicCurrent / publicMax) * 100
        end
      end

      local ratio = currentValue / maxValue
      local publicRatio = TypeGuards.AsPublicNumber(ratio)

      if publicRatio then
        return publicRatio * 100
      end

      if TypeGuards.IsFiniteNumber(ratio) then
        return ratio * 100
      end

      return nil
    end)

    if not ok then
      return nil
    end

    if not TypeGuards.IsFiniteNumber(percent) then
      return nil
    end

    return percent
  end

  local healthPercent = nil
  local powerPercent = nil
  local powerIndex = nil

  if UnitPowerType then
    local powerOk, typeIndex, typeToken = pcall(UnitPowerType, unit)

    if powerOk then
      powerIndex = TypeGuards.AsPublicNumber(typeIndex)
      local publicToken = TypeGuards.AsPublicString(typeToken)

      if publicToken then
        powerTypeName = string.lower(publicToken)
      end
    end
  end

  if UnitHealth and UnitHealthMax then
    healthPercent = UnitResourcePercent(UnitHealth, UnitHealthMax)
  end

  if UnitPower and UnitPowerMax then
    powerPercent = UnitResourcePercent(UnitPower, UnitPowerMax, powerIndex)
  end

  return {
    className = className,
    level = level,
    healthPercent = healthPercent,
    powerPercent = powerPercent,
    powerType = powerTypeName,
  }
end

---@param unit string
---@return boolean
local function UnitTargetsPlayer(unit)
  if not UnitIsUnit then
    return false
  end

  return TypeGuards.IsWowTruthy(UnitIsUnit(unit .. "target", "player"))
end

---@param unit string
---@return OlympusPVPUnitRelation?
local function InspectUnitRelation(unit)
  if not TypeGuards.ExpectPublicString("InspectUnitRelation.unit", unit) then
    return nil
  end

  local playerFaction = nil
  local faction = nil

  if UnitFactionGroup then
    local playerOk, playerValue = pcall(UnitFactionGroup, "player")

    if playerOk then
      playerFaction = TypeGuards.AsPublicString(playerValue)
    end

    local unitOk, unitValue = pcall(UnitFactionGroup, unit)

    if unitOk then
      faction = TypeGuards.AsPublicString(unitValue)
    end
  end

  local reaction = nil

  if UnitReaction then
    local reactionOk, reactionValue = pcall(UnitReaction, "player", unit)

    if reactionOk then
      reaction = TypeGuards.AsPublicNumber(reactionValue)
    end
  end

  local canAttack = false

  if UnitCanAttack then
    local attackOk, attackValue = pcall(UnitCanAttack, "player", unit)

    if attackOk then
      canAttack = TypeGuards.IsWowTruthy(attackValue)
    end
  end

  local isEnemy = false

  if UnitIsEnemy then
    local enemyOk, enemyValue = pcall(UnitIsEnemy, "player", unit)

    if enemyOk then
      isEnemy = TypeGuards.IsWowTruthy(enemyValue)
    end
  end

  local inGroup = false

  if UnitInParty then
    local partyOk, partyValue = pcall(UnitInParty, unit)

    if partyOk then
      if TypeGuards.IsWowTruthy(partyValue) then
        inGroup = true
      end
    end
  end

  if UnitInRaid then
    local raidOk, raidValue = pcall(UnitInRaid, unit)

    if raidOk then
      if raidValue then
        inGroup = true
      end
    end
  end

  local sameFaction = false

  if playerFaction then
    if faction then
      sameFaction = playerFaction == faction
    end
  end

  return {
    faction = faction,
    playerFaction = playerFaction,
    reaction = reaction,
    canAttack = canAttack,
    isEnemy = isEnemy,
    sameFaction = sameFaction,
    inGroup = inGroup,
  }
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

---@param flags unknown
---@param mask number
---@return boolean
local function CombatFlagSet(flags, mask)
  local publicFlags = TypeGuards.AsPublicNumber(flags)

  if not publicFlags then
    return false
  end

  return (math.floor(publicFlags / mask) % 2) == 1
end

---@param guid unknown
---@return boolean
local function GuidIsUnitPlayer(guid)
  if not guid then
    return false
  end

  if not UnitGUID then
    return false
  end

  local guidOk, playerGuid = pcall(UnitGUID, "player")

  if not guidOk then
    return false
  end

  local publicGuid = TypeGuards.AsPublicString(guid)
  local publicPlayer = TypeGuards.AsPublicString(playerGuid)

  if publicGuid then
    if publicPlayer then
      return publicGuid == publicPlayer
    end
  end

  local equalOk, equal = pcall(function()
    return guid == playerGuid
  end)

  if not equalOk then
    return false
  end

  return equal == true
end

---@param guid unknown
---@return string?
local function NameFromPlayerGuid(guid)
  local publicGuid = TypeGuards.AsPublicString(guid)

  if not publicGuid then
    return nil
  end

  if not GetPlayerInfoByGUID then
    return nil
  end

  local infoOk, _, _, _, _, _, playerName = pcall(GetPlayerInfoByGUID, publicGuid)

  if not infoOk then
    return nil
  end

  return TypeGuards.AsPublicString(playerName)
end

---@param name unknown
---@param guid unknown
---@return string?
local function CombatLogName(name, guid)
  local publicName = TypeGuards.AsPublicString(name)

  if publicName then
    return publicName
  end

  return NameFromPlayerGuid(guid)
end

---@param ... unknown
---@return OlympusPVPEventPayload
local function BuildCombatLogPayload(...)
  local args = { ... }
  ---@type unknown
  local subeventRaw
  ---@type unknown
  local sourceGuid
  ---@type unknown
  local sourceNameRaw
  ---@type unknown
  local sourceFlags
  ---@type unknown
  local destGuid
  ---@type unknown
  local destNameRaw
  ---@type unknown
  local destFlags

  if CombatLogGetCurrentEventInfo then
    local _, eventName, third, fourth, fifth, sixth, seventh, eighth, ninth, tenth =
      CombatLogGetCurrentEventInfo()

    subeventRaw = eventName

    if TypeGuards.IsBoolean(third) then
      sourceGuid = fourth
      sourceNameRaw = fifth
      sourceFlags = sixth
      destGuid = eighth
      destNameRaw = ninth
      destFlags = tenth
    else
      if GuidLooksLikePlayer(third) then
        sourceGuid = third
        sourceNameRaw = fourth
        sourceFlags = fifth
        destGuid = sixth
        destNameRaw = seventh
        destFlags = eighth
      else
        local thirdText = TypeGuards.AsPublicString(third)

        if thirdText then
          if string.find(thirdText, "-", 1, true) then
            sourceGuid = third
            sourceNameRaw = fourth
            sourceFlags = fifth
            destGuid = sixth
            destNameRaw = seventh
            destFlags = eighth
          else
            sourceGuid = fourth
            sourceNameRaw = fifth
            sourceFlags = sixth
            destGuid = eighth
            destNameRaw = ninth
            destFlags = tenth
          end
        else
          sourceGuid = fourth
          sourceNameRaw = fifth
          sourceFlags = sixth
          destGuid = eighth
          destNameRaw = ninth
          destFlags = tenth
        end
      end
    end
  else
    subeventRaw = args[2]
    sourceGuid = args[4]
    sourceNameRaw = args[5]
    sourceFlags = args[6]
    destGuid = args[8]
    destNameRaw = args[9]
    destFlags = args[10]
  end

  ---@type number
  local affiliationMine = 1
  ---@type number
  local typePlayer = 1024
  local sourceName = CombatLogName(sourceNameRaw, sourceGuid)
  local destinationName = CombatLogName(destNameRaw, destGuid)
  local subevent = TypeGuards.AsPublicString(subeventRaw)
  local destinationIsSelf = GuidIsUnitPlayer(destGuid)

  if not destinationIsSelf then
    destinationIsSelf = CombatFlagSet(destFlags, affiliationMine)
  end

  local sourceIsSelf = GuidIsUnitPlayer(sourceGuid)

  if not sourceIsSelf then
    sourceIsSelf = CombatFlagSet(sourceFlags, affiliationMine)
  end

  local sourceIsPlayer = GuidLooksLikePlayer(sourceGuid)

  if not sourceIsPlayer then
    sourceIsPlayer = CombatFlagSet(sourceFlags, typePlayer)
  end

  local destinationIsPlayer = GuidLooksLikePlayer(destGuid)

  if not destinationIsPlayer then
    destinationIsPlayer = CombatFlagSet(destFlags, typePlayer)
  end

  local unitDiedSelf = false

  if destinationIsSelf then
    if subevent == "UNIT_DIED" then
      unitDiedSelf = true
    else
      if subevent == "UNIT_DESTROYED" then
        unitDiedSelf = true
      end
    end
  end

  return {
    sourceName = sourceName,
    destinationName = destinationName,
    sourceIsSelf = sourceIsSelf,
    destinationIsSelf = destinationIsSelf,
    sourceIsPlayer = sourceIsPlayer,
    destinationIsPlayer = destinationIsPlayer,
    subevent = subevent,
    unitDiedSelf = unitDiedSelf,
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
  elseif event == "PLAYER_REGEN_ENABLED" then
    if uiRefresh then
      uiRefresh()
    end
  end

  eventHandler(event, payload)

  if uiRefresh then
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      return
    end

    uiRefresh()
  end
end

---@param event string
---@param handler OlympusPVPEventHandler
local function RegisterEvent(event, handler)
  eventHandler = handler

  if not CreateFrame then
    return
  end

  if string.sub(event, 1, 5) == "UNIT_" then
    return
  end

  if not eventFrame then
    eventFrame = CreateFrame("Frame", "OlympusPVPEventFrame")
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:SetScript("OnUpdate", OnUpdate)
  end

  eventFrame:RegisterEvent(event)
end

function WowBridge.SetUiRefresh(callback)
  uiRefresh = callback
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
    getPlayerPosition = GetPlayerPositionSafe,
    getUnitPosition = GetUnitPositionSafe,
    getPlayerFacingDegrees = GetPlayerFacingDegreesSafe,
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
    unitIsPlayer = UnitIsPlayerSafe,
    unitTargetsPlayer = UnitTargetsPlayer,
    inspectPvpUnit = InspectPvpUnit,
    inspectUnitRelation = InspectUnitRelation,
    getInstanceType = GetInstanceTypeSafe,
    registerSlashCommand = RegisterSlashCommand,
  }
end
