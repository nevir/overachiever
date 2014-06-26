local Util = {}

Util.DefaultTable = {}
function Util.DefaultTable:new(factory)
  local instance = {}
  local metatable = {
    __index = function(table, key)
      local value = factory(key)
      table[key] = value
      return value
    end
  }
  setmetatable(instance, metatable)

  return instance
end


-- Seriously?

function Util.DistanceTo(position1, position2)
  local deltaX = position1.x - position2.x
  local deltaY = position1.y - position2.y
  local deltaZ = position1.z - position2.z
  return math.sqrt(math.pow(deltaX, 2) + math.pow(deltaY, 2) + math.pow(deltaZ, 2))
end 

function Util.Trim(string)
  return string:gsub("\A%s*(.-)%s*\Z", "%1")
end

function Util.Normalize(string)
  return Util.Trim(string):lower()
end

-- CountedReferenceMap --

Util.CountedReferenceMap = {}
Util.CountedReferenceMap.__index = Util.CountedReferenceMap

function Util.CountedReferenceMap:new()
  -- TODO(nevir): In debug mode, track count over time to help detect leaks.
  instance = {count = 0}
  setmetatable(instance, self)

  return instance
end

function Util.CountedReferenceMap:Add(id, value)
  if self[id] then return end
  self[id] = value
  self.count = self.count + 1
end

function Util.CountedReferenceMap:Remove(id)
  if not self[id] then return end
  self[id] = nil
  self.count = self.count - 1
end

Apollo.RegisterPackage(Util, "Overachiever.Util", 1, {})
