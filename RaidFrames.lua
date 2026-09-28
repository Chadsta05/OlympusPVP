--[[
  OlympusPVP.RaidFrames

  Two movable boards: enemy PVP and open-world friendly faction.
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.RaidFrames = OlympusPVP.RaidFrames or {}

---@type table
local RaidFrames = OlympusPVP.RaidFrames
---@type table
local PvpLayout = OlympusPVP.PvpLayout
---@type table
local TypeGuards = OlympusPVP.TypeGuards
---@type table
local ClassColors = OlympusPVP.ClassColors

---@type number
local MAX_FRAMES = 40
---@type number
local GAP_PX = 3
---@type number
local CLASS_STRIPE_PX = 6
---@type number
local DISMISS_PX = 18
---@type number
local DISMISS_GAP_PX = 3
---@type number
local HEALTH_GREEN_R = 0.15
---@type number
local HEALTH_GREEN_G = 0.82
---@type number
local HEALTH_GREEN_B = 0.18

---@param kind string
---@return table
local function BoardPalette(kind)
  if kind == "friendly" then
    return {
      fillR = 0.06,
      fillG = 0.08,
      fillB = 0.11,
      bannerR = 0.16,
      bannerG = 0.24,
      bannerB = 0.34,
      dismissR = 0.18,
      dismissG = 0.24,
      dismissB = 0.32,
    }
  end

  return {
    fillR = 0.11,
    fillG = 0.06,
    fillB = 0.05,
    bannerR = 0.34,
    bannerG = 0.16,
    bannerB = 0.14,
    dismissR = 0.32,
    dismissG = 0.12,
    dismissB = 0.1,
  }
end

---@param name string
---@return string?
function RaidFrames.BuildTargetMacro(name)
  if not TypeGuards then
    local trimmed = name:match("^%s*(.-)%s*$")

    if trimmed == "" then
      return nil
    end

    return "/cleartarget\n/targetexact " .. trimmed
  end

  local trimmed = TypeGuards.ExpectPublicString("RaidFrames.BuildTargetMacro", name)

  if not trimmed then
    return nil
  end

  trimmed = trimmed:match("^%s*(.-)%s*$")

  if not TypeGuards.ExpectPublicString("RaidFrames.BuildTargetMacro.trimmed", trimmed) then
    return nil
  end

  return "/cleartarget\n/targetexact " .. trimmed
end

---@param count number
---@return table
function RaidFrames.LayoutForCount(count)
  return {
    columnSize = PvpLayout.ColumnSize(count),
    frameSize = PvpLayout.FrameSizePx(count),
    frameWidth = PvpLayout.FrameWidthPx(count),
    gridHeight = PvpLayout.GridHeightPx(count),
  }
end

---@param powerType string
---@return number
---@return number
---@return number
local function PowerRgb(powerType)
  if powerType == "rage" then
    return 0.77, 0.12, 0.23
  end

  if powerType == "energy" then
    return 0.83, 0.63, 0.09
  end

  if powerType == "runic_power" then
    return 0, 0.82, 1
  end

  if powerType == "runic" then
    return 0, 0.82, 1
  end

  if powerType == "focus" then
    return 1, 0.5, 0.25
  end

  if powerType == "fury" then
    return 0.79, 0.26, 0.99
  end

  if powerType == "chi" then
    return 0.6, 1, 0.88
  end

  return 0.16, 0.51, 0.85
end

---@param bar any
---@param unit string
---@param currentFn function
---@param maxFn function
---@param powerIndex? number
---@return boolean
local function ApplyLiveResource(bar, unit, currentFn, maxFn, powerIndex)
  if not bar then
    return false
  end

  if not currentFn then
    return false
  end

  if not maxFn then
    return false
  end

  if not UnitExists then
    return false
  end

  if not TypeGuards then
    return false
  end

  if not TypeGuards.IsWowTruthy(UnitExists(unit)) then
    return false
  end

  local ok = pcall(function()
    local maxValue
    local currentValue

    if powerIndex then
      maxValue = maxFn(unit, powerIndex)
      currentValue = currentFn(unit, powerIndex)
    else
      maxValue = maxFn(unit)
      currentValue = currentFn(unit)
    end

    bar:SetMinMaxValues(0, maxValue)
    bar:SetValue(currentValue)
  end)

  return ok == true
end

---@param name string
---@param preferred? string
---@return string?
local function FindLiveUnit(name, preferred)
  if not UnitExists then
    return preferred
  end

  ---@param unit string
  ---@return boolean
  local function UnitMatches(unit)
    if not TypeGuards.IsWowTruthy(UnitExists(unit)) then
      return false
    end

    if not UnitName then
      return false
    end

    local ok, unitName = pcall(UnitName, unit)

    if not ok then
      return false
    end

    if type(unitName) ~= "string" then
      return false
    end

    return string.lower(unitName) == string.lower(name)
  end

  if preferred then
    if TypeGuards.IsWowTruthy(UnitExists(preferred)) then
      return preferred
    end
  end

  if UnitMatches("target") then
    return "target"
  end

  if UnitMatches("focus") then
    return "focus"
  end

  if UnitMatches("mouseover") then
    return "mouseover"
  end

  local index = 1

  while index <= MAX_FRAMES do
    local unit = "nameplate" .. tostring(index)

    if UnitMatches(unit) then
      return unit
    end

    index = index + 1
  end

  return nil
end

local function InLockdown()
  if InCombatLockdown then
    if TypeGuards then
      return TypeGuards.IsWowTruthy(InCombatLockdown())
    end

    if InCombatLockdown() then
      return true
    end
  end

  return false
end

---@type number
local PAUSE_PX = 56

---@param fontString any
---@param compact boolean
local function ApplySlotFont(fontString, compact)
  if not fontString then
    return
  end

  if not GameFontHighlightSmall then
    return
  end

  if not GameFontHighlightSmall.GetFont then
    return
  end

  local path, height, flags = GameFontHighlightSmall:GetFont()

  if not path then
    return
  end

  local nextHeight = height

  if compact then
    nextHeight = 8
  end

  fontString:SetFont(path, nextHeight, flags)
end

---@param options table
---@return table
local function CreateBoard(options)
  ---@type OlympusPVPCombatant[]
  local lastCombatants = {}
  ---@type (fun(name: string))?
  local onDismiss
  ---@type (fun(name: string))?
  local onClickTarget
  ---@type string?
  local pendingClickName
  ---@type number
  local pendingClickWait = 0
  ---@type (fun(): boolean)?
  local getPaused
  ---@type (fun(paused: boolean))?
  local setPaused
  ---@type any?
  local stack
  ---@type any?
  local handle
  ---@type any?
  local pauseButton
  ---@type table
  local slots = {}
  ---@type boolean
  local built = false
  local board = {}

  local function EnsureStack()
    if built then
      return
    end

    if not CreateFrame then
      return
    end

    if InLockdown() then
      return
    end

    local palette = BoardPalette(options.kind)

    stack = CreateFrame("Frame", options.stackName, UIParent)
    stack:SetSize(200, 280)
    stack:SetPoint("TOPLEFT", UIParent, "TOPLEFT", options.offsetX, options.offsetY)
    stack:SetMovable(true)
    stack:SetClampedToScreen(true)
    stack:SetFrameStrata("HIGH")

    handle = CreateFrame("Button", options.handleName, stack)
    handle:SetSize(176, 20)
    handle:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, 0)
    handle:SetNormalFontObject("GameFontHighlightSmall")
    handle:SetText(options.title)

    ---@type any
    local handleFill = handle:CreateTexture(nil, "BACKGROUND")
    handleFill:SetAllPoints(handle)
    handleFill:SetColorTexture(palette.bannerR, palette.bannerG, palette.bannerB, 1)

    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
      if InLockdown() then
        return
      end

      stack:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
      stack:StopMovingOrSizing()
    end)

    pauseButton = CreateFrame("Button", options.handleName .. "Pause", stack)
    pauseButton:SetSize(PAUSE_PX, 20)
    pauseButton:SetPoint("TOPRIGHT", stack, "TOPRIGHT", 0, 0)
    pauseButton:SetNormalFontObject("GameFontHighlightSmall")
    pauseButton:SetText("Pause")

    ---@type any
    local pauseFill = pauseButton:CreateTexture(nil, "BACKGROUND")
    pauseFill:SetAllPoints(pauseButton)
    pauseFill:SetColorTexture(
      palette.bannerR * 0.7,
      palette.bannerG * 0.7,
      palette.bannerB * 0.7,
      1
    )
    pauseButton.pauseFill = pauseFill

    handle:ClearAllPoints()
    handle:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, 0)
    handle:SetPoint("TOPRIGHT", pauseButton, "TOPLEFT", -2, 0)

    local function SyncHeader()
      local paused = false

      if getPaused then
        paused = getPaused() == true
      end

      if paused then
        handle:SetText(options.titlePaused)
        pauseButton:SetText("Resume")
        pauseFill:SetColorTexture(0.28, 0.24, 0.1, 1)
      else
        handle:SetText(options.title)
        pauseButton:SetText("Pause")
        pauseFill:SetColorTexture(
          palette.bannerR * 0.7,
          palette.bannerG * 0.7,
          palette.bannerB * 0.7,
          1
        )
      end
    end

    pauseButton:SetScript("OnClick", function()
      local paused = false

      if getPaused then
        paused = getPaused() == true
      end

      if setPaused then
        setPaused(not paused)
      end

      SyncHeader()
    end)

    board.SyncHeader = SyncHeader

    local slotIndex = 1

    while slotIndex <= MAX_FRAMES do
      ---@type any
      local button = CreateFrame(
        "Button",
        options.buttonPrefix .. tostring(slotIndex),
        stack,
        "SecureActionButtonTemplate"
      )
      button:RegisterForClicks("AnyDown")
      button:SetAttribute("type", "macro")
      button:EnableMouse(true)
      button:Hide()
      button:SetScript("PostClick", function(self)
        local name = self.combatantName

        if not name then
          return
        end

        pendingClickName = name
        pendingClickWait = 0
      end)

      ---@type any
      local fill = button:CreateTexture(nil, "BACKGROUND")
      fill:SetColorTexture(palette.fillR, palette.fillG, palette.fillB, 0.96)
      fill:SetAllPoints(button)

      ---@type any
      local portrait = button:CreateTexture(nil, "ARTWORK")
      portrait:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
      portrait:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
      portrait:SetWidth(CLASS_STRIPE_PX)

      ---@type any
      local nameText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      nameText:SetJustifyH("LEFT")
      nameText:SetWordWrap(false)

      ---@type any
      local levelText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      levelText:SetJustifyH("RIGHT")

      ---@type any
      local healthBg = button:CreateTexture(nil, "ARTWORK")
      healthBg:SetColorTexture(0.08, 0.06, 0.04, 1)

      ---@type any
      local healthBar = CreateFrame("StatusBar", nil, button)
      healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
      healthBar:SetMinMaxValues(0, 100)
      healthBar:SetValue(100)
      healthBar:EnableMouse(false)

      ---@type any
      local powerBg = button:CreateTexture(nil, "ARTWORK")
      powerBg:SetColorTexture(0.08, 0.06, 0.04, 1)

      ---@type any
      local powerBar = CreateFrame("StatusBar", nil, button)
      powerBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
      powerBar:SetMinMaxValues(0, 100)
      powerBar:SetValue(100)
      powerBar:EnableMouse(false)

      ---@type any
      local dismiss = CreateFrame(
        "Button",
        options.dismissPrefix .. tostring(slotIndex),
        stack
      )
      dismiss:SetSize(DISMISS_PX, DISMISS_PX)
      dismiss:RegisterForClicks("LeftButtonUp")
      dismiss:EnableMouse(false)
      dismiss:SetFrameStrata("DIALOG")
      dismiss:Hide()

      ---@type any
      local dismissFill = dismiss:CreateTexture(nil, "BACKGROUND")
      dismissFill:SetAllPoints(dismiss)
      dismissFill:SetColorTexture(palette.dismissR, palette.dismissG, palette.dismissB, 1)

      ---@type any
      local dismissText = dismiss:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      dismissText:SetPoint("CENTER", dismiss, "CENTER", 0, 0)
      dismissText:SetText("X")

      dismiss:SetScript("OnClick", function(self)
        local name = self.combatantName

        if not name then
          return
        end

        if onDismiss then
          onDismiss(name)
        end
      end)

      slots[slotIndex] = {
        button = button,
        portrait = portrait,
        nameText = nameText,
        levelText = levelText,
        healthBg = healthBg,
        healthBar = healthBar,
        powerBg = powerBg,
        powerBar = powerBar,
        dismiss = dismiss,
      }

      slotIndex = slotIndex + 1
    end

    if stack.RegisterEvent then
      stack:RegisterEvent("PLAYER_REGEN_ENABLED")
      stack:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
          board.Refresh(lastCombatants)
        end
      end)
    end

    stack:SetScript("OnUpdate", function(_, elapsed)
      if not pendingClickName then
        return
      end

      if type(elapsed) ~= "number" then
        return
      end

      pendingClickWait = pendingClickWait + elapsed

      if pendingClickWait < 0.2 then
        return
      end

      local name = pendingClickName
      pendingClickName = nil
      pendingClickWait = 0

      if onClickTarget then
        onClickTarget(name)
      end
    end)

    built = true
  end

  ---@param callback fun(name: string)
  function board.SetOnDismiss(callback)
    onDismiss = callback
  end

  ---@param callback fun(name: string)
  function board.SetOnClickTarget(callback)
    onClickTarget = callback
  end

  ---@param control table
  function board.SetPauseControl(control)
    getPaused = control.getPaused
    setPaused = control.setPaused

    if built then
      if board.SyncHeader then
        board.SyncHeader()
      end
    end
  end

  ---@return OlympusPVPCombatant[]
  function board.GetLastCombatants()
    return lastCombatants
  end

  ---@param combatants OlympusPVPCombatant[]
  function board.Refresh(combatants)
    lastCombatants = combatants
    EnsureStack()

    if not built then
      return
    end

    local count = #combatants
    local size = PvpLayout.FrameSizePx(count)
    local width = PvpLayout.FrameWidthPx(count)
    local columnSize = PvpLayout.ColumnSize(count)
    local stride = width + DISMISS_GAP_PX + DISMISS_PX + GAP_PX
    local lockdown = InLockdown()
    local index = 1

    while index <= MAX_FRAMES do
      local slot = slots[index]
      local combatant = combatants[index]
      local row = (index - 1) % columnSize
      local col = math.floor((index - 1) / columnSize)
      local x = col * stride
      local y = -24 - row * (size + GAP_PX)

      if not lockdown then
        slot.button:ClearAllPoints()
        slot.button:SetSize(width, size)
        slot.button:SetPoint("TOPLEFT", stack, "TOPLEFT", x, y)
        slot.dismiss:ClearAllPoints()
        slot.dismiss:SetSize(DISMISS_PX, size)
        slot.dismiss:SetPoint("LEFT", slot.button, "RIGHT", DISMISS_GAP_PX, 0)
      end

      slot.dismiss:SetFrameLevel(slot.button:GetFrameLevel() + 40)

      local compact = size < 32
      local powerHeight = 4
      local healthHeight = 7
      local barGap = 1
      local bottomPad = 1

      if compact then
        healthHeight = 3
        powerHeight = 2
      end

      local powerBottom = bottomPad
      local healthBottom = bottomPad + powerHeight + barGap
      local nameBottom = healthBottom + healthHeight + 1

      ApplySlotFont(slot.nameText, compact)
      ApplySlotFont(slot.levelText, compact)

      local bodyLeft = CLASS_STRIPE_PX + 4
      slot.nameText:ClearAllPoints()
      slot.nameText:SetJustifyV("MIDDLE")
      slot.nameText:SetPoint("TOPLEFT", slot.button, "TOPLEFT", bodyLeft, -1)
      slot.nameText:SetPoint("BOTTOMRIGHT", slot.button, "BOTTOMRIGHT", -22, nameBottom)

      slot.levelText:ClearAllPoints()
      slot.levelText:SetJustifyV("MIDDLE")
      slot.levelText:SetPoint("TOPRIGHT", slot.button, "TOPRIGHT", -4, -1)
      slot.levelText:SetPoint("BOTTOM", slot.button, "BOTTOM", 0, nameBottom)

      slot.healthBg:ClearAllPoints()
      slot.healthBg:SetPoint("BOTTOMLEFT", slot.button, "BOTTOMLEFT", bodyLeft, healthBottom)
      slot.healthBg:SetPoint("BOTTOMRIGHT", slot.button, "BOTTOMRIGHT", -4, healthBottom)
      slot.healthBg:SetHeight(healthHeight)

      slot.powerBg:ClearAllPoints()
      slot.powerBg:SetPoint("BOTTOMLEFT", slot.button, "BOTTOMLEFT", bodyLeft, powerBottom)
      slot.powerBg:SetPoint("BOTTOMRIGHT", slot.button, "BOTTOMRIGHT", -4, powerBottom)
      slot.powerBg:SetHeight(powerHeight)

      slot.healthBar:ClearAllPoints()
      slot.healthBar:SetPoint("BOTTOMLEFT", slot.button, "BOTTOMLEFT", bodyLeft, healthBottom)
      slot.healthBar:SetPoint("BOTTOMRIGHT", slot.button, "BOTTOMRIGHT", -4, healthBottom)
      slot.healthBar:SetHeight(healthHeight)

      slot.powerBar:ClearAllPoints()
      slot.powerBar:SetPoint("BOTTOMLEFT", slot.button, "BOTTOMLEFT", bodyLeft, powerBottom)
      slot.powerBar:SetPoint("BOTTOMRIGHT", slot.button, "BOTTOMRIGHT", -4, powerBottom)
      slot.powerBar:SetHeight(powerHeight)

      if combatant then
        local painted = pcall(function()
          local r, g, b = ClassColors.HexToRgb(combatant.classColor)
          slot.portrait:SetColorTexture(r, g, b, 1)
          slot.nameText:SetText(combatant.name)
          slot.dismiss.combatantName = combatant.name
          slot.button.combatantName = combatant.name

          local levelText = "?"
          local publicLevel = nil

          if TypeGuards then
            publicLevel = TypeGuards.AsPublicNumber(combatant.level)
          end

          if publicLevel then
            levelText = tostring(publicLevel)
          end

          slot.levelText:SetText(levelText)

          local pr, pg, pb = PowerRgb(combatant.powerType)
          slot.healthBar:SetStatusBarColor(HEALTH_GREEN_R, HEALTH_GREEN_G, HEALTH_GREEN_B, 1)
          slot.powerBar:SetStatusBarColor(pr, pg, pb, 1)

          local liveUnit = FindLiveUnit(combatant.name, combatant.unit)
          local liveHealth = false
          local livePower = false

          if liveUnit then
            if UnitHealth then
              if UnitHealthMax then
                liveHealth = ApplyLiveResource(
                  slot.healthBar,
                  liveUnit,
                  UnitHealth,
                  UnitHealthMax
                )
              end
            end

            local powerIndex = nil

            if UnitPowerType then
              local powerOk, typeIndex = pcall(UnitPowerType, liveUnit)

              if powerOk then
                powerIndex = typeIndex
              end
            end

            if UnitPower then
              if UnitPowerMax then
                livePower = ApplyLiveResource(
                  slot.powerBar,
                  liveUnit,
                  UnitPower,
                  UnitPowerMax,
                  powerIndex
                )
              end
            end
          end

          if not liveHealth then
            slot.healthBar:SetMinMaxValues(0, 100)
            slot.healthBar:SetValue(ClassColors.ClampPercent(combatant.healthPercent))
          end

          if not livePower then
            slot.powerBar:SetMinMaxValues(0, 100)
            slot.powerBar:SetValue(ClassColors.ClampPercent(combatant.powerPercent))
          end
        end)

        if not painted then
          slot.healthBar:SetValue(100)
          slot.powerBar:SetValue(100)
          slot.levelText:SetText("?")
        end

        slot.dismiss:EnableMouse(true)
        slot.dismiss:Show()

        pcall(function()
          slot.button:EnableMouse(true)
          slot.button:Show()
        end)

        if not lockdown then
          local macro = RaidFrames.BuildTargetMacro(combatant.name)

          if macro then
            slot.button:SetAttribute("type", "macro")
            slot.button:SetAttribute("macrotext", macro)
          end
        end
      else
        slot.nameText:SetText("")
        slot.levelText:SetText("")
        slot.dismiss.combatantName = nil
        slot.button.combatantName = nil
        slot.dismiss:EnableMouse(false)
        slot.dismiss:Hide()

        if not lockdown then
          slot.button:SetAttribute("macrotext", "")
          slot.button:EnableMouse(false)
          slot.button:Hide()
        end
      end

      index = index + 1
    end

    if not lockdown then
      local columns = 1

      if count > 0 then
        columns = math.ceil(count / columnSize)
      end

      stack:SetSize(
        math.max(width, columns * stride) + DISMISS_PX + DISMISS_GAP_PX,
        24 + PvpLayout.GridHeightPx(count)
      )

      if handle then
        handle:ClearAllPoints()
        handle:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, 0)

        if pauseButton then
          pauseButton:ClearAllPoints()
          pauseButton:SetPoint("TOPRIGHT", stack, "TOPRIGHT", 0, 0)
          handle:SetPoint("TOPRIGHT", pauseButton, "TOPLEFT", -2, 0)
        else
          handle:SetPoint("TOPRIGHT", stack, "TOPRIGHT", 0, 0)
        end
      end

      if board.SyncHeader then
        board.SyncHeader()
      end

      local paused = false

      if getPaused then
        paused = getPaused() == true
      end

      if count > 0 then
        stack:Show()
      else
        if paused then
          stack:Show()
        else
          stack:Hide()
        end
      end
    end
  end

  return board
end

local enemyBoard = CreateBoard({
  stackName = "OlympusPVPRaidStack",
  handleName = "OlympusPVPRaidHandle",
  buttonPrefix = "OlympusPVPSecureTarget",
  dismissPrefix = "OlympusPVPDismiss",
  title = "ENEMY (drag)",
  titlePaused = "ENEMY paused",
  kind = "enemy",
  offsetX = 24,
  offsetY = -180,
})

local friendlyBoard = CreateBoard({
  stackName = "OlympusPVPFriendlyStack",
  handleName = "OlympusPVPFriendlyHandle",
  buttonPrefix = "OlympusPVPFriendlyTarget",
  dismissPrefix = "OlympusPVPFriendlyDismiss",
  title = "FRIENDLY (drag)",
  titlePaused = "FRIENDLY paused",
  kind = "friendly",
  offsetX = 24,
  offsetY = -430,
})

---@param callback fun(name: string)
function RaidFrames.SetOnDismiss(callback)
  enemyBoard.SetOnDismiss(callback)
end

---@param callback fun(name: string)
function RaidFrames.SetOnFriendlyDismiss(callback)
  friendlyBoard.SetOnDismiss(callback)
end

---@param callback fun(name: string)
function RaidFrames.SetOnClickTarget(callback)
  enemyBoard.SetOnClickTarget(callback)
  friendlyBoard.SetOnClickTarget(callback)
end

---@param enemyControl table
---@param friendlyControl table
function RaidFrames.SetPauseControl(enemyControl, friendlyControl)
  enemyBoard.SetPauseControl(enemyControl)
  friendlyBoard.SetPauseControl(friendlyControl)
end

---@return OlympusPVPCombatant[]
function RaidFrames.GetLastCombatants()
  return enemyBoard.GetLastCombatants()
end

---@param combatants OlympusPVPCombatant[]
function RaidFrames.Refresh(combatants)
  enemyBoard.Refresh(combatants)
end

---@param combatants OlympusPVPCombatant[]
function RaidFrames.RefreshFriendly(combatants)
  friendlyBoard.Refresh(combatants)
end

RaidFrames.MAX_FRAMES = MAX_FRAMES
