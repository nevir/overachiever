require "Achievement"
require "AchievementsLib"
require "GameLib"
require "Window"

local UNIT_TYPE_PLAYER = "Player"

-- AddOn Setup/Dependencies --

local Overachiever = {} 
Overachiever.__index = Overachiever

function Overachiever:Init()
  instance = {
    -- Persisted configuration: defaults.
    config = {
      achievements = {},
      tracker = {
        showDistance = true,
        trackMasterEnabled = true,
        trackMasterLineId = 1,
      },
    },
  }
  setmetatable(instance, self)

  Apollo.RegisterAddon(instance, false, "", {
    "Overachiever.Achievements",
    "Overachiever.Trackable",
    "Overachiever.Tracker",
    "Overachiever.Util",
  })

  return instance
end

function Overachiever:OnLoad()
  self:LoadDependencies()
  self:InitializeRuntimeState()
  self:RegisterEventHandlers()

  self.tracker:Show(true)
end

local Achievements
local Tracker
local Trackable
local Util
function Overachiever:LoadDependencies()
  Achievements = Apollo.GetPackage("Overachiever.Achievements").tPackage
  Trackable    = Apollo.GetPackage("Overachiever.Trackable").tPackage
  Tracker      = Apollo.GetPackage("Overachiever.Tracker").tPackage
  Util         = Apollo.GetPackage("Overachiever.Util").tPackage
end

-- Initialization --

function Overachiever:InitializeRuntimeState()
  self.achievements = Achievements:new(self.config.achievements)
  self.tracker      = Tracker:new(self.config.tracker)

  self.trackablesInRange = Util.CountedReferenceMap:new()
end

function Overachiever:RegisterEventHandlers()
  Apollo.RegisterEventHandler("SubZoneChanged", "OnSubZoneChanged", self)
  Apollo.RegisterEventHandler("UnitCreated",    "OnUnitCreated",    self)
  Apollo.RegisterEventHandler("UnitDestroyed",  "OnUnitDestroyed",  self)

  self.tickTimer = ApolloTimer.Create(1/15, true, "OnTick", self)
end

-- Persistence --

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

function Overachiever:OnUnitCreated(unit)
  local unitId   = unit:GetId()
  local existing = self.trackablesInRange[unitId]
  if existing then return end

  local trackable = self:TrackableForUnit(unit)
  if not trackable then
    -- So that we do not query it again.
    self.trackablesInRange:Add(unitId, true)
  else
    self.trackablesInRange:Add(unitId, trackable)
    self.tracker:Track(trackable)
  end
end

function Overachiever:OnUnitDestroyed(unit)
  local unitId    = unit:GetId()
  local trackable = self.trackablesInRange[unitId]
  if not trackable then return end

  if trackable ~= true then
    self.tracker:Forget(trackable)
  end
  self.trackablesInRange:Remove(unitId)
end

function Overachiever:OnTick()
  -- TODO(nevir): WOW WHAT A HACK.
  for id, trackable in pairs(self.tracker.trackablesById) do
    -- TODO(nevir): Deal with non-units.
    if not self:TrackableForUnit(GameLib.GetUnitById(id)) then
      self.tracker:Forget(trackable)
      self.trackablesInRange:Remove(id)
    end
  end

  self.tracker:Render()
end

-- Trackables --

function Overachiever:TrackableForUnit(unit)
  if not unit then return end
  if unit:IsDead() then return end
  if unit:GetType() == UNIT_TYPE_PLAYER then return end

  local achievements = self.achievements:ForUnit(unit)
  local reasons = self.achievements:ExtraReasonsForUnit(unit)
  if table.getn(achievements) == 0 and table.getn(reasons) == 0 then return end

  return Trackable:new(self.config.tracker, unit, achievements, reasons)
end

-- Entry Point --

oa = Overachiever:Init()
