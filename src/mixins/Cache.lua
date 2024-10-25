---@class Addon
local Addon = select(2, ...)
local Util = Addon.Util

---@class Cache<T, K>: { Key: K, Set: fun(self: Cache, key: any, value?: T), Has: (fun(self: Cache, key: any): boolean), Get: (fun(self: Cache, key: any): T?), Clear: fun(self: Cache)  }

---@class Cache.Static
local Static = Addon.Cache

Static.NIL = {}

---@type Cache
Static.Mixin = {}

---@class Cache
local Self = Static.Mixin

---@generic T, K: function
---@param getKey `K`
---@param limit? number
---@return Cache<T, K>
function Static:Create(getKey, limit)
    return CreateAndInitFromMixin(Static.Mixin, getKey, limit)
end

local function GetKey(_, ...) local s = "" for i=1,select("#", ...) do s = s .. (i > 1 and "|" or "") .. tostring(s) end return s end

---@param getKey function
---@param limit? number
function Self:Init(getKey, limit)
    self.Key = getKey or GetKey
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