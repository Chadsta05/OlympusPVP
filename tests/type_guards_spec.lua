describe("OlympusPVP TypeGuards", function()
  local TypeGuards

  before_each(function()
    OlympusPVP = nil
    _G.issecretvalue = nil
    dofile("Types.lua")
    dofile("TypeGuards.lua")
    TypeGuards = OlympusPVP.TypeGuards
  end)

  it("classifies primitives and rejects secret strings", function()
    assert.is_true(TypeGuards.IsString("Asmon"))
    assert.is_true(TypeGuards.IsFiniteNumber(12))
    assert.are.equal("Donald Trump", TypeGuards.AsPublicString("Donald Trump"))

    _G.issecretvalue = function(value)
      return value == "SECRET"
    end

    assert.is_nil(TypeGuards.AsPublicString("SECRET"))
  end)
end)
