local Tracker = {}
Apollo.RegisterPackage(Tracker, "Overachiever.Tracker", 1, {
  "Overachiever.Util",
  "TrackMaster",
})

local Util
function Tracker:OnLoad()
  Util = Apollo.GetPackage("Overachiever.Util").tPackage
end

local ROW_TEXT_COLOR_FOCUSED = ApolloColor.new("ff66d9ef")
local ROW_TEXT_COLOR_NORMAL  = ApolloColor.new("ffffffff")

-- Tracked Items --

Tracker.Item = {}

function Tracker.Item:new(config, unit)
  instance = {
    config = config,
    unit = unit,
  }
  setmetatable(instance, self)

  return instance
end
Tracker.Item.__index = Tracker.Item

function Tracker.Item:UpdateDistance(relativePosition)
  distance = nil
  if relativePosition then
    local unitPosition = self.unit:GetPosition()
    distance = unitPosition and Util.DistanceTo(unitPosition, relativePosition)
  end

  if distance ~= self.distance then
    self.distance = distance
    self:Render()
  end
end

function Tracker.Item:SetFocused(focused)
  if self.focused == focused then return end
  self.focused = focused
  self:Render()
end

function Tracker.Item:Render()
  if not self.row then return end
  local label = self.row:FindChild("Label")

  local labelString = self.unit:GetName()
  if self.config.showDistance and self.distance then
    labelString = string.format("(%dm) %s", self.distance, labelString)
  end
  label:SetText(labelString)

  local color = self.focused and ROW_TEXT_COLOR_FOCUSED or ROW_TEXT_COLOR_NORMAL
  label:SetTextColor(color)
end

-- Tracker Proper --

function Tracker:new(config)
  instance = {
    config = config,
    doc = XmlDoc.CreateFromFile("Tracker.xml"),
    player = GameLib.GetPlayerUnit(),
    shown = true,
    itemsByUnitId = {},
  }
  setmetatable(instance, self)

  instance.doc:RegisterCallback("OnDocLoaded", instance)

  return instance
end
Tracker.__index = Tracker

function Tracker:OnDocLoaded()
  self.window = Apollo.LoadForm(self.doc, "Tracker", nil, self)
  self.scrollArea = self.window:FindChild("ScrollArea")

  for unitId, item in pairs(self.itemsByUnitId) do
    self:AppendRow(item)
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

function Tracker:TrackUnit(unit)
  local unitId = unit:GetId()
  if self.itemsByUnitId[unitId] then return end
  local item = Tracker.Item:new(self.config, unit)
  item.id = unitId
  self:AppendRow(item)
  self.itemsByUnitId[unitId] = item

  self:Render()
end

function Tracker:ForgetUnit(unit)
  local unitId = unit:GetId()
  local item = self.itemsByUnitId[unitId]
  if not item then return end
  self:RemoveRow(item)
  self.itemsByUnitId[unitId] = nil

  self:Render()
end

function Tracker:OnUnitRowPressed(button)
  local item = button:GetParent():GetData()
  if self.focusedUnitId then
    local previousItem = self.itemsByUnitId[self.focusedUnitId]
    if previousItem then
      previousItem:SetFocused(false)
    end
  end

  if self.focusedUnitId == item.id then
    self.focusedUnitId = nil
  else
    self.focusedUnitId = item.id
    item:SetFocused(true)
  end

  self:Render()
end

-- Rendering --

function Tracker:Show(show)
  self.shown = show
  if not self.window then return end
  self.window:Show(show, true)
end

function Tracker:AppendRow(item)
  if not self.window then return end
  item.row = Apollo.LoadForm(self.doc, "UnitRow", self.scrollArea, self)
  item.row:SetData(item)
end

function Tracker:RemoveRow(item)
  if not item.row then return end
  item.row:Destroy()
end

function Tracker:Render()
  if not self.window then return end
  self:UpdateItemDistances()
  local trackedItem = self:GetTrackedItem()
  local trackedItemId = trackedItem and trackedItem.id
  self:RenderTrackedItem(trackedItem)

  self.scrollArea:ArrangeChildrenVert(0, function(row1, row2)
    local item1 = row1:GetData()
    local item2 = row2:GetData()

    if item1.id == trackedItemId then
      return true
    elseif item2.id == trackedItemId then
      return false
    elseif item1 and item1.distance and item2 and item2.distance then
      return item1.distance < item2.distance
    elseif item1 and item1.distance then
      return true
    else
      return false
    end
  end)

end

-- Tracked Unit Rendering --

function Tracker:RenderTrackedItem(item)
  if not self.config.trackMasterEnabled then return end
  local TrackMaster = Apollo.GetAddon("TrackMaster")
  if not TrackMaster then return end
  local unit = item and item.unit
  TrackMaster:SetTarget(unit, -1, self.config.trackMasterLineId)
end

-- Utility --

function Tracker:UpdateItemDistances()
  local playerPosition = self.player:GetPosition()
  for unitId, item in pairs(self.itemsByUnitId) do
    item:UpdateDistance(playerPosition)
  end
end

function Tracker:GetTrackedItem()
  if self.itemsByUnitId[self.focusedUnitId] then
    return self.itemsByUnitId[self.focusedUnitId]
  end

  local trackedUnitId = nil
  local minDistance = math.huge
  for unitId, item in pairs(self.itemsByUnitId) do
    if item.distance and item.distance < minDistance then
      trackedUnitId = unitId
      minDistance = item.distance
    end
  end

  return self.itemsByUnitId[trackedUnitId]
end
