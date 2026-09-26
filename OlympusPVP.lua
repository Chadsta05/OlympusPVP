--[[
  OlympusPVP boot
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}

---@type table
local Settings = OlympusPVP.Settings
---@type table
local Core = OlympusPVP.Core
---@type table
local AddonController = OlympusPVP.AddonController
---@type table
local SettingsPanel = OlympusPVP.SettingsPanel
---@type table
local WowBridge = OlympusPVP.WowBridge
---@type table
local RaidFrames = OlympusPVP.RaidFrames

function OlympusPVP.PersistSettings()
  if not OlympusPVP.settingsStore then
    return
  end

  OlympusPVPDB = OlympusPVPDB or {}
  OlympusPVPDB.settings = OlympusPVP.settingsStore.GetSettings()
end

local function RefreshFrames()
  if not OlympusPVP.scanner then
    return
  end

  RaidFrames.Refresh(OlympusPVP.scanner.GetPvpCombatants())
end

local function Boot()
  OlympusPVPDB = OlympusPVPDB or {}

  local dependencies = WowBridge.CreateDependencies()
  local settingsStore = Settings.CreateSettingsStore(OlympusPVPDB.settings)

  local originalUpdate = settingsStore.UpdateSettings

  function settingsStore.UpdateSettings(changes)
    local nextSettings = originalUpdate(changes)
    OlympusPVPDB.settings = nextSettings
    return nextSettings
  end

  local originalReset = settingsStore.ResetSettings

  function settingsStore.ResetSettings()
    local nextSettings = originalReset()
    OlympusPVPDB.settings = nextSettings
    return nextSettings
  end

  local originalQueue = dependencies.queuePvpTarget

  dependencies.getSettings = settingsStore.GetSettings
  dependencies.queuePvpTarget = function(name)
    if originalQueue then
      originalQueue(name)
    end

    RefreshFrames()
  end

  local scanner = Core.CreateScanner(dependencies)

  local settingsPanel = SettingsPanel.Create({
    getSettings = settingsStore.GetSettings,
    updateSettings = settingsStore.UpdateSettings,
  })

  local controller = AddonController.Create({
    settingsPanel = settingsPanel,
    resetSettings = settingsStore.ResetSettings,
    printToChat = dependencies.printToChat,
    clearPvpCombatants = function()
      scanner.ClearPvpCombatants()
      RefreshFrames()
    end,
  })

  OlympusPVP.settingsStore = settingsStore
  OlympusPVP.scanner = scanner
  OlympusPVP.settingsPanel = settingsPanel
  OlympusPVP.controller = controller

  if dependencies.registerSlashCommand then
    dependencies.registerSlashCommand(controller.HandleSlashCommand)
  end

  scanner.Start()
end

if CreateFrame then
  local bootFrame = CreateFrame("Frame", "OlympusPVPBootFrame")
  bootFrame:RegisterEvent("ADDON_LOADED")

  bootFrame:SetScript("OnEvent", function(self, event, addonName)
    if event ~= "ADDON_LOADED" then
      return
    end

    if addonName ~= "OlympusPVP" then
      return
    end

    Boot()

    if OlympusPVP.scanner then
      OlympusPVP.scanner.HandleEvent("PLAYER_LOGIN")
    end

    self:UnregisterEvent("ADDON_LOADED")
  end)
end
