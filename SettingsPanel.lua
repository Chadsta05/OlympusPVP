--[[
  OlympusPVP.SettingsPanel

  Gank-list controller plus a small in-game panel.
]]

---@type OlympusPVPNamespace
OlympusPVP = OlympusPVP or {}
OlympusPVP.SettingsPanel = OlympusPVP.SettingsPanel or {}

---@type table
local SettingsPanel = OlympusPVP.SettingsPanel

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
function SettingsPanel.Create(dependencies)
  local visible = false
  ---@type any?
  local frame
  ---@type any?
  local enabledCheck
  ---@type any?
  local pvpCheck
  ---@type any?
  local friendlyCheck
  ---@type any?
  local selfCheck
  ---@type any?
  local nameInput
  ---@type table
  local nameRows = {}
  local panel = {}

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

  local function RefreshList()
    if not frame then
      return
    end

    local settings = dependencies.getSettings()

    if enabledCheck then
      enabledCheck:SetChecked(settings.enabled)
    end

    if pvpCheck then
      pvpCheck:SetChecked(settings.pvpModeEnabled)
    end

    if friendlyCheck then
      friendlyCheck:SetChecked(settings.friendlyModeEnabled)
    end

    if selfCheck then
      selfCheck:SetChecked(settings.includeSelfOnFriendly)
    end

    local index = 1

    while index <= 12 do
      local row = nameRows[index]
      local gankName = settings.gankNames[index]

      if row then
        if gankName then
          row.label:SetText(gankName)
          row.button:Show()
          row.label:Show()
        else
          row.label:SetText("")
          row.button:Hide()
          row.label:Hide()
        end
      end

      index = index + 1
    end
  end

  local function EnsureFrame()
    if frame then
      return
    end

    if not CreateFrame then
      return
    end

    frame = CreateFrame("Frame", "OlympusPVPSettingsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(320, 502)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    if frame.SetBackdrop then
      frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 2,
      })
      frame:SetBackdropColor(0.05, 0.04, 0.03, 0.96)
      frame:SetBackdropBorderColor(0.54, 0.42, 0.18, 1)
    end

    ---@type any
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    title:SetText("Olympus PVP")

    ---@type any
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
      panel.Close()
    end)

    enabledCheck = CreateFrame("CheckButton", "OlympusPVPEnabledCheck", frame, "UICheckButtonTemplate")
    enabledCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44)
    ---@type any?
    local enabledLabel = _G["OlympusPVPEnabledCheckText"]
    if enabledLabel then
      enabledLabel:SetText("Enable scanner")
    end
    enabledCheck:SetScript("OnClick", function(self)
      local checked = self:GetChecked()
      dependencies.updateSettings({
        enabled = checked == true or checked == 1,
      })
    end)

    pvpCheck = CreateFrame("CheckButton", "OlympusPVPModeCheck", frame, "UICheckButtonTemplate")
    pvpCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -76)
    ---@type any?
    local pvpLabel = _G["OlympusPVPModeCheckText"]
    if pvpLabel then
      pvpLabel:SetText("Enemy frames (in range)")
    end
    pvpCheck:SetScript("OnClick", function(self)
      local checked = self:GetChecked()
      dependencies.updateSettings({
        pvpModeEnabled = checked == true or checked == 1,
      })
    end)

    friendlyCheck = CreateFrame("CheckButton", "OlympusPVPFriendlyCheck", frame, "UICheckButtonTemplate")
    friendlyCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -108)
    ---@type any?
    local friendlyLabel = _G["OlympusPVPFriendlyCheckText"]
    if friendlyLabel then
      friendlyLabel:SetText("Friendly raid frames")
    end
    friendlyCheck:SetScript("OnClick", function(self)
      local checked = self:GetChecked()
      dependencies.updateSettings({
        friendlyModeEnabled = checked == true or checked == 1,
      })
    end)

    selfCheck = CreateFrame("CheckButton", "OlympusPVPSelfFriendlyCheck", frame, "UICheckButtonTemplate")
    selfCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -140)
    ---@type any?
    local selfLabel = _G["OlympusPVPSelfFriendlyCheckText"]
    if selfLabel then
      selfLabel:SetText("Show yourself (heals)")
    end
    selfCheck:SetScript("OnClick", function(self)
      local checked = self:GetChecked()
      dependencies.updateSettings({
        includeSelfOnFriendly = checked == true or checked == 1,
      })
    end)

    ---@type any
    local gankTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gankTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -178)
    gankTitle:SetText("Gank list")

    nameInput = CreateFrame("EditBox", "OlympusPVPGankInput", frame, "InputBoxTemplate")
    nameInput:SetSize(200, 22)
    nameInput:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -200)
    nameInput:SetAutoFocus(false)

    ---@type any
    local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addButton:SetSize(72, 22)
    addButton:SetPoint("LEFT", nameInput, "RIGHT", 8, 0)
    addButton:SetText("Add")
    addButton:SetScript("OnClick", function()
      panel.AddGank(nameInput:GetText() or "")
      nameInput:SetText("")
      RefreshList()
    end)

    nameInput:SetScript("OnEnterPressed", function(self)
      panel.AddGank(self:GetText() or "")
      self:SetText("")
      self:ClearFocus()
      RefreshList()
    end)

    local rowIndex = 1

    while rowIndex <= 12 do
      ---@type any
      local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      label:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -232 - ((rowIndex - 1) * 18))
      label:SetWidth(230)
      label:SetJustifyH("LEFT")

      ---@type any
      local remove = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
      remove:SetSize(22, 16)
      remove:SetPoint("LEFT", label, "RIGHT", 6, 0)
      remove:SetText("X")

      local captured = rowIndex
      remove:SetScript("OnClick", function()
        local settings = dependencies.getSettings()
        local gankName = settings.gankNames[captured]

        if gankName then
          panel.RemoveGank(gankName)
          RefreshList()
        end
      end)

      nameRows[rowIndex] = {
        label = label,
        button = remove,
      }
      rowIndex = rowIndex + 1
    end
  end

  function panel.Open()
    visible = true
    EnsureFrame()

    if frame then
      RefreshList()
      frame:Show()
    end
  end

  function panel.Close()
    visible = false

    if frame then
      frame:Hide()
    end
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

  function panel.Refresh()
    RefreshList()
  end

  ---@param names string[]
  function panel.PromptDeathGankers(names)
    if not names then
      return
    end

    if #names == 0 then
      return
    end

    if not CreateFrame then
      panel.lastDeathPrompt = names
      return
    end

    ---@type any
    local prompt
    local created = pcall(function()
      prompt = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    end)

    if not created then
      prompt = CreateFrame("Frame", nil, UIParent)
    end
    prompt:SetSize(380, 90 + (#names * 28))
    prompt:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    prompt:SetFrameStrata("FULLSCREEN_DIALOG")
    if prompt.SetToplevel then
      prompt:SetToplevel(true)
    end
    prompt:EnableMouse(true)
    prompt:SetMovable(true)
    prompt:RegisterForDrag("LeftButton")
    prompt:SetScript("OnDragStart", prompt.StartMoving)
    prompt:SetScript("OnDragStop", prompt.StopMovingOrSizing)

    if prompt.SetBackdrop then
      prompt:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 2,
      })
      prompt:SetBackdropColor(0.05, 0.04, 0.03, 0.97)
      prompt:SetBackdropBorderColor(0.7, 0.18, 0.14, 1)
    end

    ---@type any
    local title = prompt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", prompt, "TOPLEFT", 16, -12)
    title:SetText("Mark gankers?")

    ---@type any
    local subtitle = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", prompt, "TOPLEFT", 16, -32)
    subtitle:SetWidth(348)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("These names hit you before you died. Yes adds them to the gank list.")

    local rowIndex = 1

    while rowIndex <= #names do
      local gankName = names[rowIndex]
      local y = -52 - ((rowIndex - 1) * 28)

      ---@type any
      local label = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      label:SetPoint("TOPLEFT", prompt, "TOPLEFT", 16, y)
      label:SetWidth(220)
      label:SetJustifyH("LEFT")
      label:SetText(gankName)

      ---@type any
      local yes = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
      yes:SetSize(64, 22)
      yes:SetPoint("LEFT", label, "RIGHT", 8, 0)
      yes:SetText("Ganker")
      yes:SetScript("OnClick", function()
        panel.AddGank(gankName)

        if panel.Refresh then
          panel.Refresh()
        end

        yes:Disable()
        yes:SetText("Added")
      end)

      ---@type any
      local no = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
      no:SetSize(48, 22)
      no:SetPoint("LEFT", yes, "RIGHT", 6, 0)
      no:SetText("No")
      no:SetScript("OnClick", function()
        yes:Disable()
        no:Disable()
        label:SetText(gankName .. " (skipped)")
      end)

      rowIndex = rowIndex + 1
    end

    ---@type any
    local close = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
    close:SetSize(72, 22)
    close:SetPoint("BOTTOM", prompt, "BOTTOM", 0, 10)
    close:SetText("Close")
    close:SetScript("OnClick", function()
      prompt:Hide()
    end)

    prompt:Show()
  end

  return panel
end
