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
  "PLAYER_REGEN_ENABLED",
  "PLAYER_TARGET_CHANGED",
  "PLAYER_FOCUS_CHANGED",
  "UPDATE_MOUSEOVER_UNIT",
  "NAME_PLATE_UNIT_ADDED",
  "COMBAT_LOG_EVENT_UNFILTERED",
  "PLAYER_DEAD",
}

---@type number
local MAX_PVP_COMBATANTS = 40
---@type number
local ATTACKER_WINDOW_MS = 45000
---@type number
local SIGHT_STALE_MS = 10000

---@type table<string, boolean>
local DAMAGE_SUBEVENTS = {
  SWING_DAMAGE = true,
  RANGE_DAMAGE = true,
  SPELL_DAMAGE = true,
  SPELL_PERIODIC_DAMAGE = true,
  SPELL_BUILDING_DAMAGE = true,
  DAMAGE_SHIELD = true,
  DAMAGE_SPLIT = true,
  SWING_DAMAGE_LANDED = true,
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
  ---@type OlympusPVPCombatant[]
  local friendlyCombatants = {}
  ---@type boolean
  local wasInBattleground = false

  ---@return table
  local function CreateNameSet()
    ---@type table<string, boolean>
    local items = {}
    local set = {}

    ---@param value? string
    function set.add(value)
      local key = Core.NormalizeName(value)

      if not key then
        return
      end

      items[key] = true
    end

    ---@param value? string
    ---@return boolean
    function set.has(value)
      local key = Core.NormalizeName(value)

      if not key then
        return false
      end

      return items[key] == true
    end

    ---@param value? string
    function set.delete(value)
      local key = Core.NormalizeName(value)

      if not key then
        return
      end

      items[key] = nil
    end

    function set.clear()
      items = {}
    end

    return set
  end

  ---@type table
  local needsInspect = CreateNameSet()
  ---@type table<string, { name: string, time: number }>
  local recentAttackers = {}

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

  ---@param name string
  local function NoteIncomingAttacker(name)
    local key = Core.NormalizeName(name)

    if not key then
      return
    end

    if IsSelfName(name) then
      return
    end

    recentAttackers[key] = {
      name = name,
      time = dependencies.now(),
    }
  end

  ---@return string[]
  local function CollectDeathSuspects()
    local now = dependencies.now()
    ---@type string[]
    local names = {}

    for _, entry in pairs(recentAttackers) do
      if now - entry.time <= ATTACKER_WINDOW_MS then
        if not IsGankTarget(entry.name) then
          names[#names + 1] = entry.name
        end
      end
    end

    table.sort(names)
    return names
  end

  local function PromptDeathGankers()
    if dependencies.getInstanceType then
      if Core.IsBattlegroundInstance(dependencies.getInstanceType()) then
        return
      end
    end

    local names = CollectDeathSuspects()

    if #names == 0 then
      return
    end

    if dependencies.printToChat then
      dependencies.printToChat(
        "[Olympus PVP] You died. Mark gankers? " .. table.concat(names, ", ")
      )
    end

    if dependencies.promptDeathGankers then
      dependencies.promptDeathGankers(names)
    end

    recentAttackers = {}
  end

  ---@param list OlympusPVPCombatant[]
  ---@param name? string
  ---@return OlympusPVPCombatant?
  local function FindCombatant(list, name)
    local normalizedName = Core.NormalizeName(name)

    if not normalizedName then
      return nil
    end

    local index = 1

    while index <= #list do
      if Core.NormalizeName(list[index].name) == normalizedName then
        return list[index]
      end

      index = index + 1
    end

    return nil
  end

  ---@param name? string
  ---@return OlympusPVPCombatant?
  local function FindPvpCombatant(name)
    return FindCombatant(pvpCombatants, name)
  end

  ---@param name? string
  ---@return OlympusPVPCombatant?
  local function FindFriendlyCombatant(name)
    return FindCombatant(friendlyCombatants, name)
  end

  ---@param list OlympusPVPCombatant[]
  ---@return OlympusPVPCombatant[]
  local function CopyCombatants(list)
    ---@type OlympusPVPCombatant[]
    local copy = {}
    local index = 1

    while index <= #list do
      copy[index] = list[index]
      index = index + 1
    end

    return copy
  end

  ---@return OlympusPVPCombatant[]
  local function GetPvpCombatants()
    return CopyCombatants(pvpCombatants)
  end

  ---@return OlympusPVPCombatant[]
  local function GetFriendlyCombatants()
    return CopyCombatants(friendlyCombatants)
  end

  local function ClearPvpCombatants()
    pvpCombatants = {}
    friendlyCombatants = {}
    lastGankSighting = nil
    needsInspect.clear()
    recentAttackers = {}
  end

  ---@param list OlympusPVPCombatant[]
  ---@param name string
  ---@return OlympusPVPCombatant[]
  local function DismissFromList(list, name)
    local normalizedName = Core.NormalizeName(name)

    if not normalizedName then
      return list
    end

    ---@type OlympusPVPCombatant[]
    local nextList = {}
    local index = 1

    while index <= #list do
      if Core.NormalizeName(list[index].name) ~= normalizedName then
        nextList[#nextList + 1] = list[index]
      end

      index = index + 1
    end

    return nextList
  end

  ---@param name string
  local function DismissPvpCombatant(name)
    pvpCombatants = DismissFromList(pvpCombatants, name)
    needsInspect.delete(name)
  end

  ---@param name string
  local function DismissFriendlyCombatant(name)
    friendlyCombatants = DismissFromList(friendlyCombatants, name)
    needsInspect.delete(name)
  end

  ---@param list OlympusPVPCombatant[]
  ---@return OlympusPVPCombatant[]
  local function KeepRecentlySeen(list)
    local now = dependencies.now()
    local settings = dependencies.getSettings()
    ---@type OlympusPVPCombatant[]
    local nextList = {}
    local index = 1

    while index <= #list do
      local combatant = list[index]
      local seenAt = combatant.seenAt

      if seenAt then
        if now - seenAt <= SIGHT_STALE_MS then
          nextList[#nextList + 1] = combatant
        else
          if IsSelfName(combatant.name) then
            if settings.includeSelfOnFriendly then
              nextList[#nextList + 1] = combatant
            else
              needsInspect.delete(combatant.name)
            end
          else
            needsInspect.delete(combatant.name)
          end
        end
      else
        needsInspect.delete(combatant.name)
      end

      index = index + 1
    end

    return nextList
  end

  local function PruneStaleCombatants()
    local settings = dependencies.getSettings()

    if not settings.enemyListPaused then
      pvpCombatants = KeepRecentlySeen(pvpCombatants)
    end

    if not settings.friendlyListPaused then
      friendlyCombatants = KeepRecentlySeen(friendlyCombatants)
    end
  end

  ---@param name string
  local function ConfirmClickTarget(name)
    if not Core.NormalizeName(name) then
      return
    end

    local targetName = dependencies.unitName("target")

    if NamesMatch(targetName, name) then
      local foe = FindPvpCombatant(name)

      if foe then
        foe.seenAt = dependencies.now()
      end

      local friend = FindFriendlyCombatant(name)

      if friend then
        friend.seenAt = dependencies.now()
      end

      return
    end

    if IsSelfName(name) then
      local friend = FindFriendlyCombatant(name)

      if friend then
        friend.seenAt = dependencies.now()
      end

      return
    end

    DismissPvpCombatant(name)
    DismissFriendlyCombatant(name)
  end

  ---@param list OlympusPVPCombatant[]
  ---@return OlympusPVPCombatant[]
  local function EvictStalest(list)
    if #list == 0 then
      return list
    end

    local staleIndex = 1
    local staleTime = list[1].updatedAt
    local index = 2

    while index <= #list do
      if list[index].updatedAt < staleTime then
        staleTime = list[index].updatedAt
        staleIndex = index
      end

      index = index + 1
    end

    ---@type OlympusPVPCombatant[]
    local nextList = {}
    index = 1

    while index <= #list do
      if index ~= staleIndex then
        nextList[#nextList + 1] = list[index]
      end

      index = index + 1
    end

    return nextList
  end

  local function EvictStalestPvpCombatant()
    pvpCombatants = EvictStalest(pvpCombatants)
  end

  local function EvictStalestFriendlyCombatant()
    friendlyCombatants = EvictStalest(friendlyCombatants)
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
  ---@param unit? string
  ---@return string?
  local function ResolveInspectUnit(combatant, unit)
    if unit then
      if dependencies.unitExists(unit) then
        return unit
      end
    end

    if dependencies.unitExists("target") then
      local targetName = dependencies.unitName("target")

      if NamesMatch(targetName, combatant.name) then
        return "target"
      end
    end

    if dependencies.unitExists("mouseover") then
      local mouseName = dependencies.unitName("mouseover")

      if NamesMatch(mouseName, combatant.name) then
        return "mouseover"
      end
    end

    return combatant.unit
  end

  ---@param combatant OlympusPVPCombatant
  ---@param name string
  ---@param unit? string
  local function RefreshPvpCombatant(combatant, name, unit)
    local unitToken = ResolveInspectUnit(combatant, unit)
    local info = InspectCombatant(name, unitToken)

    if info.className then
      combatant.className = info.className
      combatant.classColor = ClassColors.ColorForClass(info.className)
    end

    if info.level then
      combatant.level = info.level
    end

    if info.portraitUrl then
      combatant.portraitUrl = info.portraitUrl
    end

    if info.powerType then
      combatant.powerType = info.powerType
    else
      if combatant.className then
        if not combatant.powerType then
          combatant.powerType = ClassColors.PowerTypeForClass(combatant.className)
        end
      else
        combatant.powerType = ClassColors.PowerTypeForClass(info.className)
      end
    end

    if unitToken then
      if dependencies.unitExists(unitToken) then
        combatant.unit = unitToken

        if info.healthPercent ~= nil then
          combatant.healthPercent = ClassColors.ClampPercent(info.healthPercent)
        end

        if info.powerPercent ~= nil then
          combatant.powerPercent = ClassColors.ClampPercent(info.powerPercent)
        end
      end
    end

    combatant.updatedAt = dependencies.now()

    if unit then
      combatant.seenAt = dependencies.now()
    end

    if combatant.className then
      needsInspect.delete(combatant.name)
    else
      needsInspect.add(combatant.name)
    end
  end

  ---@param name string
  ---@param unit? string
  ---@return boolean
  local function FillKnownCombatant(name, unit)
    local foe = FindPvpCombatant(name)

    if foe then
      RefreshPvpCombatant(foe, foe.name, unit)
      return true
    end

    local friend = FindFriendlyCombatant(name)

    if friend then
      RefreshPvpCombatant(friend, friend.name, unit)
      return true
    end

    return false
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

  ---@param unit? string
  ---@return OlympusPVPUnitRelation
  local function InspectRelation(unit)
    if unit then
      if dependencies.inspectUnitRelation then
        local info = dependencies.inspectUnitRelation(unit)

        if info then
          return info
        end
      end
    end

    return {
      canAttack = true,
      isEnemy = true,
      sameFaction = false,
      inGroup = false,
    }
  end

  ---@param info OlympusPVPUnitRelation
  ---@return string
  local function KindFromRelation(info)
    if info.canAttack == true then
      return "foe"
    end

    if info.isEnemy == true then
      return "foe"
    end

    if info.inGroup == true then
      local settings = dependencies.getSettings()

      if settings.includeGroupOnFriendly then
        return "grouped"
      end

      return "skip-group"
    end

    if info.sameFaction == true then
      return "nearby"
    end

    return "unknown"
  end

  ---@param name string
  ---@param unit? string
  local function AppendFoe(name, unit)
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
  ---@param unit? string
  local function AppendFriendly(name, unit)
    local existing = FindFriendlyCombatant(name)

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

    if #friendlyCombatants >= MAX_PVP_COMBATANTS then
      EvictStalestFriendlyCombatant()
    end

    RefreshPvpCombatant(combatant, name, unit)
    friendlyCombatants[#friendlyCombatants + 1] = combatant

    if dependencies.queuePvpTarget then
      dependencies.queuePvpTarget(name)
    end
  end

  ---@param name string
  ---@param unit? string
  local function PinFriendlyFront(name, unit)
    local existing = FindFriendlyCombatant(name)

    if existing then
      RefreshPvpCombatant(existing, existing.name, unit)

      ---@type OlympusPVPCombatant[]
      local nextList = { existing }
      local index = 1

      while index <= #friendlyCombatants do
        if not NamesMatch(friendlyCombatants[index].name, name) then
          nextList[#nextList + 1] = friendlyCombatants[index]
        end

        index = index + 1
      end

      friendlyCombatants = nextList
      return
    end

    AppendFriendly(name, unit)
    PinFriendlyFront(name, unit)
  end

  ---@param unit? string
  local function NoteSelfFriendly(unit)
    local settings = dependencies.getSettings()
    local playerName = nil

    if dependencies.unitName then
      if dependencies.unitExists then
        if dependencies.unitExists("player") then
          playerName = dependencies.unitName("player")
        end
      end
    end

    if not playerName then
      if dependencies.getPlayerName then
        playerName = dependencies.getPlayerName()
      end
    end

    if not playerName then
      return
    end

    if not settings.includeSelfOnFriendly then
      friendlyCombatants = DismissFromList(friendlyCombatants, playerName)
      return
    end

    local token = unit

    if not token then
      token = "player"
    end

    PinFriendlyFront(playerName, token)
  end

  ---@param name string
  ---@param unit? string
  local function NotePvpPlayer(name, unit)
    if not Core.NormalizeName(name) then
      return
    end

    if IsSelfName(name) then
      NoteSelfFriendly(unit)
      return
    end

    FillKnownCombatant(name, unit)

    local settings = dependencies.getSettings()
    local info = InspectRelation(unit)
    local kind = KindFromRelation(info)

    if kind == "foe" then
      if not settings.pvpModeEnabled then
        return
      end

      friendlyCombatants = DismissFromList(friendlyCombatants, name)

      if settings.enemyListPaused then
        local existing = FindPvpCombatant(name)

        if existing then
          RefreshPvpCombatant(existing, existing.name, unit)
        end

        return
      end

      AppendFoe(name, unit)
      return
    end

    if kind == "skip-group" then
      friendlyCombatants = DismissFromList(friendlyCombatants, name)
      return
    end

    ---@param listedName string
    ---@param listedUnit? string
    local function TryAppendFriendly(listedName, listedUnit)
      pvpCombatants = DismissFromList(pvpCombatants, listedName)

      if settings.friendlyListPaused then
        local existing = FindFriendlyCombatant(listedName)

        if existing then
          RefreshPvpCombatant(existing, existing.name, listedUnit)
        end

        return
      end

      AppendFriendly(listedName, listedUnit)
    end

    if kind == "grouped" then
      TryAppendFriendly(name, unit)
      return
    end

    if kind == "nearby" then
      if not settings.friendlyModeEnabled then
        friendlyCombatants = DismissFromList(friendlyCombatants, name)
        return
      end

      TryAppendFriendly(name, unit)
      return
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

  ---@param unit string
  local function RefreshListedUnit(unit)
    if not dependencies.unitExists(unit) then
      return
    end

    local name = dependencies.unitName(unit)

    if not name then
      return
    end

    local foe = FindPvpCombatant(name)

    if foe then
      RefreshPvpCombatant(foe, foe.name, unit)
      return
    end

    local friend = FindFriendlyCombatant(name)

    if friend then
      RefreshPvpCombatant(friend, friend.name, unit)
    end
  end

  ---@param unit string
  local function CheckNearbyPlayer(unit)
    if unit == "player" then
      NoteSelfFriendly("player")
      return
    end

    if not dependencies.unitExists(unit) then
      return
    end

    RefreshListedUnit(unit)

    if not IsOtherPlayerUnit(unit) then
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
        if event.destinationIsPlayer == true then
          NotePvpPlayer(event.destinationName)
        end
      end
    end

    if destinationIsSelf then
      if event.sourceName then
        NoteIncomingAttacker(event.sourceName)

        if event.sourceIsPlayer == true then
          NotePvpPlayer(event.sourceName)
        end
      end
    end
  end

  ---@param event OlympusPVPEventPayload
  local function NoteIncomingFromCombatLog(event)
    if not CombatEventIsDamage(event) then
      return
    end

    local destinationIsSelf = event.destinationIsSelf == true

    if not destinationIsSelf then
      if event.destinationName then
        destinationIsSelf = IsSelfName(event.destinationName)
      end
    end

    if not destinationIsSelf then
      return
    end

    if not event.sourceName then
      return
    end

    if IsSelfName(event.sourceName) then
      return
    end

    NoteIncomingAttacker(event.sourceName)
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
        if event ~= "PLAYER_DEAD" then
          if not settings.enabled then
            return
          end
        end
      end
    end

    if event == "PLAYER_LOGIN" then
      ClearPvpCombatants()
      wasInBattleground = false
      NoteSelfFriendly("player")
      return
    end

    if event == "PLAYER_ENTERING_WORLD" then
      CheckBattlegroundExit()
      NoteSelfFriendly("player")
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      return
    end

    if event == "PLAYER_TARGET_CHANGED" then
      CheckUnit("target", "target")
      CheckPvpOutgoingTarget()
      CheckNearbyPlayer("target")
      return
    end

    if event == "UPDATE_MOUSEOVER_UNIT" then
      CheckUnit("mouseover", "mouseover")
      CheckNearbyPlayer("mouseover")
      return
    end

    if event == "PLAYER_FOCUS_CHANGED" then
      CheckUnit("focus", "focus")
      CheckNearbyPlayer("focus")
      return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
      if payload.unit then
        CheckUnit(payload.unit, "nameplate")
        CheckNearbyPlayer(payload.unit)
      end
      return
    end

    if event == "UNIT_TARGET" then
      if payload.unit then
        CheckPvpIncomingTarget(payload.unit)
      end
      return
    end

    if event == "UNIT_HEALTH" then
      if payload.unit then
        RefreshListedUnit(payload.unit)
      end
      return
    end

    if event == "UNIT_MAXHEALTH" then
      if payload.unit then
        RefreshListedUnit(payload.unit)
      end
      return
    end

    if event == "UNIT_POWER_UPDATE" then
      if payload.unit then
        RefreshListedUnit(payload.unit)
      end
      return
    end

    if event == "UNIT_POWER_FREQUENT" then
      if payload.unit then
        RefreshListedUnit(payload.unit)
      end
      return
    end

    if event == "UNIT_DISPLAYPOWER" then
      if payload.unit then
        RefreshListedUnit(payload.unit)
      end
      return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      NoteIncomingFromCombatLog(payload)
      CheckCombatLog(payload)
      CheckPvpCombat(payload)

      if payload.unitDiedSelf == true then
        PromptDeathGankers()
      else
        if payload.subevent == "UNIT_DIED" then
          if payload.destinationIsSelf == true then
            PromptDeathGankers()
          end
        end
      end

      return
    end

    if event == "PLAYER_DEAD" then
      PromptDeathGankers()
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
    GetFriendlyCombatants = GetFriendlyCombatants,
    ClearPvpCombatants = ClearPvpCombatants,
    DismissPvpCombatant = DismissPvpCombatant,
    DismissFriendlyCombatant = DismissFriendlyCombatant,
    PruneStaleCombatants = PruneStaleCombatants,
    ConfirmClickTarget = ConfirmClickTarget,
    SyncPlayerFriendly = function()
      NoteSelfFriendly("player")
    end,
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
    NeedsInspect = function(name)
      return needsInspect.has(name)
    end,
    GetDeathSuspects = CollectDeathSuspects,
  }
end

Core.EVENTS = EVENTS
Core.MAX_PVP_COMBATANTS = MAX_PVP_COMBATANTS
Core.ATTACKER_WINDOW_MS = ATTACKER_WINDOW_MS
