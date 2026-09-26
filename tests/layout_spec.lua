describe("OlympusPVP layout and pointer", function()
  before_each(function()
    OlympusPVP = nil
    dofile("Types.lua")
    dofile("ClassColors.lua")
    dofile("PvpLayout.lua")
    dofile("GankPointer.lua")
  end)

  it("stacks five frames and shrinks ten pixels per ten people", function()
    local PvpLayout = OlympusPVP.PvpLayout

    assert.are.equal(5, PvpLayout.COLUMN_SIZE)
    assert.are.equal(48, PvpLayout.FrameSizePx(10))
    assert.are.equal(38, PvpLayout.FrameSizePx(11))
    assert.are.equal(18, PvpLayout.FrameSizePx(31))
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
    assert.are.equal(0, ClassColors.ClampPercent(-4))
  end)
end)
