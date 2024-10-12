---@class Addon
local Addon = select(2, ...)
local Util = Addon.Util

---@class Cache<T, K>: { Key: K, Set: fun(self: Cache, key: any, value?: T), Has: (fun(self: Cache, key: any): boolean), Get: (fun(self: Cache, key: any): T?), Clear: fun(self: Cache)  }

---@class Cache
local Self = {}

---@generic T, K: function
---@param getKey `K`
---@param limit? number
---@return Cache<T, K>
function Addon:CreateCache(getKey, limit)
    return CreateAndInitFromMixin(Self, getKey, limit)
end

---@param getKey function
---@param limit? number
function Self:Init(getKey, limit)
    self.Key = getKey
    self.limit = limit
    self.keys = limit and {}
    self.values = {}
end

function Self:Set(key, value)
    if self.limit and self:Has(key) then
        tremove(self.keys, Util:TblIndexOf(self.keys, key))
    end

    self.values[key] = value

    if self.limit and value ~= nil then
        tinsert(self.keys, key)
        if #self.keys > self.limit then self:Set(self.keys[1]) end
    end
end

function Self:Has(key)
    return self.values[key] ~= nil
end

function Self:Get(key)
    return self.values[key]
end

function Self:Clear()
    wipe(self.values)
    if self.limit then wipe(self.keys) end
end