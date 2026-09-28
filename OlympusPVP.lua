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

  if OlympusPVP.scanner.PruneStaleCombatants then
    OlympusPVP.scanner.PruneStaleCombatants()
  end

  RaidFrames.Refresh(OlympusPVP.scanner.GetPvpCombatants())

  if OlympusPVP.scanner.GetFriendlyCombatants then
    RaidFrames.RefreshFriendly(OlympusPVP.scanner.GetFriendlyCombatants())
  end
end

local function Boot()
  OlympusPVPDB = OlympusPVPDB or {}

  local dependencies = WowBridge.CreateDependencies()
  local settingsStore = Settings.CreateSettingsStore(OlympusPVPDB.settings)

  local originalUpdate = settingsStore.UpdateSettings

  function settingsStore.UpdateSettings(changes)
    local nextSettings = originalUpdate(changes)
    OlympusPVPDB.settings = nextSettings

    if OlympusPVP.scanner then
      if OlympusPVP.scanner.SyncPlayerFriendly then
        OlympusPVP.scanner.SyncPlayerFriendly()
      end
    end

    RefreshFrames()
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

  if WowBridge.SetUiRefresh then
    WowBridge.SetUiRefresh(RefreshFrames)
  end

  local scanner = Core.CreateScanner(dependencies)

  RaidFrames.SetOnDismiss(function(name)
    scanner.DismissPvpCombatant(name)
    RefreshFrames()
  end)

  if RaidFrames.SetOnFriendlyDismiss then
    RaidFrames.SetOnFriendlyDismiss(function(name)
      scanner.DismissFriendlyCombatant(name)
      RefreshFrames()
    end)
  end

  if RaidFrames.SetOnClickTarget then
    RaidFrames.SetOnClickTarget(function(name)
      if scanner.ConfirmClickTarget then
        scanner.ConfirmClickTarget(name)
      end

      RefreshFrames()
    end)
  end

  if RaidFrames.SetPauseControl then
    RaidFrames.SetPauseControl({
      getPaused = function()
        return settingsStore.GetSettings().enemyListPaused == true
      end,
      setPaused = function(paused)
        settingsStore.UpdateSettings({
          enemyListPaused = paused == true,
        })
      end,
    }, {
      getPaused = function()
        return settingsStore.GetSettings().friendlyListPaused == true
      end,
      setPaused = function(paused)
        settingsStore.UpdateSettings({
          friendlyListPaused = paused == true,
        })
      end,
    })
  end

  local settingsPanel = SettingsPanel.Create({
    getSettings = settingsStore.GetSettings,
    updateSettings = settingsStore.UpdateSettings,
  })

  dependencies.promptDeathGankers = function(names)
    settingsPanel.PromptDeathGankers(names)
  end

  local controller = AddonController.Create({
    settingsPanel = settingsPanel,
    resetSettings = function()
      settingsStore.ResetSettings()

      if settingsPanel.Refresh then
        settingsPanel.Refresh()
      end
    end,
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
  RefreshFrames()
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
