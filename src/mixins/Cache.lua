---@class TestFlight
local Addon = select(2, ...)
local Util = Addon.Util

---@class Cache<T, K>: { Key: K, Set: fun(self: self, key: any, value?: T), Has: (fun(self: self, key: any): boolean), Get: (fun(self: self, key: any): T?), Clear: fun(self: self)  }

---@class Cache
local CacheMixin = {}

---@generic T, K: function
---@param getKey `K`
---@param limit? number
---@return Cache<T, K>
function Addon:CreateCache(getKey, limit)
    return CreateAndInitFromMixin(CacheMixin, getKey, limit)
end

---@param getKey `K`
---@param limit? number
function CacheMixin:Init(getKey, limit)
    self.Key = getKey
    self.limit = limit
    self.keys = limit and {}
    self.values = {}
end

function CacheMixin:Set(key, value)
    if self.limit and self:Has(key) then
        tremove(self.keys, Util:TblIndexOf(self.keys, key))
    end

    self.values[key] = value

    if self.limit and value ~= nil then
        tinsert(self.keys, key)
        if #self.keys > self.limit then self:Set(self.keys[1]) end
    end
end

function CacheMixin:Has(key)
    return self.values[key] ~= nil
end

function CacheMixin:Get(key)
    return self.values[key]
end

function CacheMixin:Clear()
    wipe(self.values)
    if self.limit then wipe(self.keys) end
end