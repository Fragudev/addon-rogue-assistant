local Loader = dofile("tests/support/loader.lua")

describe("Options", function()
  local ns, options, settings, model, redraws, applies, bus, banner

  local function build()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    local root = {}
    settings = ns.Settings.New(root)
    model = ns.TrackerModel.New(settings)
    redraws, applies, banner = 0, 0, 0
    bus = ns.EventBus.New()
    local vm = ns.ViewModelOptions.New({
      settings = settings,
      model = model,
      bus = bus,
      refreshAlerts = function()
        banner = banner + 1
      end,
      refreshTracker = function()
        redraws = redraws + 1
      end,
      refreshPoison = function()
        applies = applies + 1
      end,
    })
    options = ns.Options.New({ viewModel = vm })
    options:Create()
  end

  -- The widgets created under the content frame, by type and creation order.
  local function widgets(frameType, template)
    local found = {}
    for _, frame in ipairs(WowStub.state.frames) do
      if frame.frameType == frameType and (template == nil or frame.template == template) then
        found[#found + 1] = frame
      end
    end
    return found
  end

  local function show()
    options.panel.scripts.OnShow()
  end

  local function buttonLabelled(text)
    for _, frame in ipairs(widgets("Button", "UIPanelButtonTemplate")) do
      if frame.text == text then
        return frame
      end
    end
  end

  before_each(function()
    WowStub.Reset()
    build()
  end)

  describe("registration", function()
    it("registers a canvas in the Settings window and builds nothing until it is shown", function()
      assert.are.equal(options.panel, WowStub.state.categories[1].frame)
      assert.are.equal("Rogue Assistant", WowStub.state.categories[1].name)
      assert.is_true(WowStub.state.categories[1].registered)
      assert.is_nil(options.window)
      assert.are.equal(0, #widgets("Slider"))
      show()
      assert.are.equal(1 + 3 + 5, #widgets("Slider"))
    end)

    it("opens the registered category", function()
      assert.is_true(options:Open())
      assert.are.same({ 1 }, WowStub.state.opened)
    end)

    it("falls back to its own window without the Settings API", function()
      WowStub.Reset()
      WowStub.Remove("Settings.RegisterCanvasLayoutCategory")
      build()
      assert.is_not_nil(options.window)
      assert.are.equal(options.window, options.panel.parent)
      assert.is_true(options:Open())
      assert.is_true(options.window.shown)
      assert.is_true(options:Open())
      assert.is_false(options.window.shown)
    end)

    it("falls back to its own window when the category cannot be opened", function()
      WowStub.Fail("Settings.OpenToCategory")
      assert.is_true(options:Open())
      assert.is_true(options.window.shown)
    end)

    it("cannot open before it is created", function()
      assert.is_false(ns.Options.New({ viewModel = {} }):Open())
    end)

    it("registers a starter that creates the panel", function()
      WowStub.Reset()
      ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
      ns.store = ns.Store.Open({})
      ns.bus = ns.EventBus.New()
      ns.settings = ns.Settings.New(ns.store:Profile("Player-1").settings)
      ns.profile = ns.store:Profile("Player-1")
      ns.weaponState = ns.WeaponState.New({ data = {} })
      ns.Startup.Run()
      assert.is_not_nil(ns.options)
      -- The panel redraws and applies through whatever the addon runs by then.
      redraws, applies = 0, 0
      ns.trackerFrames = {
        Refresh = function()
          redraws = redraws + 1
        end,
      }
      ns.poisonButton = {
        ApplySettings = function()
          applies = applies + 1
        end,
      }
      ns.options.panel.scripts.OnShow()
      ns.options.vm:Set("poison.locked", false)
      ns.options.vm:SetLayout("buffs", "columns", 3)
      assert.are.same({ 1, 1 }, { redraws, applies })
    end)

    it("does nothing when the addon is disabled", function()
      WowStub.Reset()
      ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
      ns.disabled = "not_rogue"
      ns.Startup.Run()
      assert.is_nil(ns.options)
    end)
  end)

  describe("controls", function()
    before_each(show)

    it("toggles a check box through the settings", function()
      local check = widgets("CheckButton")[1]
      assert.is_true(check.checked)
      check:SetChecked(false)
      check.scripts.OnClick(check)
      assert.is_false(settings:Get("poison.locked"))
      assert.are.equal(1, applies)
    end)

    it("writes a slider value and says why a bad one is refused", function()
      local slider = widgets("Slider")[1]
      slider.scripts.OnValueChanged(slider, 2)
      assert.are.equal(2, settings:Get("poison.scale"))
      slider.scripts.OnValueChanged(slider, 50)
      assert.are.equal(2, settings:Get("poison.scale"))
      assert.are.equal(ns.L["options.error.invalid"], options.status.text)
    end)

    it("does not write while it is refreshing the sliders", function()
      options.refreshing = true
      widgets("Slider")[1].scripts.OnValueChanged(nil, 3)
      options.refreshing = false
      assert.are.equal(1, settings:Get("poison.scale"))
    end)

    it("writes the tracker layout of the selected group", function()
      local sliders = widgets("Slider")
      local iconSize = sliders[5]
      iconSize.scripts.OnValueChanged(iconSize, 48)
      assert.are.equal(48, model:Group("essentials").iconSize)
      local group = buttonLabelled("Group: Essentials (click to change)")
      group.scripts.OnClick()
      assert.is_not_nil(buttonLabelled("Group: Buffs (click to change)"))
      iconSize.scripts.OnValueChanged(iconSize, 50)
      assert.are.equal(50, model:Group("buffs").iconSize)
    end)

    it("cycles the choice buttons", function()
      buttonLabelled("Growth: right").scripts.OnClick()
      assert.are.equal("LEFT", model:Group("essentials").growth)
      assert.is_not_nil(buttonLabelled("Growth: left"))
      buttonLabelled("Display: icons").scripts.OnClick()
      assert.are.equal("bars", model:Group("essentials").mode)
      buttonLabelled("When an aura is missing: hide it").scripts.OnClick()
      assert.are.equal("dim", model:Group("essentials").showWhenMissing)
    end)

    it("toggles the status lines check box", function()
      local check = widgets("CheckButton")[2]
      assert.is_true(check.checked)
      check:SetChecked(false)
      check.scripts.OnClick(check)
      assert.is_false(settings:Get("poison.statusShown"))
      assert.are.equal(1, applies)
    end)

    it("cycles the flyout direction", function()
      buttonLabelled("Poison list opens: up").scripts.OnClick()
      assert.are.equal("DOWN", settings:Get("poison.flyoutDirection"))
      assert.is_not_nil(buttonLabelled("Poison list opens: down"))
      assert.are.equal(1, applies)
      for _, label in ipairs({ "down", "left", "right" }) do
        buttonLabelled("Poison list opens: " .. label).scripts.OnClick()
      end
      assert.are.equal("UP", settings:Get("poison.flyoutDirection"))
    end)

    it("unlocks and locks every element from a button, like the slash commands", function()
      local events = {}
      bus:Subscribe("layout.unlock", function()
        events[#events + 1] = "unlock"
        settings:Set("poison.locked", false)
      end)
      bus:Subscribe("layout.lock", function()
        events[#events + 1] = "lock"
        settings:Set("poison.locked", true)
      end)
      buttonLabelled("Unlock elements").scripts.OnClick()
      assert.are.equal(ns.L["layout.unlocked"], options.status.text)
      buttonLabelled("Lock elements").scripts.OnClick()
      assert.are.equal(ns.L["layout.locked"], options.status.text)
      assert.is_not_nil(buttonLabelled("Unlock elements"))
      assert.are.same({ "unlock", "lock" }, events)
    end)

    it("refuses to unlock in combat with the existing message", function()
      local published = 0
      bus:Subscribe("layout.unlock", function()
        published = published + 1
      end)
      WowStub.state.inCombat = true
      buttonLabelled("Unlock elements").scripts.OnClick()
      assert.are.equal(0, published)
      assert.are.equal(ns.L["layout.combat"], options.status.text)
    end)

    it("resets every position", function()
      local spot = { point = "TOP", relativePoint = "TOP", x = 1, y = 2 }
      settings:Set("poison.position", spot)
      settings:Set("poison.statusPosition", spot)
      settings:Set("alerts.position", spot)
      model:SetPosition("buffs", spot)
      buttonLabelled("Reset all positions").scripts.OnClick()
      assert.are.equal(200, settings:Get("poison.position").y)
      assert.are.equal(198, settings:Get("poison.statusPosition").y)
      assert.are.equal(-160, settings:Get("alerts.position").y)
      assert.are.equal(220, model:Group("buffs").position.y)
      assert.are.same({ 1, 1, 1 }, { redraws, applies, banner })
    end)

    it("resets the poison button position", function()
      settings:Set("poison.position", { point = "TOP", relativePoint = "TOP", x = 1, y = 2 })
      buttonLabelled("Reset position").scripts.OnClick()
      assert.are.equal("BOTTOM", settings:Get("poison.position").point)
    end)
  end)

  describe("entries", function()
    before_each(show)

    local function rowsShown()
      local count = 0
      for _, row in ipairs(options.entryRows) do
        if row.shown then
          count = count + 1
        end
      end
      return count
    end

    it("lists the entries of the group", function()
      assert.are.equal(#model:Group("essentials").entries, rowsShown())
      assert.is_false(options.empty.shown)
      assert.is_false(options.entryRows[1].up.shown)
      assert.is_true(options.entryRows[1].down.shown)
    end)

    it("adds a spell from the edit box and shows the result", function()
      options.addBox:SetText("12345")
      options.addBox.scripts.OnEnterPressed(options.addBox)
      assert.are.equal(12345, model:Group("essentials").entries[#model:Group("essentials").entries].spellId)
      assert.are.equal("", options.addBox:GetText())
      assert.is_truthy(options.status.text:find("12345", 1, true))
      buttonLabelled("Add").scripts.OnClick()
      assert.are.equal(ns.L["options.error.invalid"], options.status.text)
      options.addBox.scripts.OnEscapePressed(options.addBox)
    end)

    it("removes and moves entries", function()
      local first = model:Group("essentials").entries[1]
      local second = model:Group("essentials").entries[2]
      options.entryRows[1].down.scripts.OnClick()
      assert.are.equal(second, model:Group("essentials").entries[1])
      options.entryRows[2].up.scripts.OnClick()
      assert.are.equal(first, model:Group("essentials").entries[1])
      local count = #model:Group("essentials").entries
      options.entryRows[1].remove.scripts.OnClick()
      assert.are.equal(count - 1, #model:Group("essentials").entries)
      assert.are.equal(count - 1, rowsShown())
    end)

    it("shows the empty note when the group has no spells", function()
      for _ = 1, #model:Group("essentials").entries do
        options.entryRows[1].remove.scripts.OnClick()
      end
      assert.is_true(options.empty.shown)
      assert.are.equal(0, rowsShown())
    end)

    it("resets the group, and all groups only after a second click", function()
      model:SetLayout("essentials", "iconSize", 60)
      buttonLabelled("Reset this group").scripts.OnClick()
      assert.is_nil(model:Group("essentials").iconSize)
      model:SetLayout("target", "iconSize", 60)
      buttonLabelled("Reset all groups").scripts.OnClick()
      assert.are.equal(60, model:Group("target").iconSize)
      buttonLabelled("Click again to reset all groups").scripts.OnClick()
      assert.is_nil(model:Group("target").iconSize)
      assert.is_not_nil(buttonLabelled("Reset all groups"))
    end)

    it("falls back to the first group when the selected one disappears", function()
      options.groupId = "gone"
      options:Refresh()
      assert.are.equal("essentials", options.groupId)
      options:NextGroup()
      assert.are.equal("buffs", options.groupId)
    end)

    it("does not refresh before it is built", function()
      assert.is_nil(ns.Options.New({ viewModel = {} }):Refresh())
    end)
  end)
end)
