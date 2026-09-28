describe("OlympusPVP AddonController", function()
  local AddonController

  before_each(function()
    OlympusPVP = nil
    dofile("Types.lua")
    dofile("AddonController.lua")
    AddonController = OlympusPVP.AddonController
  end)

  local function CreateFixture()
    local toggleCount = 0
    local resetCount = 0
    local clearCount = 0
    local chatMessages = {}

    local controller = AddonController.Create({
      settingsPanel = {
        Toggle = function()
          toggleCount = toggleCount + 1
        end,
      },
      resetSettings = function()
        resetCount = resetCount + 1
      end,
      clearPvpCombatants = function()
        clearCount = clearCount + 1
      end,
      printToChat = function(message)
        chatMessages[#chatMessages + 1] = message
      end,
    })

    return {
      controller = controller,
      chatMessages = chatMessages,
      getToggleCount = function()
        return toggleCount
      end,
      getResetCount = function()
        return resetCount
      end,
      getClearCount = function()
        return clearCount
      end,
    }
  end

  it("toggles the panel for a blank command", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("")

    assert.are.equal(1, fixture.getToggleCount())
  end)

  it("clears frames for pvpclear", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("pvpclear")

    assert.are.equal(1, fixture.getClearCount())
    assert.are.equal("[Olympus PVP] Enemy and friendly frames cleared.", fixture.chatMessages[1])
  end)

  it("resets settings", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("reset")

    assert.are.equal(1, fixture.getResetCount())
  end)
end)
