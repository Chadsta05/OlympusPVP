describe("OlympusPVP Settings", function()
  local Settings

  before_each(function()
    OlympusPVP = nil
    dofile("Types.lua")
    dofile("Settings.lua")
    Settings = OlympusPVP.Settings
  end)

  it("defaults to PVP on with an empty gank list", function()
    local settings = Settings.CreateDefaultSettings()

    assert.is_true(settings.enabled)
    assert.is_true(settings.pvpModeEnabled)
    assert.same({}, settings.gankNames)
    assert.are.equal(10000, settings.alertCooldownMs)
  end)

  it("merges a saved gank list onto defaults", function()
    local merged = Settings.MergeSettings({
      gankNames = { "Stad Swipe" },
      enabled = false,
    })

    assert.is_false(merged.enabled)
    assert.is_true(merged.pvpModeEnabled)
    assert.same({ "Stad Swipe" }, merged.gankNames)
  end)

  it("keeps gank arrays independent", function()
    local first = Settings.CreateDefaultSettings()
    local second = Settings.CreateDefaultSettings()

    first.gankNames[#first.gankNames + 1] = "Stad Swipe"

    assert.same({}, second.gankNames)
  end)
end)
