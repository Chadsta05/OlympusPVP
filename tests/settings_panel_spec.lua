describe("OlympusPVP SettingsPanel", function()
  local Settings
  local SettingsPanel

  before_each(function()
    OlympusPVP = nil
    dofile("Types.lua")
    dofile("Settings.lua")
    dofile("SettingsPanel.lua")
    Settings = OlympusPVP.Settings
    SettingsPanel = OlympusPVP.SettingsPanel
  end)

  it("adds unique gank names and removes them", function()
    local store = Settings.CreateSettingsStore()
    local panel = SettingsPanel.Create({
      getSettings = store.GetSettings,
      updateSettings = store.UpdateSettings,
    })

    panel.AddGank("Stad Swipe")
    panel.AddGank("stad swipe")

    assert.same({ "Stad Swipe" }, store.GetSettings().gankNames)

    panel.RemoveGank("Stad Swipe")

    assert.same({}, store.GetSettings().gankNames)
  end)
end)
