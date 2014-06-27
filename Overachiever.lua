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
      paths = {},
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
    "Overachiever.Paths",
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
local Paths
local Tracker
local Trackable
local Util
function Overachiever:LoadDependencies()
  Achievements = Apollo.GetPackage("Overachiever.Achievements").tPackage
  Paths        = Apollo.GetPackage("Overachiever.Paths").tPackage
  Trackable    = Apollo.GetPackage("Overachiever.Trackable").tPackage
  Tracker      = Apollo.GetPackage("Overachiever.Tracker").tPackage
  Util         = Apollo.GetPackage("Overachiever.Util").tPackage
end

-- Initialization --

function Overachiever:InitializeRuntimeState()
  self.achievements = Achievements:new(self.config.achievements)
  self.paths        = Paths:new(self.config.paths)
  self.tracker      = Tracker:new(self.config.tracker)

  self.recentlyCreatedUnits = {}

  self.trackablesInRange = Util.CountedReferenceMap:new()
end

function Overachiever:RegisterEventHandlers()
  Apollo.RegisterEventHandler("SubZoneChanged", "OnSubZoneChanged", self)
  Apollo.RegisterEventHandler("UnitCreated",    "OnUnitCreated",    self)
  Apollo.RegisterEventHandler("UnitDestroyed",  "OnUnitDestroyed",  self)

  self.tickTimer = ApolloTimer.Create(1/10, true, "OnTick", self)
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

function Overachiever:OnTick()
  if not self.player then
    local player = GameLib.GetPlayerUnit()
    if not player:IsValid() then return end
    self.player = player
    self.tracker.player = player
    self:OnGameReady()
  end

  -- TODO(nevir): Some unit state is not available during OnUnitCreated; but it
  -- appears to always be ready by next tick (so probably not relying on network
  -- I/O). Order of execution fail?
  for i, unit in ipairs(self.recentlyCreatedUnits) do
    self:DeferredOnUnitCreated(unit)
  end
  self.recentlyCreatedUnits = {}

  -- TODO(nevir): WOW WHAT A HACK.
  for id, trackable in pairs(self.tracker.trackablesById) do
    if not self:GetTrackableForUnit(GameLib.GetUnitById(id)) then
      self.tracker:Forget(trackable)
      self.trackablesInRange:Remove(id)
    end
  end

  self.tracker:Render()
end

function Overachiever:OnGameReady()
  -- TODO(nevir): Maddeningly, *some* achievements are ready at OnLoad time, but not all!
  self.achievements:IndexAll()
  -- TODO(nevir): Similarly, many units are not fully loaded while the player is zoning in.
  self:RefreshAllUnitsInRange()
end

function Overachiever:OnUnitCreated(unit)
  table.insert(self.recentlyCreatedUnits, unit)
end

function Overachiever:DeferredOnUnitCreated(unit)
  if not unit:IsValid() then return end
  local unitId   = unit:GetId()
  local existing = self.trackablesInRange[unitId]
  if existing then return end

  local trackable = self:GetTrackableForUnit(unit)
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

-- Trackables --

function Overachiever:GetTrackableForUnit(unit)
  if not unit then return end
  if unit:IsDead() then return end
  if unit:GetType() == UNIT_TYPE_PLAYER then return end

  local achievements = self.achievements:GetForUnit(unit)
  local missions = self.paths:GetMissionsForUnit(unit)
  local reasons = self.achievements:GetExtraReasonsForUnit(unit)
  if table.getn(achievements) == 0 and table.getn(missions) == 0 and table.getn(reasons) == 0 then return end

  return Trackable:new(self.config.tracker, unit, achievements, missions, reasons)
end

function Overachiever:RefreshAllUnitsInRange()
  -- Sometimes, we get UnitCreated/UnitDestroyed events before units have all their
  -- details available (typically, when logging in the first time).
  --
  -- So we re-scan to make sure that the units we know about are actually correct.
  for unitId, trackable in pairs(self.trackablesInRange) do
    if trackable == true and unitId ~= "count" then
      local trackable = self:GetTrackableForUnit(GameLib.GetUnitById(unitId))
      if trackable then
        self.trackablesInRange:Add(unitId, trackable)
        self.tracker:Track(trackable)
      end
    end
  end
end

-- Entry Point --

oa = Overachiever:Init()
