--[[
  OlympusPVP.AddonController

  Slash: /olympus, /opvp
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.AddonController = OlympusPVP.AddonController or {}

---@type table
local AddonController = OlympusPVP.AddonController

---@param value? string
---@return string
local function Trim(value)
  if not value then
    return ""
  end

  return (value:match("^%s*(.-)%s*$")) or ""
end

---@param dependencies table
---@return table
function AddonController.Create(dependencies)
  local controller = {}

  local function ShowHelp()
    dependencies.printToChat("[Olympus PVP] Commands:")
    dependencies.printToChat("/olympus - Open or close settings")
    dependencies.printToChat("/olympus pvpclear - Clear PVP raid frames")
    dependencies.printToChat("/olympus reset - Reset settings")
    dependencies.printToChat("/olympus help - Show commands")
  end

  ---@param input? string
  function controller.HandleSlashCommand(input)
    local trimmedInput = Trim(input or "")

    if trimmedInput == "" then
      dependencies.settingsPanel.Toggle()
      return
    end

    local lowerInput = string.lower(trimmedInput)

    if lowerInput == "pvpclear" then
      if dependencies.clearPvpCombatants then
        dependencies.clearPvpCombatants()
      end

      dependencies.printToChat("[Olympus PVP] PVP frames cleared.")
      return
    end

    if lowerInput == "reset" then
      dependencies.resetSettings()
      dependencies.printToChat("[Olympus PVP] Settings reset.")
      return
    end

    ShowHelp()
  end

  return controller
end
