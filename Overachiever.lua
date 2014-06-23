require "Achievement"
require "AchievementsLib"
require "GameLib"
require "Window"

-- Initialization --

local Overachiever = {} 

function Overachiever:new()
  instance = {
    config = {
      tracker = {
        showDistance = true,
        trackMasterEnabled = true,
        trackMasterLineId = 1,
      },
    }
  }
  setmetatable(instance, self)
  return instance
end
Overachiever.__index = Overachiever

function Overachiever:Init()
  Apollo.RegisterAddon(self, false, "", {
    "Overachiever.Tracker",
    "Overachiever.Util",
    "Overachiever.ZoneInfo",
  })
end

function Overachiever:OnLoad()
  self:LoadDependencies()
  self:InitializeState()

  self:IndexAchievements()
  self:IndexZoneNames()
  self:LoadCurrentGameState()
  self:RegisterEventHandlers()

  self.tracker:Show(true)
end

local Tracker
local Util
local ZoneInfo
local TrackMaster
function Overachiever:LoadDependencies()
  Tracker     = Apollo.GetPackage("Overachiever.Tracker").tPackage
  Util        = Apollo.GetPackage("Overachiever.Util").tPackage
  ZoneInfo    = Apollo.GetPackage("Overachiever.ZoneInfo").tPackage
end

function Overachiever:InitializeState()
  self.tracker = Tracker:new(self.config.tracker)
  self.zoneInfo = Util.DefaultTable:new(function(key) return ZoneInfo:new(key) end)
  self.zoneInfoByName = {} -- See GetCurrentZoneInfo.
end

-- Preloading --

function Overachiever:IndexAchievements()
  for i, achievement in pairs(AchievementsLib.GetAchievements(false)) do
    local zoneInfo = self.zoneInfo[achievement:GetWorldZoneId()]
    zoneInfo:IndexAchievement(achievement)
  end
end

function Overachiever:IndexZoneNames()
  for i, info in pairs(AchievementsLib.GetAchievementZones()) do
    if (rawget(self.zoneInfo, info.nId) ~= nil) then
      self.zoneInfo[info.nId].name = info.strName
      self.zoneInfoByName[info.strName] = self.zoneInfo[info.nId] -- See GetCurrentZoneInfo.
    end
  end
end

function Overachiever:LoadCurrentGameState()
  self:SetCurrentZoneInfo()
end

function Overachiever:RegisterEventHandlers()
  Apollo.RegisterEventHandler("SubZoneChanged", "OnSubZoneChanged", self)
  Apollo.RegisterEventHandler("UnitCreated",    "OnUnitCreated",    self)
  Apollo.RegisterEventHandler("UnitDestroyed",  "OnUnitDestroyed",  self)

  self.tickTimer = ApolloTimer.Create(1/15, true, "OnTick", self)
end

-- Persistence Handlers --

function Overachiever:OnSave(saveType)
  if saveType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
  return self.config
end

function Overachiever:OnRestore(saveType, data)
  for key, value in pairs(data and data.tracker or {}) do
    self.config.tracker[key] = value
  end
end

-- Event Handlers --

function Overachiever:OnSubZoneChanged(id, name)
  self:SetCurrentZoneInfo()
end

function Overachiever:OnUnitCreated(unit)
  if self:UnitIsInteresting(unit) then
    self.tracker:TrackUnit(unit)
  end
end

function Overachiever:OnUnitDestroyed(unit)
  if self:UnitIsInteresting(unit) then
    self.tracker:ForgetUnit(unit)
  end
end

function Overachiever:OnTick()
  -- TODO(nevir): WOW WHAT A HACK.
  for unitId, _ in pairs(self.tracker.itemsByUnitId) do
    local unit = GameLib.GetUnitById(unitId)
    if not self:UnitIsInteresting(unit) then
      self.tracker:ForgetUnit(unit)
    end
  end

  self.tracker:Render()
end

-- Utility --

function Overachiever:SetCurrentZoneInfo()
  -- TODO(nevir) ...seriously?
  local currentZoneMap = GameLib.GetCurrentZoneMap()
  if currentZoneMap == nil or currentZoneMap.strName == nil then
    self.currentZoneInfo = nil
  else
    self.currentZoneInfo = self.zoneInfoByName[currentZoneMap.strName]
  end
end

function Overachiever:UnitIsInteresting(unit)
  if not unit then return end
  if unit:GetActivationState().Datacube ~= nil then return true end

  if self.currentZoneInfo then
    return self.currentZoneInfo:IsWatchingUnit(unit)
  end

  return false
end

local OverachieverInst = Overachiever:new()
oa = OverachieverInst
OverachieverInst:Init()
