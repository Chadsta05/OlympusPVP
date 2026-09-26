--[[
  OlympusPVP.SettingsPanel

  Gank-list and panel visibility. Frame widgets live in RaidFrames.
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.SettingsPanel = OlympusPVP.SettingsPanel or {}

---@type table
local SettingsPanel = OlympusPVP.SettingsPanel

---@param value string
---@return string
local function Trim(value)
  return (value:match("^%s*(.-)%s*$")) or ""
end

---@param dependencies table
---@return table
function SettingsPanel.Create(dependencies)
  local visible = false
  local panel = {}

  function panel.Open()
    visible = true
  end

  function panel.Close()
    visible = false
  end

  function panel.Toggle()
    if visible then
      panel.Close()
      return
    end

    panel.Open()
  end

  function panel.IsVisible()
    return visible
  end

  ---@param name string
  ---@return OlympusPVPSettings
  function panel.AddGank(name)
    local trimmedName = Trim(name)

    if trimmedName == "" then
      return dependencies.getSettings()
    end

    local settings = dependencies.getSettings()
    ---@type string[]
    local gankNames = {}
    local index = 1
    local alreadyExists = false
    local normalizedName = string.lower(trimmedName)

    while index <= #settings.gankNames do
      gankNames[index] = settings.gankNames[index]

      if string.lower(settings.gankNames[index]) == normalizedName then
        alreadyExists = true
      end

      index = index + 1
    end

    if not alreadyExists then
      gankNames[#gankNames + 1] = trimmedName
    end

    return dependencies.updateSettings({
      gankNames = gankNames,
    })
  end

  ---@param name string
  ---@return OlympusPVPSettings
  function panel.RemoveGank(name)
    local settings = dependencies.getSettings()
    local normalizedName = string.lower(Trim(name))
    ---@type string[]
    local gankNames = {}
    local index = 1

    while index <= #settings.gankNames do
      if string.lower(settings.gankNames[index]) ~= normalizedName then
        gankNames[#gankNames + 1] = settings.gankNames[index]
      end

      index = index + 1
    end

    return dependencies.updateSettings({
      gankNames = gankNames,
    })
  end

  return panel
end
