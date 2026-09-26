describe("OlympusPVP RaidFrames", function()
  before_each(function()
    OlympusPVP = nil
    dofile("Types.lua")
    dofile("TypeGuards.lua")
    dofile("PvpLayout.lua")
    dofile("RaidFrames.lua")
  end)

  it("builds a targetexact macro", function()
    assert.are.equal(
      "/cleartarget\n/targetexact Donald Trump",
      OlympusPVP.RaidFrames.BuildTargetMacro("Donald Trump")
    )
  end)
end)
