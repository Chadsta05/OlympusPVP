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
    local warnings = {}
    local chatMessages = {}
    local requested = {}
    local queued = {}

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
      unitName = function()
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
        return true
      end,
      unitTargetsPlayer = function()
        return unitTargetsPlayer
      end,
      inspectPvpName = function(name)
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
    })

    return {
      scanner = scanner,
      store = store,
      warnings = warnings,
      chatMessages = chatMessages,
      requested = requested,
      queued = queued,
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
    }
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
end)
