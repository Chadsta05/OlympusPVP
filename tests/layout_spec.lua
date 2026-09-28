describe("OlympusPVP layout and pointer", function()
  before_each(function()
    OlympusPVP = nil
    dofile("Types.lua")
    dofile("ClassColors.lua")
    dofile("PvpLayout.lua")
    dofile("GankPointer.lua")
  end)

  it("uses five-row columns until fifteen, then ten-row columns", function()
    local PvpLayout = OlympusPVP.PvpLayout

    assert.are.equal(5, PvpLayout.ColumnSize(14))
    assert.are.equal(10, PvpLayout.ColumnSize(15))
    assert.are.equal(10, PvpLayout.ColumnSize(40))
    assert.are.equal(48, PvpLayout.FrameSizePx(14))
    assert.are.equal(36, PvpLayout.FrameSizePx(15))
    assert.are.equal(24, PvpLayout.FrameSizePx(25))
    assert.are.equal(22, PvpLayout.FrameSizePx(35))
    assert.are.equal(252, PvpLayout.GridHeightPx(1))
  end)

  it("points north as zero degrees", function()
    local GankPointer = OlympusPVP.GankPointer

    assert.is_true(math.abs(GankPointer.BearingDegrees(50, 50, 50, 40)) < 0.001)
    assert.is_true(math.abs(GankPointer.BearingDegrees(50, 50, 60, 50) - 90) < 0.001)
    assert.are.equal(0, GankPointer.NeedleRotationDegrees(90, 90))
    assert.are.equal("42.5, 61.3", GankPointer.FormatMapCoords(42.5, 61.25))
  end)

  it("maps class colors and power types", function()
    local ClassColors = OlympusPVP.ClassColors

    assert.are.equal("#FFF569", ClassColors.ColorForClass("Rogue"))
    assert.are.equal("energy", ClassColors.PowerTypeForClass("Rogue"))
    assert.are.equal("rage", ClassColors.PowerTypeForClass("Warrior"))
    assert.is_true(ClassColors.IsPlayerClass("DRUID"))
    assert.is_true(ClassColors.IsPlayerClass("Rogue"))
    assert.is_true(ClassColors.IsPlayerClass("DEATHKNIGHT"))
    assert.is_true(ClassColors.IsPlayerClass("Death Knight"))
    assert.is_true(ClassColors.IsPlayerClass("DEMONHUNTER"))
    assert.is_true(ClassColors.IsPlayerClass("MONK"))
    assert.is_true(ClassColors.IsPlayerClass("EVOKER"))
    assert.are.equal("#C41F3B", ClassColors.ColorForClass("DEATHKNIGHT"))
    assert.are.equal("#FF7D0A", ClassColors.ColorForClass("Druid"))
    assert.are.equal("runic_power", ClassColors.PowerTypeForClass("Death Knight"))
    assert.are.equal(0, ClassColors.ClampPercent(-4))
    local r, g, b = ClassColors.HexToRgb("#FFF569")
    assert.is_true(math.abs(r - 1) < 0.01)
  end)
end)
