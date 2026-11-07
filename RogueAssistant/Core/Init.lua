local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
  if event ~= "ADDON_LOADED" or loadedAddon ~= ADDON_NAME then
    return
  end
  -- Saved variables and app startup are added here.
end)
