local _, ns = ...

-- Internal publish/subscribe. A handler that raises never stops the others: the error is kept for diagnostics
-- (EventBus:Errors) and the next handler runs. Events used so far:
--   addon.ready    ()   the addon finished starting on a rogue (every starter has run)
--   layout.unlock  ()   /ras unlock: movable frames become draggable
--   layout.lock    ()   /ras lock: movable frames are locked in place
local EventBus = {}
EventBus.__index = EventBus

-- Only the most recent errors are kept.
EventBus.MAX_ERRORS = 50

function EventBus.New()
  return setmetatable({ handlers = {}, errors = {} }, EventBus)
end

-- Returns the handler, which is also the token for Unsubscribe.
function EventBus:Subscribe(event, handler)
  if type(handler) ~= "function" then
    error("EventBus:Subscribe expects a function", 2)
  end
  local list = self.handlers[event]
  if not list then
    list = {}
    self.handlers[event] = list
  end
  list[#list + 1] = handler
  return handler
end

-- Returns true when the handler was subscribed.
function EventBus:Unsubscribe(event, handler)
  local list = self.handlers[event]
  if not list then
    return false
  end
  for index, candidate in ipairs(list) do
    if candidate == handler then
      table.remove(list, index)
      return true
    end
  end
  return false
end

-- Calls every handler of the event; returns how many ran without error.
function EventBus:Publish(event, ...)
  local list = self.handlers[event]
  if not list then
    return 0
  end
  -- Iterate a copy: a handler may subscribe or unsubscribe while it runs.
  local snapshot = { unpack(list) }
  local delivered = 0
  for _, handler in ipairs(snapshot) do
    local ok, err = pcall(handler, ...)
    if ok then
      delivered = delivered + 1
    else
      local errors = self.errors
      errors[#errors + 1] = { event = event, error = tostring(err) }
      if #errors > EventBus.MAX_ERRORS then
        table.remove(errors, 1)
      end
    end
  end
  return delivered
end

function EventBus:Errors()
  return self.errors
end

function EventBus:ClearErrors()
  self.errors = {}
end

ns.EventBus = EventBus
