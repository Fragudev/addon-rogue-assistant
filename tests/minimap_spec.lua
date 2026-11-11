describe("Minimap button", function()
  local ns, state

  local function button()
    return _G.RogueAssistantMinimapButton
  end

  local function menu()
    return _G.RogueAssistantMinimapMenu
  end

  local function entries()
    local labels = {}
    for _, item in ipairs(menu().items) do
      if item:IsShown() then
        labels[#labels + 1] = item.label:GetText()
      end
    end
    return labels
  end

  local function choose(label)
    for _, item in ipairs(menu().items) do
      if item:IsShown() and item.label:GetText() == label then
        WowStub.Click(item)
        return
      end
    end
    error("no menu entry " .. label)
  end

  local function lastMessage()
    local messages = WowStub.Messages()
    return messages[#messages]
  end

  before_each(function()
    WowStub.Reset()
    state = WowStub.state
    ns = WowStub.LoadAddon()
  end)

  it("sits on the minimap edge at the default angle and saves it", function()
    assert.is_true(button():IsShown())
    assert.same({ minimapAngle = 225, minimapHidden = false }, {
      minimapAngle = RogueAssistantDB.minimapAngle,
      minimapHidden = RogueAssistantDB.minimapHidden,
    })
    local point, relativeTo, relativePoint, x, y = button():GetPoint()
    assert.equal("CENTER", point)
    assert.equal(Minimap, relativeTo)
    assert.equal("CENTER", relativePoint)
    assert.is_true(math.abs(x + 80 * math.sqrt(0.5)) < 0.01)
    assert.is_true(math.abs(y + 80 * math.sqrt(0.5)) < 0.01)
  end)

  it("opens a menu with the basic options and closes it with a second click", function()
    assert.is_false(menu():IsShown())
    WowStub.Click(button())
    assert.is_true(menu():IsShown())
    assert.same({ "Unlock bar", "Reset position", "Hide minimap button" }, entries())
    WowStub.Click(button())
    assert.is_false(menu():IsShown())
  end)

  it("closes the menu with Escape", function()
    local found = false
    for _, name in ipairs(UISpecialFrames) do
      found = found or name == "RogueAssistantMinimapMenu"
    end
    assert.is_true(found)
  end)

  it("unlocks and locks the bar from the menu", function()
    WowStub.Click(button())
    choose("Unlock bar")
    assert.is_false(menu():IsShown())
    assert.is_true(ns.Bar.handle:IsShown())
    assert.truthy(lastMessage():find("Bar unlocked", 1, true))

    WowStub.Click(button())
    assert.same({ "Lock bar", "Reset position", "Hide minimap button" }, entries())
    choose("Lock bar")
    assert.is_false(ns.Bar.handle:IsShown())
    assert.truthy(lastMessage():find("Bar locked.", 1, true))
  end)

  it("resets the bar position from the menu", function()
    RogueAssistantDB.position = { point = "TOP", relativePoint = "TOP", x = 0, y = 0 }
    WowStub.Click(button())
    choose("Reset position")
    assert.is_nil(RogueAssistantDB.position)
    assert.truthy(lastMessage():find("default position", 1, true))
  end)

  it("refuses to unlock in combat and says why", function()
    state.inCombat = true
    WowStub.Click(button())
    choose("Unlock bar")
    assert.is_false(ns.Bar.handle:IsShown())
    assert.truthy(lastMessage():find("Not possible in combat", 1, true))
  end)

  it("hides itself from the menu and comes back with /ras minimap", function()
    WowStub.Click(button())
    choose("Hide minimap button")
    assert.is_false(button():IsShown())
    assert.is_true(RogueAssistantDB.minimapHidden)
    assert.truthy(lastMessage():find("/ras minimap", 1, true))

    SlashCmdList.RAS("minimap")
    assert.is_true(button():IsShown())
    assert.is_false(RogueAssistantDB.minimapHidden)
    assert.truthy(lastMessage():find("Minimap button shown.", 1, true))

    SlashCmdList.RAS("minimap")
    assert.is_false(button():IsShown())
  end)

  it("moves around the minimap edge while dragged", function()
    button().scripts.OnDragStart(button())
    assert.is_true(button().dragging)
    state.cursor = { 1000, 800 } -- straight above the minimap centre
    button().scripts.OnUpdate(button(), 0.1)
    button().scripts.OnDragStop(button())
    assert.is_falsy(button().dragging)
    assert.is_nil(button().scripts.OnUpdate)
    assert.is_true(math.abs(RogueAssistantDB.minimapAngle - 90) < 0.01)
    local _, _, _, x, y = button():GetPoint()
    assert.is_true(math.abs(x) < 0.01)
    assert.is_true(math.abs(y - 80) < 0.01)
  end)

  it("lists the minimap command in the help", function()
    SlashCmdList.RAS("help")
    local found = false
    for _, line in ipairs(WowStub.Messages()) do
      found = found or line:find("/ras minimap", 1, true) ~= nil
    end
    assert.is_true(found)
  end)
end)

describe("Minimap button saved as hidden", function()
  it("starts hidden", function()
    WowStub.Reset()
    _G.RogueAssistantDB = { version = 2, warnMinutes = 5, enchants = {}, minimapAngle = 10, minimapHidden = true }
    WowStub.LoadAddon()
    assert.is_false(_G.RogueAssistantMinimapButton:IsShown())
    assert.equal(10, RogueAssistantDB.minimapAngle)
  end)
end)
