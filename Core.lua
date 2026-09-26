--[[
  OlympusPVP.Core

  Lua translation of the JS PVP/gank scanner: sticky raid frames (cap 40),
  gank-list alerts with coords, battleground-leave clear, login clear.
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.Core = OlympusPVP.Core or {}

---@type table
local Core = OlympusPVP.Core
---@type table
local ClassColors = OlympusPVP.ClassColors
---@type table
local GankPointer = OlympusPVP.GankPointer

---@type string[]
local EVENTS = {
  "PLAYER_LOGIN",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_TARGET_CHANGED",
  "PLAYER_FOCUS_CHANGED",
  "UPDATE_MOUSEOVER_UNIT",
  "NAME_PLATE_UNIT_ADDED",
  "UNIT_TARGET",
  "COMBAT_LOG_EVENT_UNFILTERED",
}

---@type number
local MAX_PVP_COMBATANTS = 40

---@type table<string, boolean>
local DAMAGE_SUBEVENTS = {
  SWING_DAMAGE = true,
  RANGE_DAMAGE = true,
  SPELL_DAMAGE = true,
  SPELL_PERIODIC_DAMAGE = true,
  SPELL_BUILDING_DAMAGE = true,
  DAMAGE_SHIELD = true,
  DAMAGE_SPLIT = true,
}

---@param name? string
---@return string?
function Core.NormalizeName(name)
  if type(name) ~= "string" then
    return nil
  end

  local trimmed = name:match("^%s*(.-)%s*$")

  if trimmed == "" then
    return nil
  end

  return string.lower(trimmed)
end

---@param instanceType? string
---@return boolean
function Core.IsBattlegroundInstance(instanceType)
  if instanceType == "pvp" then
    return true
  end

  if instanceType == "arena" then
    return true
  end

  return false
end

---@param event OlympusPVPEventPayload
---@return boolean
local function CombatEventIsDamage(event)
  if event.isDamage == false then
    return false
  end

  if event.isDamage == true then
    return true
  end

  if event.subevent then
    if DAMAGE_SUBEVENTS[event.subevent] then
      return true
    end

    return false
  end

  return true
end

---@param dependencies OlympusPVPDependencies
---@return OlympusPVPApi
function Core.CreateScanner(dependencies)
  ---@type table<string, number>
  local lastGankAlertTimeByName = {}
  ---@type OlympusPVPDetection?
  local lastGankSighting = nil
  ---@type OlympusPVPCombatant[]
  local pvpCombatants = {}
  ---@type boolean
  local wasInBattleground = false

  ---@param left? string
  ---@param right? string
  ---@return boolean
  local function NamesMatch(left, right)
    local normalizedLeft = Core.NormalizeName(left)
    local normalizedRight = Core.NormalizeName(right)

    if not normalizedLeft then
      return false
    end

    if not normalizedRight then
      return false
    end

    return normalizedLeft == normalizedRight
  end

  ---@param name? string
  ---@return boolean
  local function IsSelfName(name)
    if not dependencies.getPlayerName then
      return false
    end

    return NamesMatch(name, dependencies.getPlayerName())
  end

  ---@param name? string
  ---@return boolean
  local function IsGankTarget(name)
    local normalizedName = Core.NormalizeName(name)

    if not normalizedName then
      return false
    end

    local settings = dependencies.getSettings()
    local index = 1

    while index <= #settings.gankNames do
      if Core.NormalizeName(settings.gankNames[index]) == normalizedName then
        return true
      end

      index = index + 1
    end

    return false
  end

  ---@param name? string
  ---@return OlympusPVPCombatant?
  local function FindPvpCombatant(name)
    local normalizedName = Core.NormalizeName(name)

    if not normalizedName then
      return nil
    end

    local index = 1

    while index <= #pvpCombatants do
      if Core.NormalizeName(pvpCombatants[index].name) == normalizedName then
        return pvpCombatants[index]
      end

      index = index + 1
    end

    return nil
  end

  ---@return OlympusPVPCombatant[]
  local function GetPvpCombatants()
    ---@type OlympusPVPCombatant[]
    local copy = {}
    local index = 1

    while index <= #pvpCombatants do
      copy[index] = pvpCombatants[index]
      index = index + 1
    end

    return copy
  end

  local function ClearPvpCombatants()
    pvpCombatants = {}
    lastGankSighting = nil
  end

  ---@param name string
  local function DismissPvpCombatant(name)
    local normalizedName = Core.NormalizeName(name)

    if not normalizedName then
      return
    end

    ---@type OlympusPVPCombatant[]
    local nextList = {}
    local index = 1

    while index <= #pvpCombatants do
      if Core.NormalizeName(pvpCombatants[index].name) ~= normalizedName then
        nextList[#nextList + 1] = pvpCombatants[index]
      end

      index = index + 1
    end

    pvpCombatants = nextList
  end

  local function EvictStalestPvpCombatant()
    if #pvpCombatants == 0 then
      return
    end

    local staleIndex = 1
    local staleTime = pvpCombatants[1].updatedAt
    local index = 2

    while index <= #pvpCombatants do
      if pvpCombatants[index].updatedAt < staleTime then
        staleTime = pvpCombatants[index].updatedAt
        staleIndex = index
      end

      index = index + 1
    end

    ---@type OlympusPVPCombatant[]
    local nextList = {}
    index = 1

    while index <= #pvpCombatants do
      if index ~= staleIndex then
        nextList[#nextList + 1] = pvpCombatants[index]
      end

      index = index + 1
    end

    pvpCombatants = nextList
  end

  ---@return string
  local function GetLocation()
    local zone = "Unknown Zone"
    local zoneText = dependencies.getZoneText()

    if zoneText then
      zone = zoneText
    end

    local subZoneText = dependencies.getSubZoneText()

    if subZoneText and subZoneText ~= "" then
      return zone .. " - " .. subZoneText
    end

    return zone
  end

  ---@param name string
  ---@param source string
  ---@param timestamp number
  ---@param unit? string
  ---@return OlympusPVPDetection
  local function CreateDetection(name, source, timestamp, unit)
    ---@type OlympusPVPMapPosition?
    local position = dependencies.getPlayerPosition()

    if unit then
      if dependencies.getUnitPosition then
        local unitPosition = dependencies.getUnitPosition(unit)

        if unitPosition then
          position = unitPosition
        end
      end
    end

    ---@type OlympusPVPDetection
    local detection = {
      name = name,
      zone = GetLocation(),
      source = source,
      time = timestamp,
    }

    if position then
      detection.x = position.x
      detection.y = position.y
      detection.mapId = position.mapId
    end

    return detection
  end

  ---@param name string
  ---@param unit? string
  ---@return OlympusPVPUnitInfo
  local function InspectCombatant(name, unit)
    if unit then
      if dependencies.inspectPvpUnit then
        local fromUnit = dependencies.inspectPvpUnit(unit)

        if fromUnit then
          return fromUnit
        end
      end
    end

    if dependencies.inspectPvpName then
      local fromName = dependencies.inspectPvpName(name)

      if fromName then
        return fromName
      end
    end

    return {
      healthPercent = 100,
      powerPercent = 100,
      powerType = "mana",
    }
  end

  ---@param combatant OlympusPVPCombatant
  ---@param name string
  ---@param unit? string
  local function RefreshPvpCombatant(combatant, name, unit)
    local unitToken = combatant.unit

    if unit then
      unitToken = unit
    end

    local info = InspectCombatant(name, unitToken)
    local powerType = ClassColors.PowerTypeForClass(info.className)

    if info.powerType then
      powerType = info.powerType
    end

    combatant.className = info.className
    combatant.classColor = ClassColors.ColorForClass(info.className)
    combatant.level = info.level
    combatant.portraitUrl = info.portraitUrl
    combatant.unit = unitToken
    combatant.healthPercent = ClassColors.ClampPercent(info.healthPercent)
    combatant.powerPercent = ClassColors.ClampPercent(info.powerPercent)
    combatant.powerType = powerType
    combatant.updatedAt = dependencies.now()
  end

  ---@param unit string
  ---@return boolean
  local function IsOtherPlayerUnit(unit)
    if dependencies.unitIsPlayer then
      if not dependencies.unitIsPlayer(unit) then
        return false
      end
    end

    local name = dependencies.unitName(unit)

    if not name then
      return false
    end

    if IsSelfName(name) then
      return false
    end

    return true
  end

  ---@param name string
  ---@param unit? string
  local function NotePvpPlayer(name, unit)
    local settings = dependencies.getSettings()

    if not settings.pvpModeEnabled then
      return
    end

    if not Core.NormalizeName(name) then
      return
    end

    if IsSelfName(name) then
      return
    end

    local existing = FindPvpCombatant(name)

    if existing then
      RefreshPvpCombatant(existing, existing.name, unit)
      return
    end

    ---@type OlympusPVPCombatant
    local combatant = {
      name = name,
      classColor = ClassColors.ColorForClass(nil),
      healthPercent = 100,
      powerPercent = 100,
      powerType = "mana",
      updatedAt = dependencies.now(),
      unit = unit,
    }

    if #pvpCombatants >= MAX_PVP_COMBATANTS then
      EvictStalestPvpCombatant()
    end

    RefreshPvpCombatant(combatant, name, unit)
    pvpCombatants[#pvpCombatants + 1] = combatant

    if dependencies.queuePvpTarget then
      dependencies.queuePvpTarget(name)
    end
  end

  ---@param name string
  ---@param currentTime number
  ---@return boolean
  local function CanGankAlert(name, currentTime)
    local key = Core.NormalizeName(name)

    if not key then
      return false
    end

    local lastTime = lastGankAlertTimeByName[key]

    if lastTime == nil then
      return true
    end

    local settings = dependencies.getSettings()

    return (currentTime - lastTime) >= settings.alertCooldownMs
  end

  ---@param name string
  ---@param source string
  ---@param unit? string
  local function ShowGankAlert(name, source, unit)
    local settings = dependencies.getSettings()

    if not settings.enabled then
      return
    end

    local currentTime = dependencies.now()

    if not CanGankAlert(name, currentTime) then
      return
    end

    local key = Core.NormalizeName(name)

    if not key then
      return
    end

    lastGankAlertTimeByName[key] = currentTime

    local detection = CreateDetection(name, source, currentTime, unit)
    lastGankSighting = detection

    local warning = detection.name .. " GANKER"

    if detection.x ~= nil then
      if detection.y ~= nil then
        warning = warning .. " at " .. GankPointer.FormatMapCoords(detection.x, detection.y)
      end
    end

    if settings.raidWarningEnabled then
      dependencies.showRaidWarning(warning)
    end

    if settings.chatEnabled then
      local chat = "[Olympus PVP] Ganker "
        .. detection.name
        .. " via "
        .. detection.source
        .. " in "
        .. detection.zone

      if detection.x ~= nil then
        if detection.y ~= nil then
          chat = chat .. " @ " .. GankPointer.FormatMapCoords(detection.x, detection.y)
        end
      end

      dependencies.printToChat(chat)
    end

    if settings.soundEnabled then
      dependencies.playRaidWarningSound()
    end

    dependencies.requestTarget(detection.name)
    NotePvpPlayer(detection.name, unit)
  end

  ---@return OlympusPVPGankPointer?
  local function GetGankPointer()
    if not lastGankSighting then
      return nil
    end

    local playerPosition = dependencies.getPlayerPosition()

    if not playerPosition then
      return nil
    end

    if lastGankSighting.x == nil then
      return nil
    end

    if lastGankSighting.y == nil then
      return nil
    end

    local facing = 0

    if dependencies.getPlayerFacingDegrees then
      local reported = dependencies.getPlayerFacingDegrees()

      if type(reported) == "number" then
        facing = reported
      end
    end

    local bearing = GankPointer.BearingDegrees(
      playerPosition.x,
      playerPosition.y,
      lastGankSighting.x,
      lastGankSighting.y
    )

    return {
      name = lastGankSighting.name,
      needleDegrees = GankPointer.NeedleRotationDegrees(facing, bearing),
      x = lastGankSighting.x,
      y = lastGankSighting.y,
      zone = lastGankSighting.zone,
    }
  end

  ---@param unit string
  ---@param source string
  local function CheckUnit(unit, source)
    if not dependencies.unitExists(unit) then
      return
    end

    local name = dependencies.unitName(unit)

    if not name then
      return
    end

    if IsGankTarget(name) then
      ShowGankAlert(name, source, unit)
    end
  end

  local function CheckPvpOutgoingTarget()
    local settings = dependencies.getSettings()

    if not settings.pvpModeEnabled then
      return
    end

    if not dependencies.unitExists("target") then
      return
    end

    if not IsOtherPlayerUnit("target") then
      return
    end

    local name = dependencies.unitName("target")

    if not name then
      return
    end

    NotePvpPlayer(name, "target")
  end

  ---@param unit string
  local function CheckPvpIncomingTarget(unit)
    local settings = dependencies.getSettings()

    if not settings.pvpModeEnabled then
      return
    end

    if not dependencies.unitExists(unit) then
      return
    end

    if not IsOtherPlayerUnit(unit) then
      return
    end

    if not dependencies.unitTargetsPlayer then
      return
    end

    if not dependencies.unitTargetsPlayer(unit) then
      return
    end

    local name = dependencies.unitName(unit)

    if not name then
      return
    end

    NotePvpPlayer(name, unit)
  end

  ---@param event OlympusPVPEventPayload
  local function CheckPvpCombat(event)
    local settings = dependencies.getSettings()

    if not settings.pvpModeEnabled then
      return
    end

    if not CombatEventIsDamage(event) then
      return
    end

    local sourceIsSelf = false

    if event.sourceIsSelf == true then
      sourceIsSelf = true
    else
      if event.sourceName then
        sourceIsSelf = IsSelfName(event.sourceName)
      end
    end

    local destinationIsSelf = false

    if event.destinationIsSelf == true then
      destinationIsSelf = true
    else
      if event.destinationName then
        destinationIsSelf = IsSelfName(event.destinationName)
      end
    end

    if not sourceIsSelf then
      if not destinationIsSelf then
        return
      end
    end

    if sourceIsSelf then
      if event.destinationName then
        NotePvpPlayer(event.destinationName)
      end
    end

    if destinationIsSelf then
      if event.sourceName then
        NotePvpPlayer(event.sourceName)
      end
    end
  end

  ---@param event OlympusPVPEventPayload
  local function CheckCombatLog(event)
    if event.sourceName then
      if IsGankTarget(event.sourceName) then
        ShowGankAlert(event.sourceName, "combat log")
      end
    end

    if not event.destinationName then
      return
    end

    if IsGankTarget(event.sourceName) then
      return
    end

    if IsGankTarget(event.destinationName) then
      ShowGankAlert(event.destinationName, "combat log")
    end
  end

  local function CheckBattlegroundExit()
    if not dependencies.getInstanceType then
      return
    end

    local inBattleground = Core.IsBattlegroundInstance(dependencies.getInstanceType())

    if wasInBattleground then
      if not inBattleground then
        ClearPvpCombatants()
      end
    end

    wasInBattleground = inBattleground
  end

  ---@param event string
  ---@param payload? OlympusPVPEventPayload
  local function HandleEvent(event, payload)
    payload = payload or {}
    local settings = dependencies.getSettings()

    if event ~= "PLAYER_LOGIN" then
      if event ~= "PLAYER_ENTERING_WORLD" then
        if not settings.enabled then
          return
        end
      end
    end

    if event == "PLAYER_LOGIN" then
      ClearPvpCombatants()
      wasInBattleground = false
      dependencies.printToChat("[Olympus PVP] loaded.")
      dependencies.printToChat(
        "[Olympus PVP] Gank list " .. tostring(#settings.gankNames) .. " names."
      )
      return
    end

    if event == "PLAYER_ENTERING_WORLD" then
      CheckBattlegroundExit()
      return
    end

    if event == "PLAYER_TARGET_CHANGED" then
      CheckUnit("target", "target")
      CheckPvpOutgoingTarget()
      return
    end

    if event == "PLAYER_FOCUS_CHANGED" then
      CheckUnit("focus", "focus")
      return
    end

    if event == "UPDATE_MOUSEOVER_UNIT" then
      CheckUnit("mouseover", "mouseover")
      return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
      if payload.unit then
        CheckUnit(payload.unit, "nameplate")
        CheckPvpIncomingTarget(payload.unit)
      end
      return
    end

    if event == "UNIT_TARGET" then
      if payload.unit then
        CheckPvpIncomingTarget(payload.unit)
      end
      return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      CheckCombatLog(payload)
      CheckPvpCombat(payload)
    end
  end

  local function Start()
    local index = 1

    while index <= #EVENTS do
      dependencies.registerEvent(EVENTS[index], HandleEvent)
      index = index + 1
    end
  end

  return {
    Start = Start,
    HandleEvent = HandleEvent,
    NotePvpPlayer = NotePvpPlayer,
    GetPvpCombatants = GetPvpCombatants,
    ClearPvpCombatants = ClearPvpCombatants,
    DismissPvpCombatant = DismissPvpCombatant,
    IsPvpCombatant = function(name)
      if FindPvpCombatant(name) then
        return true
      end

      return false
    end,
    IsGankTarget = IsGankTarget,
    GetLastGankSighting = function()
      return lastGankSighting
    end,
    GetGankPointer = GetGankPointer,
    CheckUnit = CheckUnit,
    CheckCombatLog = CheckCombatLog,
  }
end

Core.EVENTS = EVENTS
Core.MAX_PVP_COMBATANTS = MAX_PVP_COMBATANTS
