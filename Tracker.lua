local Tracker = {}
Tracker.__index = Tracker

Apollo.RegisterPackage(Tracker, "Overachiever.Tracker", 1, {
  "Overachiever.Util",
  "Overachiever.Trackable",
  "TrackMaster",
})

local Util
local Trackable
function Tracker:OnLoad()
  Util      = Apollo.GetPackage("Overachiever.Util").tPackage
  Trackable = Apollo.GetPackage("Overachiever.Trackable").tPackage
end

-- Tracker Proper --

function Tracker:new(config)
  instance = {
    config = config,
    doc = XmlDoc.CreateFromFile("Tracker.xml"),
    player = GameLib.GetPlayerUnit(),
    shown = true,
    trackablesById = {},
  }
  setmetatable(instance, self)

  instance.doc:RegisterCallback("OnDocLoaded", instance)

  return instance
end

function Tracker:OnDocLoaded()
  self.window = Apollo.LoadForm(self.doc, "Tracker", nil, self)
  self.scrollArea = self.window:FindChild("ScrollArea")

  for id, trackable in pairs(self.trackablesById) do
    self:AppendRow(trackable)
  end

  self:ConfigureTrackMaster()

  if self.shown then
    self:Render()
    self:Show(true)
  end
end

function Tracker:ConfigureTrackMaster()
  local TrackMaster = Apollo.GetAddon("TrackMaster")
  if not TrackMaster then return end

  TrackMaster:AddToConfigMenu(TrackMaster.Type.Track, "Overachiever", {
    LineNo = self.config.trackMasterLineId,
    IsChecked = self.config.trackMasterEnabled,
    CanEnable = true,
    CanFire = false,
    OnEnableChanged = function(enabled)
      self:RenderTrackedItem(nil)
      self.config.trackMasterEnabled = enabled
    end,
    OnLineChanged = function(lineId)
      self.config.trackMasterLineId = lineId
    end,
  })
end

-- State --

function Tracker:Track(trackable)
  self.trackablesById[trackable.id] = trackable
  self:AppendRow(trackable, true)
  if trackable.id == self.pinnedId then
    trackable:SetFocused(true)
  end

  self:Render()
end

function Tracker:Forget(trackable)
  self.trackablesById[trackable.id] = nil
  self:RemoveRow(trackable)
  self:Render()
end

function Tracker:OnUnitRowPressed(button)
  local trackable = button:GetParent():GetData()
  if self.pinnedId then
    local previous = self.trackablesById[self.pinnedId]
    if previous then
      previous:SetFocused(false)
    end
  end

  if self.pinnedId == trackable.id then
    self.pinnedId = nil
  else
    self.pinnedId = trackable.id
    trackable:SetFocused(true)
  end

  self:Render()
end

-- Rendering --

function Tracker:Show(show)
  self.shown = show
  if not self.window then return end
  self.window:Show(show, true)
end

function Tracker:AppendRow(trackable, animate)
  if not self.window then return end
  if trackable.row then return end
  trackable.row = Apollo.LoadForm(self.doc, "UnitRow", self.scrollArea, self)
  trackable.row:SetData(trackable)
  if animate then
    trackable.row:SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
  end
end

function Tracker:RemoveRow(trackable)
  if not trackable.row then return end
  trackable.row:Destroy()
end

function Tracker:Render()
  if not self.window then return end
  self:UpdateDistances()
  local focused = self:GetFocusedTrackable()
  local focusedId = focused and focused.id
  self:RenderTrackedItem(focused)

  self.scrollArea:ArrangeChildrenVert(0, function(row1, row2)
    local trackable1 = row1:GetData()
    local trackable2 = row2:GetData()

    if trackable1.id == focusedId then
      return true
    elseif trackable2.id == focusedId then
      return false
    elseif trackable1 and trackable1.distance and trackable2 and trackable2.distance then
      return trackable1.distance < trackable2.distance
    elseif trackable1 and trackable1.distance then
      return true
    else
      return false
    end
  end)

end

-- Tracked Unit Rendering --

function Tracker:RenderTrackedItem(trackable)
  if not self.config.trackMasterEnabled then return end
  local TrackMaster = Apollo.GetAddon("TrackMaster")
  if not TrackMaster then return end
  -- TODO(nevir): Deal with non-units.
  local unit = trackable and trackable.unit
  TrackMaster:SetTarget(unit, -1, self.config.trackMasterLineId)
end

-- Utility --

function Tracker:UpdateDistances()
  if not self.player then return end
  local playerPosition = self.player:GetPosition()
  for id, trackable in pairs(self.trackablesById) do
    trackable:UpdateDistance(playerPosition)
  end
end

function Tracker:GetFocusedTrackable()
  if self.trackablesById[self.pinnedId] then
    return self.trackablesById[self.pinnedId]
  end

  local trackedId = nil
  local minDistance = math.huge
  for id, trackable in pairs(self.trackablesById) do
    if trackable.distance and trackable.distance < minDistance then
      trackedId = id
      minDistance = trackable.distance
    end
  end

  return self.trackablesById[trackedId]
end
