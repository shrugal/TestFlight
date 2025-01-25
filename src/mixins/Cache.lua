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

---@generic T
---@generic K, V: function
---@param getKey? K
---@param getVal? V
---@param limit? number
---@param priority? boolean
---@param getContext? fun(): any
---@return Cache<T, K, V>
function Static:Create(getKey, getVal, limit, priority, getContext)
    return self:Unserialize({}, getKey, getVal, limit, priority, getContext)
end

---@generic T
---@generic K, V: function
---@param getKey? K
---@param getVal? V
---@return Cache<T, K, V>
function Static:PerFrame(getKey, getVal)
    return self:Create(getKey, getVal, nil, nil, GetTime)
end

---@generic T
---@generic K, V: function
---@param cache table
---@param getKey? K
---@param getVal? V
---@param limit? number
---@param priority? boolean
---@param getContext? fun(): any
---@return Cache<T, K, V>
function Static:Unserialize(cache, getKey, getVal, limit, priority, getContext)
    Mixin(cache, Static.Mixin)
    cache:Init(getKey, getVal, limit, priority, getContext)
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
---@param getVal? function
---@param limit? number
---@param priority? boolean
---@param getContext? fun(): any
function Self:Init(getKey, getVal, limit, priority, getContext)
    assert(not priority or limit, "Priority cache needs a limit")

    self.Key = getKey or GetKey
    self.getVal = getVal
    self.getContext = getContext

    self.values = self.values or {}
    self.size = self.size or 0
    self.limit = limit
    self.keys = limit and (self.keys or {}) or nil
    self.priority = priority or false
    self.context = nil

    tinsert(Static.instances, self)
end

function Self:Set(key, value)
    self:CheckContext()

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
end

function Self:Unset(key)
    self:CheckContext()

    if self:Has(key) then
        self.size = self.size - 1

        if self.limit then
            tremove(self.keys, Util:TblIndexOf(self.keys, key) --[[@as number]])
        end
    end

    self.values[key] = nil
end

function Self:Has(key)
    self:CheckContext()

    return self.values[key] ~= nil
end

function Self:Get(key)
    self:CheckContext()

    if self.priority and self:Has(key) then
        local i = Util:TblIndexOf(self.keys, key) --[[@as number]]
        if i ~= self.size then
            tinsert(self.keys, tremove(self.keys, i))
        end
    end

    local value = self.values[key]
    if value == Util.NIL then return nil end
    return value
end

function Self:Val(...)
    self:CheckContext()

    local key = self:Key(...)
    if not self:Has(key) then self:Set(key, self:getVal(...)) end
    return self:Get(key)
end

function Self:CheckContext()
    if not self.getContext then return end
    local context = self.getContext()
    if context == self.context then return end
    self.context = context
    self:Clear()
end

function Self:Clear()
    self.size = 0
    wipe(self.values)

    if self.limit then wipe(self.keys) end
    if self.getContext then self.context = self.getContext() end
end