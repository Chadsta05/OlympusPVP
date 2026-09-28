describe("OlympusPVP Core", function()
  local Core
  local Settings

  before_each(function()
    OlympusPVP = nil
    dofile("Types.lua")
    dofile("Settings.lua")
    dofile("ClassColors.lua")
    dofile("PvpLayout.lua")
    dofile("GankPointer.lua")
    dofile("Core.lua")
    Core = OlympusPVP.Core
    Settings = OlympusPVP.Settings
  end)

  local function CreateFixture(options)
    options = options or {}

    local store = Settings.CreateSettingsStore(options.settings)
    local currentTime = options.currentTime or 1000
    local currentUnitName = options.unitName
    local currentInstanceType = options.instanceType or "none"
    local unitPosition = options.unitPosition
    local unitTargetsPlayer = options.unitTargetsPlayer == true
    local unitIsPlayer = true

    if options.unitIsPlayer == false then
      unitIsPlayer = false
    end
    local relation = options.relation or {
      faction = "Horde",
      playerFaction = "Alliance",
      reaction = 2,
      canAttack = true,
      isEnemy = true,
      sameFaction = false,
      inGroup = false,
    }
    local warnings = {}
    local chatMessages = {}
    local requested = {}
    local queued = {}
    local inspectByUnit = options.inspectByUnit or {}
    local skipNameInspect = options.skipNameInspect == true
    local deathPrompts = {}

    local scanner = Core.CreateScanner({
      getZoneText = function()
        return "Elwynn Forest"
      end,
      getSubZoneText = function()
        return "Goldshire"
      end,
      getPlayerPosition = function()
        return {
          x = 42.5,
          y = 61.25,
          mapId = "1429",
        }
      end,
      unitExists = function()
        return true
      end,
      unitName = function(unit)
        if unit == "player" then
          return "Chadsta05"
        end

        return currentUnitName
      end,
      showRaidWarning = function(message)
        warnings[#warnings + 1] = message
      end,
      printToChat = function(message)
        chatMessages[#chatMessages + 1] = message
      end,
      playRaidWarningSound = function() end,
      requestTarget = function(name)
        requested[#requested + 1] = name
      end,
      registerEvent = function() end,
      now = function()
        return currentTime
      end,
      getSettings = store.GetSettings,
      getPlayerName = function()
        return "Chadsta05"
      end,
      unitIsPlayer = function()
        return unitIsPlayer
      end,
      unitTargetsPlayer = function()
        return unitTargetsPlayer
      end,
      inspectPvpName = function(name)
        if skipNameInspect then
          return nil
        end

        local className = "Warrior"

        if string.find(name, "Rogue") then
          className = "Rogue"
        end

        return {
          className = className,
          level = 60,
          healthPercent = 80,
          powerPercent = 45,
        }
      end,
      inspectPvpUnit = function(unit)
        return inspectByUnit[unit]
      end,
      inspectUnitRelation = function()
        return relation
      end,
      queuePvpTarget = function(name)
        queued[#queued + 1] = name
      end,
      getUnitPosition = function()
        return unitPosition
      end,
      getPlayerFacingDegrees = function()
        return 0
      end,
      getInstanceType = function()
        return currentInstanceType
      end,
      promptDeathGankers = function(names)
        deathPrompts[#deathPrompts + 1] = names
      end,
    })

    return {
      scanner = scanner,
      store = store,
      warnings = warnings,
      chatMessages = chatMessages,
      requested = requested,
      queued = queued,
      deathPrompts = deathPrompts,
      setTime = function(time)
        currentTime = time
      end,
      setUnitName = function(name)
        currentUnitName = name
      end,
      setInstanceType = function(instanceType)
        currentInstanceType = instanceType
      end,
      setUnitTargetsPlayer = function(value)
        unitTargetsPlayer = value
      end,
      setRelation = function(nextRelation)
        relation = nextRelation
      end,
    }
  end

  local function FriendlyNames(scanner)
    local combatants = scanner.GetFriendlyCombatants()
    local names = {}
    local index = 1

    while index <= #combatants do
      names[index] = combatants[index].name
      index = index + 1
    end

    return names
  end

  local function Names(scanner)
    local combatants = scanner.GetPvpCombatants()
    local names = {}
    local index = 1

    while index <= #combatants do
      names[index] = combatants[index].name
      index = index + 1
    end

    return names
  end

  it("normalizes Forever full names", function()
    assert.are.equal("donald trump", Core.NormalizeName("  Donald Trump  "))
    assert.is_nil(Core.NormalizeName("   "))
  end)

  it("queues a frame when you target a player without alerting", function()
    local fixture = CreateFixture({
      unitName = "Enemy Rogue",
    })

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")

    assert.same({ "Enemy Rogue" }, Names(fixture.scanner))
    assert.same({ "Enemy Rogue" }, fixture.queued)
    assert.are.equal(0, #fixture.warnings)
  end)

  it("keeps first-seen order when the same player is seen again", function()
    local fixture = CreateFixture({
      unitName = "Enemy Rogue",
    })

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")
    fixture.setUnitName("Horde Mage")
    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")
    fixture.setUnitName("Enemy Rogue")
    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")

    assert.same({ "Enemy Rogue", "Horde Mage" }, Names(fixture.scanner))
    assert.are.equal(2, #fixture.queued)
  end)

  it("clears frames on login", function()
    local fixture = CreateFixture({
      unitName = "Enemy Rogue",
    })

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")
    fixture.scanner.HandleEvent("PLAYER_LOGIN")

    assert.same({}, Names(fixture.scanner))
  end)

  it("clears frames when leaving a battleground", function()
    local fixture = CreateFixture({
      unitName = "Enemy Rogue",
      instanceType = "pvp",
    })

    fixture.scanner.HandleEvent("PLAYER_ENTERING_WORLD")
    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")
    fixture.setInstanceType("none")
    fixture.scanner.HandleEvent("PLAYER_ENTERING_WORLD")

    assert.same({}, Names(fixture.scanner))
  end)

  it("evicts the stalest frame at the 40 cap", function()
    local fixture = CreateFixture()
    local index = 1

    while index <= Core.MAX_PVP_COMBATANTS do
      fixture.setTime(index * 1000)
      fixture.scanner.NotePvpPlayer("Horde " .. tostring(index))
      index = index + 1
    end

    fixture.setTime(50000)
    fixture.scanner.NotePvpPlayer("Horde 1")
    fixture.setTime(60000)
    fixture.scanner.NotePvpPlayer("Fresh Rogue")

    local names = Names(fixture.scanner)

    assert.are.equal(40, #names)
    assert.are.equal("Horde 1", names[1])
    assert.are.equal("Fresh Rogue", names[#names])

    local foundTwo = false
    index = 1

    while index <= #names do
      if names[index] == "Horde 2" then
        foundTwo = true
      end

      index = index + 1
    end

    assert.is_false(foundTwo)
  end)

  it("raid-warns a ganker with coordinates", function()
    local fixture = CreateFixture({
      unitName = "Stad Swipe",
      unitPosition = {
        x = 48,
        y = 55,
        mapId = "1429",
      },
      settings = {
        gankNames = { "Stad Swipe" },
      },
    })

    fixture.scanner.CheckUnit("nameplate1", "nameplate")

    assert.are.equal("Stad Swipe GANKER at 48.0, 55.0", fixture.warnings[1])
    assert.are.equal("Stad Swipe", fixture.requested[1])
    assert.are.equal(48, fixture.scanner.GetLastGankSighting().x)
  end)

  it("points the needle north when the ganker is north", function()
    local fixture = CreateFixture({
      unitName = "Stad Swipe",
      unitPosition = {
        x = 42.5,
        y = 50,
        mapId = "1429",
      },
      settings = {
        gankNames = { "Stad Swipe" },
      },
    })

    fixture.scanner.CheckUnit("nameplate1", "nameplate")

    local pointer = fixture.scanner.GetGankPointer()

    assert.are.equal("Stad Swipe", pointer.name)
    assert.is_true(math.abs(pointer.needleDegrees) < 0.001)
  end)

  it("does not queue the local player", function()
    local fixture = CreateFixture({
      unitName = "Chadsta05",
    })

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")

    assert.same({}, Names(fixture.scanner))
  end)

  it("can pin the local player on the friendly board for heals", function()
    local fixture = CreateFixture({
      unitName = "Horde Rogue",
      settings = {
        includeSelfOnFriendly = true,
      },
    })

    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "player" })

    assert.same({ "Chadsta05" }, FriendlyNames(fixture.scanner))
    assert.same({}, Names(fixture.scanner))

    fixture.scanner.ConfirmClickTarget("Chadsta05")
    assert.same({ "Chadsta05" }, FriendlyNames(fixture.scanner))

    fixture.store.UpdateSettings({
      includeSelfOnFriendly = false,
    })
    fixture.scanner.SyncPlayerFriendly()

    assert.same({}, FriendlyNames(fixture.scanner))
  end)

  it("does not add new enemies while the enemy list is paused", function()
    local fixture = CreateFixture({
      unitName = "Horde Rogue",
      settings = {
        enemyListPaused = true,
      },
    })

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")

    assert.same({}, Names(fixture.scanner))
  end)

  it("does not add new friendlies while the friendly list is paused", function()
    local fixture = CreateFixture({
      unitName = "Tilds Telemand",
      settings = {
        friendlyModeEnabled = true,
        friendlyListPaused = true,
      },
      relation = {
        faction = "Alliance",
        playerFaction = "Alliance",
        reaction = 5,
        canAttack = false,
        isEnemy = false,
        sameFaction = true,
        inGroup = false,
      },
    })

    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "nameplate1" })

    assert.same({}, FriendlyNames(fixture.scanner))
  end)

  it("drops enemies who have not been seen in range", function()
    local fixture = CreateFixture({
      unitName = "Horde Rogue",
    })

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")
    fixture.setTime(12000)
    fixture.scanner.PruneStaleCombatants()

    assert.same({}, Names(fixture.scanner))
  end)

  it("keeps paused enemies even when they leave range", function()
    local fixture = CreateFixture({
      unitName = "Horde Rogue",
    })

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")
    fixture.store.UpdateSettings({
      enemyListPaused = true,
    })
    fixture.setTime(12000)
    fixture.scanner.PruneStaleCombatants()

    assert.same({ "Horde Rogue" }, Names(fixture.scanner))
  end)

  it("removes a frame when a click does not acquire that target", function()
    local fixture = CreateFixture({
      unitName = "Horde Rogue",
    })

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")
    fixture.setUnitName("Someone Else")
    fixture.scanner.ConfirmClickTarget("Horde Rogue")

    assert.same({}, Names(fixture.scanner))
  end)

  it("keeps same-faction players off the enemy list", function()
    local fixture = CreateFixture({
      unitName = "Tilds Telemand",
      relation = {
        faction = "Alliance",
        playerFaction = "Alliance",
        reaction = 5,
        canAttack = false,
        isEnemy = false,
        sameFaction = true,
        inGroup = false,
      },
    })

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")
    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "nameplate1" })

    assert.same({}, Names(fixture.scanner))
    assert.same({}, FriendlyNames(fixture.scanner))
  end)

  it("puts same-faction open-world players on a separate friendly list", function()
    local fixture = CreateFixture({
      unitName = "Tilds Telemand",
      settings = {
        friendlyModeEnabled = true,
      },
      relation = {
        faction = "Alliance",
        playerFaction = "Alliance",
        reaction = 5,
        canAttack = false,
        isEnemy = false,
        sameFaction = true,
        inGroup = false,
      },
    })

    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "nameplate1" })

    assert.same({}, Names(fixture.scanner))
    assert.same({ "Tilds Telemand" }, FriendlyNames(fixture.scanner))
  end)

  it("puts group members on the friendly list", function()
    local fixture = CreateFixture({
      unitName = "Party Paladin",
      settings = {
        friendlyModeEnabled = false,
        includeGroupOnFriendly = true,
      },
      relation = {
        faction = "Alliance",
        playerFaction = "Alliance",
        reaction = 5,
        canAttack = false,
        isEnemy = false,
        sameFaction = true,
        inGroup = true,
      },
    })

    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "party1" })

    assert.same({}, Names(fixture.scanner))
    assert.same({ "Party Paladin" }, FriendlyNames(fixture.scanner))
  end)

  it("can skip group members on the friendly list", function()
    local fixture = CreateFixture({
      unitName = "Party Paladin",
      settings = {
        friendlyModeEnabled = true,
        includeGroupOnFriendly = false,
      },
      relation = {
        faction = "Alliance",
        playerFaction = "Alliance",
        reaction = 5,
        canAttack = false,
        isEnemy = false,
        sameFaction = true,
        inGroup = true,
      },
    })

    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "party1" })

    assert.same({}, Names(fixture.scanner))
    assert.same({}, FriendlyNames(fixture.scanner))
  end)

  it("adds hostile players from nameplates before combat", function()
    local fixture = CreateFixture({
      unitName = "Horde Rogue",
    })

    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "nameplate1" })

    assert.same({ "Horde Rogue" }, Names(fixture.scanner))
    assert.same({}, FriendlyNames(fixture.scanner))
  end)

  it("updates listed health when the nameplate unit changes", function()
    local inspectByUnit = {
      nameplate1 = {
        className = "Rogue",
        healthPercent = 80,
        powerPercent = 50,
        powerType = "energy",
      },
    }
    local fixture = CreateFixture({
      unitName = "Horde Rogue",
      inspectByUnit = inspectByUnit,
    })

    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "nameplate1" })
    inspectByUnit.nameplate1 = {
      className = "Rogue",
      healthPercent = 22,
      powerPercent = 8,
      powerType = "energy",
    }
    fixture.scanner.HandleEvent("UNIT_HEALTH", { unit = "nameplate1" })

    local combatant = fixture.scanner.GetPvpCombatants()[1]
    assert.are.equal(22, combatant.healthPercent)
    assert.are.equal(8, combatant.powerPercent)
  end)

  it("does not add enemy npcs to targetable frames", function()
    local fixture = CreateFixture({
      unitName = "Defias Thug",
      unitIsPlayer = false,
    })

    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "nameplate1" })
    fixture.scanner.HandleEvent("COMBAT_LOG_EVENT_UNFILTERED", {
      sourceName = "Defias Thug",
      destinationName = "Chadsta05",
      destinationIsSelf = true,
      isDamage = true,
    })

    assert.same({}, Names(fixture.scanner))
  end)

  it("puts incomplete nameplate inspect on a set and fills it from target", function()
    local fixture = CreateFixture({
      unitName = "Cat Druid",
      skipNameInspect = true,
      inspectByUnit = {
        target = {
          className = "Druid",
          level = 60,
          healthPercent = 42,
          powerPercent = 80,
          powerType = "energy",
        },
      },
    })

    fixture.scanner.HandleEvent("NAME_PLATE_UNIT_ADDED", { unit = "nameplate1" })

    local scanned = fixture.scanner.GetPvpCombatants()[1]
    assert.is_nil(scanned.className)
    assert.is_true(fixture.scanner.NeedsInspect("Cat Druid"))

    fixture.scanner.HandleEvent("PLAYER_TARGET_CHANGED")

    local filled = fixture.scanner.GetPvpCombatants()[1]
    assert.are.equal("Druid", filled.className)
    assert.are.equal(60, filled.level)
    assert.are.equal(42, filled.healthPercent)
    assert.is_false(fixture.scanner.NeedsInspect("Cat Druid"))
  end)

  it("prompts ganker marks for names that damaged you before death", function()
    local fixture = CreateFixture()

    fixture.scanner.HandleEvent("COMBAT_LOG_EVENT_UNFILTERED", {
      sourceName = "Stad Swipe",
      destinationName = "Chadsta05",
      destinationIsSelf = true,
      isDamage = true,
    })
    fixture.scanner.HandleEvent("COMBAT_LOG_EVENT_UNFILTERED", {
      sourceName = "Horde Rogue",
      destinationName = "Chadsta05",
      destinationIsSelf = true,
      isDamage = true,
    })
    fixture.scanner.HandleEvent("PLAYER_DEAD")

    assert.same({ { "Horde Rogue", "Stad Swipe" } }, fixture.deathPrompts)
  end)

  it("prompts from combat-log self death when dest is marked self", function()
    local fixture = CreateFixture()

    fixture.scanner.HandleEvent("COMBAT_LOG_EVENT_UNFILTERED", {
      sourceName = "Stad Swipe",
      destinationIsSelf = true,
      isDamage = true,
    })
    fixture.scanner.HandleEvent("COMBAT_LOG_EVENT_UNFILTERED", {
      subevent = "UNIT_DIED",
      destinationIsSelf = true,
      unitDiedSelf = true,
    })

    assert.same({ { "Stad Swipe" } }, fixture.deathPrompts)
  end)

  it("skips death ganker prompts in battlegrounds", function()
    local fixture = CreateFixture({
      instanceType = "pvp",
    })

    fixture.scanner.HandleEvent("COMBAT_LOG_EVENT_UNFILTERED", {
      sourceName = "Stad Swipe",
      destinationName = "Chadsta05",
      destinationIsSelf = true,
      isDamage = true,
    })
    fixture.scanner.HandleEvent("PLAYER_DEAD")

    assert.same({}, fixture.deathPrompts)
  end)
end)
