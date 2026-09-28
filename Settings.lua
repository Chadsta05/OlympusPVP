--[[
  OlympusPVP.Settings
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.Settings = OlympusPVP.Settings or {}

---@type table
local Settings = OlympusPVP.Settings

---@type OlympusPVPSettings
local DEFAULT_SETTINGS = {
  enabled = true,
  alertCooldownMs = 10000,
  raidWarningEnabled = true,
  soundEnabled = true,
  chatEnabled = true,
  pvpModeEnabled = true,
  friendlyModeEnabled = false,
  enemyListPaused = false,
  friendlyListPaused = false,
  gankNames = {},
}

---@param names? string[]
---@return string[]
local function CopyNames(names)
  ---@type string[]
  local copy = {}
  if not names then
    return copy
  end

  local index = 1
  while index <= #names do
    copy[index] = names[index]
    index = index + 1
  end

  return copy
end

---@return OlympusPVPSettings
function Settings.CreateDefaultSettings()
  return {
    enabled = DEFAULT_SETTINGS.enabled,
    alertCooldownMs = DEFAULT_SETTINGS.alertCooldownMs,
    raidWarningEnabled = DEFAULT_SETTINGS.raidWarningEnabled,
    soundEnabled = DEFAULT_SETTINGS.soundEnabled,
    chatEnabled = DEFAULT_SETTINGS.chatEnabled,
    pvpModeEnabled = DEFAULT_SETTINGS.pvpModeEnabled,
    friendlyModeEnabled = DEFAULT_SETTINGS.friendlyModeEnabled,
    enemyListPaused = DEFAULT_SETTINGS.enemyListPaused,
    friendlyListPaused = DEFAULT_SETTINGS.friendlyListPaused,
    gankNames = CopyNames(DEFAULT_SETTINGS.gankNames),
  }
end

---@param settings OlympusPVPSettings
---@return OlympusPVPSettings
function Settings.CloneSettings(settings)
  return {
    enabled = settings.enabled,
    alertCooldownMs = settings.alertCooldownMs,
    raidWarningEnabled = settings.raidWarningEnabled,
    soundEnabled = settings.soundEnabled,
    chatEnabled = settings.chatEnabled,
    pvpModeEnabled = settings.pvpModeEnabled,
    friendlyModeEnabled = settings.friendlyModeEnabled,
    enemyListPaused = settings.enemyListPaused,
    friendlyListPaused = settings.friendlyListPaused,
    gankNames = CopyNames(settings.gankNames),
  }
end

---@param saved? PartialOlympusPVPSettings
---@return OlympusPVPSettings
function Settings.MergeSettings(saved)
  local merged = Settings.CreateDefaultSettings()

  if not saved then
    return merged
  end

  if saved.enabled ~= nil then
    merged.enabled = saved.enabled
  end

  if saved.alertCooldownMs ~= nil then
    merged.alertCooldownMs = saved.alertCooldownMs
  end

  if saved.raidWarningEnabled ~= nil then
    merged.raidWarningEnabled = saved.raidWarningEnabled
  end

  if saved.soundEnabled ~= nil then
    merged.soundEnabled = saved.soundEnabled
  end

  if saved.chatEnabled ~= nil then
    merged.chatEnabled = saved.chatEnabled
  end

  if saved.pvpModeEnabled ~= nil then
    merged.pvpModeEnabled = saved.pvpModeEnabled
  end

  if saved.friendlyModeEnabled ~= nil then
    merged.friendlyModeEnabled = saved.friendlyModeEnabled
  end

  if saved.enemyListPaused ~= nil then
    merged.enemyListPaused = saved.enemyListPaused
  end

  if saved.friendlyListPaused ~= nil then
    merged.friendlyListPaused = saved.friendlyListPaused
  end

  if saved.gankNames then
    merged.gankNames = CopyNames(saved.gankNames)
  end

  return merged
end

---@param initialSettings? PartialOlympusPVPSettings
---@return OlympusPVPSettingsStore
function Settings.CreateSettingsStore(initialSettings)
  ---@type OlympusPVPSettings
  local settings = Settings.MergeSettings(initialSettings)

  ---@type OlympusPVPSettingsStore
  local store = {}

  function store.GetSettings()
    return Settings.CloneSettings(settings)
  end

  ---@param changes PartialOlympusPVPSettings
  ---@return OlympusPVPSettings
  function store.UpdateSettings(changes)
    local nextSettings = Settings.CloneSettings(settings)

    if changes.enabled ~= nil then
      nextSettings.enabled = changes.enabled
    end

    if changes.alertCooldownMs ~= nil then
      nextSettings.alertCooldownMs = changes.alertCooldownMs
    end

    if changes.raidWarningEnabled ~= nil then
      nextSettings.raidWarningEnabled = changes.raidWarningEnabled
    end

    if changes.soundEnabled ~= nil then
      nextSettings.soundEnabled = changes.soundEnabled
    end

    if changes.chatEnabled ~= nil then
      nextSettings.chatEnabled = changes.chatEnabled
    end

    if changes.pvpModeEnabled ~= nil then
      nextSettings.pvpModeEnabled = changes.pvpModeEnabled
    end

    if changes.friendlyModeEnabled ~= nil then
      nextSettings.friendlyModeEnabled = changes.friendlyModeEnabled
    end

    if changes.enemyListPaused ~= nil then
      nextSettings.enemyListPaused = changes.enemyListPaused
    end

    if changes.friendlyListPaused ~= nil then
      nextSettings.friendlyListPaused = changes.friendlyListPaused
    end

    if changes.gankNames ~= nil then
      nextSettings.gankNames = CopyNames(changes.gankNames)
    end

    settings = Settings.MergeSettings(nextSettings)
    return store.GetSettings()
  end

  function store.ResetSettings()
    settings = Settings.CreateDefaultSettings()
    return store.GetSettings()
  end

  return store
end

Settings.DEFAULT_SETTINGS = DEFAULT_SETTINGS
