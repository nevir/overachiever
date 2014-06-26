local Achievements = {}
Achievements.__index = Achievements

Apollo.RegisterPackage(Achievements, "Overachiever.Achievements", 1, {
  "Gemini:Locale-1.0",
  "Overachiever.Util",
})

local L
local Util
function Achievements:OnLoad()
  L    = Apollo.GetPackage("Gemini:Locale-1.0").tPackage:GetLocale("Overachiever")
  Util = Apollo.GetPackage("Overachiever.Util").tPackage
end

local ACTIVATION_COLLECT  = "Collect"
local ACTIVATION_INTERACT = "Interact"
local ACTIVATION_LORE     = "Datacube"
local ACTIVATION_SPELL    = "Spell"

local CATEGORY_EXPLORATION  = 1
local CATEGORY_QUEST        = 3
local CATEGORY_KILL         = 4
local CATEGORY_PVP          = 7
local CATEGORY_PATHS        = 9
local CATEGORY_REPUTATION   = 11
local CATEGORY_GENERAL      = 12
local CATEGORY_DUNGEONS     = 65
local CATEGORY_ADVENTURES   = 78
local CATEGORY_CHALLENGES   = 161
local CATEGORY_SHIPHAND     = 162
local CATEGORY_PUBLIC_EVENT = 163
local CATEGORY_RAIDS        = 164
local CATEGORY_WORLD_STORY  = 175
local CATEGORY_SOCIAL       = 281
local CATEGORY_HOTSHOT      = 284

-- Achievement Indexing --

function Achievements:new(config)
  instance = {
    config = config,
    watchedByUnitName = Util.DefaultTable:new(function(key) return {} end),
    secretStashByZone = {},
  }
  setmetatable(instance, self)

  return instance
end

function Achievements:IndexAll()
  self:IndexKillAchievements()
  self:IndexSecretStashAchievements()
end

function Achievements:IndexKillAchievements()
  for i, achievement in ipairs(self:IncompleteForCategory(CATEGORY_KILL, true)) do
    for j, item in ipairs(achievement:GetChecklistItems() or {}) do
      if not item.bIsComplete then
        local name = Util.Normalize(item.strChecklistEntry)
        table.insert(self.watchedByUnitName[name], achievement)
      end
    end
  end
end

function Achievements:IndexSecretStashAchievements()
  
end

-- Querying --

function Achievements:ForUnit(unit)
  local achievements = {}
  local forName = rawget(self.watchedByUnitName, Util.Normalize(unit:GetName()))
  for i, achievement in ipairs(forName or {}) do
    table.insert(achievements, achievement)
  end

  return achievements
end

-- TODO(nevir): This should really be elsewhere, but for now it's convenient to
-- keep the ACTIVATION_* constants together.
function Achievements:ExtraReasonsForUnit(unit)
  local reasons = {}
  local activations = unit:GetActivationState() or {}
  if activations[ACTIVATION_LORE] then
    table.insert(reasons, "Lore") -- TODO(nevir): Constant!
  end

  if activations[ACTIVATION_COLLECT] and unit:GetName() == L["Unit_SecretStash"] then
    table.insert(reasons, "SecretStash") -- TODO(nevir): Constant!
  end

  return reasons
end

function Achievements:IsUnitInteresting(unit)
  if rawget(self.watchedByUnitName, Util.Normalize(unit:GetName())) then
    return true
  else
    return false
  end
end

-- Utility --

function Achievements:IncompleteForCategory(category, deep)
  local achievements = {}
  for i, achievement in ipairs(AchievementsLib.GetAchievementsForCategory(category, deep)) do
    if not achievement:IsComplete() then
      table.insert(achievements, achievement)
    end
  end
  return achievements
end
