local Trackable = {}
Apollo.RegisterPackage(Trackable, "Overachiever.Trackable", 1, {
  "Overachiever.Util",
})

local Util
function Trackable:OnLoad()
  Util = Apollo.GetPackage("Overachiever.Util").tPackage
end

-- TODO(nevir): Palette constants.
local ROW_TEXT_COLOR_FOCUSED    = "ff4fc3f7" 
local ROW_TEXT_COLOR_NORMAL     = "ffffffff"
local TOOLTIP_ACHIEVEMENT_COLOR = "ff4fc3f7"
local TOOLTIP_PATH_COLOR        = "ffaed581"
local TOOLTIP_REASON_COLOR      = "fffff176"

function Trackable:new(config, unit, achievements, missions, reasons)
  instance = {
    id = unit:GetId(),
    config = config,
    unit = unit,
    achievements = achievements,
    missions = missions,
    reasons = reasons,
  }
  setmetatable(instance, self)

  return instance
end
Trackable.__index = Trackable

function Trackable:UpdateDistance(relativePosition)
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

function Trackable:SetFocused(focused)
  if self.focused == focused then return end
  self.focused = focused
  self:Render()
end

function Trackable:GetName()
  return self.unit:GetName() or ""
end

function Trackable:Render()
  if not self.row then return end
  self:RenderTooltip()

  local label = self.row:FindChild("Label")
  local labelString = self.unit:GetName()
  if self.config.showDistance and self.distance then
    labelString = string.format("(%dm) %s", self.distance, labelString)
  end
  label:SetText(labelString)

  local color = self.focused and ROW_TEXT_COLOR_FOCUSED or ROW_TEXT_COLOR_NORMAL
  label:SetTextColor(color)
end

function Trackable:RenderTooltip()
  if not self.row then return end
  local text = ""

  for i, achievement in ipairs(self.achievements) do
    text = text .. string.format("<P TextColor=\"%s\">%s</P>", TOOLTIP_ACHIEVEMENT_COLOR, achievement:GetName())
  end

  if text ~= "" and table.getn(self.missions) > 0 then
    -- TODO(nevir): Gotta be a better way.
    text = text .. "<P TextColor=\"00ffffff\">-</P>"
  end

  for i, mission in ipairs(self.missions) do
    local name = mission:GetName()
    if name == "" then
      name = "Path" -- TODO(nevir): Localize!
    end
    text = text .. string.format("<P TextColor=\"%s\">%s</P>", TOOLTIP_PATH_COLOR, name)
  end

  if text ~= "" and table.getn(self.reasons) > 0 then
    -- TODO(nevir): Gotta be a better way.
    text = text .. "<P TextColor=\"00ffffff\">-</P>"
  end

  for i, reason in ipairs(self.reasons) do
    if i > 1 then
      text = text .. "  •  "
    end
    -- TODO(nevir): Localize!
    text = text .. string.format("<T TextColor=\"%s\">%s</T>", TOOLTIP_REASON_COLOR, reason)
  end

  self.row:SetTooltip(text)
end
