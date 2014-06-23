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

-- UNUSED:

Util.Set = {}
function Util.Set:new()
  instance = {count = 0}
  setmetatable(instance, self)
  return instance
end
Util.Set.__index = Util.Set

function Util.Set:_Add(item)
  if self[item] then return end
  self[item] = true
  self.count = self.count + 1
end

function Util.Set:_Remove(item)
  if not self[item] then return end
  self[item] = nil
  self.count = self.count - 1
end

function Util.Set:_Toggle(item, add)
  if add then
    self:_Add(item)
  else
    self:_Remove(item)
  end
end

Apollo.RegisterPackage(Util, "Overachiever.Util", 1, {})
