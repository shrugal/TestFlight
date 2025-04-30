---@class Addon
local Addon = select(2, ...)
local Util = Addon.Util

---@class Cache<T, K, V>: { Key: K, Set: fun(self: Cache, key: any, value?: T), Unset: fun(self: Cache, key: any), Has: (fun(self: Cache, key: any): boolean), Get: (fun(self: Cache, key: any): T?), Val: V, Clear: fun(self: Cache)  }

---@class Cache.Static
local Static = Addon.Cache

---@type Cache[]
Static.instances = setmetatable({}, { __mode = "v" })

function Static:ClearAll()
    for _,cache in pairs(self.instances) do cache:Clear() end
end

---@type Cache
---@diagnostic disable-next-line: missing-fields
Static.Mixin = {}

---@class Cache
local Self = Static.Mixin

local function GetKey(_, ...)
    local s = ""
    for i=1,select("#", ...) do
        s = s .. (i > 1 and "|" or "") .. tostring(s)
    end
    return s
end

---@generic T
---@generic K, V: function
---@param getKey? K
---@param getVal? V
---@param limit? number
---@param priority? boolean
---@return Cache<T, K, V>
function Static:Create(getKey, getVal, limit, priority)
    return self:Unserialize({}, getKey, getVal, limit, priority)
end

---@generic T
---@generic K, V: function
---@param getKey? K
---@param getVal? V
---@return Cache<T, K, V>
function Static:PerFrame(getKey, getVal)
    if not getKey then getKey = GetKey end
    return self:Create(function (...) return getKey(...), GetTime() end, getVal, nil, nil)
end

---@generic T
---@generic K, V: function
---@param cache table
---@param getKey? K
---@param getVal? V
---@param limit? number
---@param priority? boolean
---@return Cache<T, K, V>
function Static:Unserialize(cache, getKey, getVal, limit, priority)
    Mixin(cache, Static.Mixin)
    cache:Init(getKey, getVal, limit, priority)
    return cache
end

---@param getKey function
---@param getVal? function
---@param limit? number
---@param priority? boolean
function Self:Init(getKey, getVal, limit, priority)
    assert(not priority or limit, "Priority cache needs a limit")

    self.Key = getKey or GetKey
    self.getVal = getVal

    self.values = self.values or {}
    self.contexts = self.contexts or {}
    self.size = self.size or 0
    self.limit = limit
    self.keys = limit and (self.keys or {}) or nil
    self.priority = priority or false

    tinsert(Static.instances, self)
end

function Self:Set(key, value, ctx)
    if not self:Has(key) then
        self.size = self.size + 1

        if self.limit then
            tinsert(self.keys, key)
            if self.size > self.limit then self:Unset(self.keys[1]) end
        end
    elseif self.priority then
        local i = Util:TblIndexOf(self.keys, key) --[[@as number]]
        if i ~= self.size then
            tinsert(self.keys, tremove(self.keys, i))
        end
    end

    self.values[key] = value == nil and Util.NIL or value
    self.contexts[key] = ctx
end

function Self:Unset(key)
    if not self:Has(key) then return end

    self.size = self.size - 1

    if self.limit then
        tremove(self.keys, Util:TblIndexOf(self.keys, key) --[[@as number]])
    end

    self.values[key] = nil
    self.contexts[key] = nil
end

function Self:Has(key)
    return self.values[key] ~= nil
end

function Self:Valid(key, ctx)
    return self:Has(key) and self.contexts[key] == ctx
end

---@generic T
---@return T?
function Self:Get(key)
    if not self:Has(key) then return end

    if self.priority then
        local i = Util:TblIndexOf(self.keys, key) --[[@as number]]
        if i ~= self.size then
            tinsert(self.keys, tremove(self.keys, i))
        end
    end

    local value = self.values[key]
    if value == Util.NIL then return nil end

    return value
end

---@generic T
---@return T?
function Self:Val(...)
    local key, ctx = self:Key(...)

    if not self:Valid(key, ctx) then self:Set(key, self:getVal(...), ctx) end

    return self:Get(key)
end

function Self:Clear()
    self.size = 0

    wipe(self.values)
    wipe(self.contexts)

    if self.limit then wipe(self.keys) end
end