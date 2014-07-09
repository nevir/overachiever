local Paths = {}
Paths.__index = Paths

Apollo.RegisterPackage(Paths, "Overachiever.Paths", 1, {
  "Gemini:Locale-1.0",
  "Overachiever.Util",
})

local L
local Util
function Paths:OnLoad()
  L    = Apollo.GetPackage("Gemini:Locale-1.0").tPackage:GetLocale("Overachiever")
  Util = Apollo.GetPackage("Overachiever.Util").tPackage
end

function Paths:new(config)
  instance = {
    config = config,
  }
  setmetatable(instance, self)

  return instance
end

-- Querying --

function Paths:GetMissionsForUnit(unit)
  local missions = {}
  for i, info in ipairs(unit:GetRewardInfo() or {}) do
    local mission = info.pmMission
    if mission and not mission:IsComplete() then
      table.insert(missions, mission)
    end
  end

  return missions
end
