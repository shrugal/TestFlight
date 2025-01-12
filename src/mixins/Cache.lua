---@class Addon
local Addon = select(2, ...)
local Util = Addon.Util

---@class Cache<T, K>: { Key: K, Set: fun(self: Cache, key: any, value?: T), Unset: fun(self: Cache, key: any), Has: (fun(self: Cache, key: any): boolean), Get: (fun(self: Cache, key: any): T?), Clear: fun(self: Cache)  }

---@class Cache.Static
local Static = Addon.Cache

---@type Cache[]
Static.instances = setmetatable({}, { __mode = "v" })

Static.NIL = {}

function Static:ClearAll()
    for _,cache in pairs(self.instances) do cache:Clear() end
end

---@type Cache
---@diagnostic disable-next-line: missing-fields
Static.Mixin = {}

---@class Cache
local Self = Static.Mixin

---@generic T, K: function
---@param getKey `K`
---@param limit? number
---@param priority? boolean
---@return Cache<T, K>
function Static:Create(getKey, limit, priority)
    return self:Unserialize({}, getKey, limit, priority)
end

---@generic T, K: function
---@param cache table
---@param getKey `K`
---@param limit? number
---@param priority? boolean
---@return Cache<T, K>
function Static:Unserialize(cache, getKey, limit, priority)
    Mixin(cache, Static.Mixin)
    cache:Init(getKey, limit, priority)
    return cache
end

local function GetKey(_, ...)
    local s = ""
    for i=1,select("#", ...) do
        s = s .. (i > 1 and "|" or "") .. tostring(s)
    end
    return s
end

---@param getKey function
---@param limit? number
---@param priority? boolean
function Self:Init(getKey, limit, priority)
    assert(not priority or limit, "Priority cache needs a limit")

    self.Key = getKey or GetKey
    self.values = self.values or {}
    self.size = self.size or 0
    self.limit = limit
    self.keys = limit and (self.keys or {}) or nil
    self.priority = priority or false

    tinsert(Static.instances, self)
end

function Self:Set(key, value)
    if not self:Has(key) then
        self.size = self.size + 1

        if self.limit then
            tinsert(self.keys, key)
            if self.size > self.limit then self:Unset(self.keys[1]) end
        end
    elseif self.priority then
        local i = Util:TblIndexOf(self.keys, key)
        if i ~= self.size then
            tinsert(self.keys, tremove(self.keys, i))
        end
    end

    self.values[key] = value == nil and Static.NIL or value
end

function Self:Unset(key)
    if self:Has(key) then
        self.size = self.size - 1

        if self.limit then
            tremove(self.keys, Util:TblIndexOf(self.keys, key))
        end
    end

    self.values[key] = nil
end

function Self:Has(key)
    return self.values[key] ~= nil
end

function Self:Get(key)
    if self.priority and self:Has(key) then
        local i = Util:TblIndexOf(self.keys, key)
        if i ~= self.size then
            tinsert(self.keys, tremove(self.keys, i))
        end
    end

    local value = self.values[key]
    if value == Static.NIL then return nil end
    return value
end

function Self:Clear()
    wipe(self.values)
    if self.limit then wipe(self.keys) end
end