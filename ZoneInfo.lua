local ZoneInfo = {}
Apollo.RegisterPackage(ZoneInfo, "Overachiever.ZoneInfo", 1, {
  "Overachiever.Util"
})

local Util
function ZoneInfo:OnLoad()
  Util = Apollo.GetPackage("Overachiever.Util").tPackage
end

---------------------------------

function ZoneInfo:new(id)
  instance = {
    id = id,
    complete = {},
    incomplete = {},
    watchedUnitNames = Util.DefaultTable:new(function(key) return Util.Set:new() end),
  }
  setmetatable(instance, self)
  return instance
end
ZoneInfo.__index = ZoneInfo

function ZoneInfo:IndexAchievement(achievement)
  self:_IndexCompletionStatus(achievement)
  self:_IndexInterestingNames(achievement)
end

function ZoneInfo:_IndexCompletionStatus(achievement)
  local achievementId = achievement:GetId()
  if achievement:IsComplete() then
    self.complete[achievementId] = achievement
    self.incomplete[achievementId] = nil
  else
    self.complete[achievementId] = nil
    self.incomplete[achievementId] = achievement
  end
end

function ZoneInfo:_IndexInterestingNames(achievement)
  if not achievement:IsChecklist() then return end
  local achievementId = achievement:GetId()
  for i, item in pairs(achievement:GetChecklistItems()) do
    local name = item.strChecklistEntry
    local isInteresting = not item.bIsComplete
    if rawget(self.watchedUnitNames, name) or isInteresting then
      self.watchedUnitNames[name]:_Toggle(achievement, isInteresting)
      if self.watchedUnitNames[name].count == 0 then
        self.watchedUnitNames[name] = nil
      end
    end
  end
end

function ZoneInfo:IsWatchingUnit(unit)
  return rawget(self.watchedUnitNames, unit:GetName())
end
