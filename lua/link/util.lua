local M = {}

local function class(base)
    local cls = base or {}
    cls.__index = cls

    function cls:new(...)
        local instance = setmetatable({}, cls)
        if instance.init then
            instance:init(...)
        end
        return instance
    end

    setmetatable(cls, {
        __call = function(c, ...)
            return c:new(...)
        end
    })

    return cls
end
M.class = class

local function append_unique(list1, list2)
  local seen = {}
  local result = {}

  for _, item in ipairs(list1 or {}) do
    result[#result + 1] = item
    seen[item] = true
  end

  for _, item in ipairs(list2 or {}) do
    if not seen[item] then
      result[#result + 1] = item
      seen[item] = true
    end
  end

  return result
end
M.append_unique = append_unique

local function list_to_set(list)
  local set = {}
  for _, v in ipairs(list or {}) do
    set[v] = true
  end
  return set
end
M.list_to_set = list_to_set


return M
