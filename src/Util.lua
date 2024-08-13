---@class TestFlight
local Addon = select(2, ...)

---@class Util
local Self = {}
Addon.Util = Self

---@alias SearchFn<T, R, S> (fun(v: T, ...:any): R) | (fun(v: T, k: any, ...: any): R) | (fun(self: S, v: T, ...: any): R) | (fun(self: S, v: T, k: any, ...: any): R)

-- Tbl

---@generic T, S: table
---@param tbl T[]
---@param fn? SearchFn<T, boolean, S>
---@param key? boolean
---@param obj? S
---@param ... any
---@return number
function Self:TblCount(tbl, fn, key, obj, ...)
    local c, k = 0, next(tbl)
    while k do
        if not fn or Self:FnCall(fn, tbl[k], k, obj, ...) then c = c + 1 end
        k = next(tbl, k)
    end
    return c
end

---@generic T: table
---@param tbl T
---@param recursive? boolean
---@return T
function Self:TblCopy(tbl, recursive)
    local t = {}
    for k,v in pairs(tbl) do
        if recursive and type(v) == "table" then
            t[k] = self:TblCopy(v, recursive)
        else
            t[k] = v
        end
    end
    return t
end

---@generic T: table
---@param tbl T
---@return T
function Self:TblCreateMixin(tbl)
    local t = {}
    for k,v in pairs(tbl) do
        if type(v) == "function" and type(k) == "string" and k:match("^[A-Z]") then
            t[k] = v
        end
    end
    return t
end

---@generic T, R, S: table
---@param tbl T[]
---@param fn SearchFn<T, R, S>
---@param key? boolean
---@param obj? S
---@param ... any
---@return R[]
function Self:TblMap(tbl, fn, key, obj, ...)
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = self:FnCall(fn, v, key and k, obj, ...)
    end
    return t
end

---@generic T, S: table
---@param tbl T[]
---@param fn SearchFn<T, boolean, S>
---@param key? boolean
---@param obj? S
---@param ... any
---@return T[]
function Self:TblFilter(tbl, fn, key, obj, ...)
    local t = {}
    for k,v in pairs(tbl) do
        if self:FnCall(fn, v, key and k, obj) then tinsert(t, v) end
    end
    return t
end

---@param tbl table
---@param ... any
function Self:TblMatch(tbl, ...)
    for i=1,select("#", ...), 2 do
        local k,v = select(i, ...), select(i+1, ...)
        if tbl[k] ~= v then return false end
    end
    return true
end

---@generic T
---@param tbl T[]
---@param ... any
---@return T?
function Self:TblWhere(tbl, ...)
    for _,v in pairs(tbl) do
        if self:TblMatch(v, ...) then return v end
    end
end

---@generic T
---@param tbl T[]
---@param ... any
---@return T[]
function Self:TblFilterWhere(tbl, ...)
    local t = {}
    for _,v in pairs(tbl) do
        if self:TblMatch(v, ...) then tinsert(t, v) end
    end
    return t
end

---@generic T, R, S: table
---@param tbl T[]
---@param fn (fun(prev: R, curr: T): R) | (fun(self: S, prev: R, curr: T): R)
---@param value? R
---@param obj? S
---@return R
function Self:TblReduce(tbl, fn, value, obj)
    for k,v in ipairs(tbl) do
        if obj then
            value = fn(obj, value, v)
        else
            value = fn(value, v)
        end
    end
    return value
end

---@generic T, S: table
---@param tbl T[]
---@param fn SearchFn<T, boolean, S>
---@param key? boolean
---@param obj? S
---@param ... any
---@return any?, T?
function Self:TblFind(tbl, fn, key, obj, ...)
    for k,v in pairs(tbl) do
        if self:FnCall(fn, v, key and k, obj, ...) then return k, v end
    end
end

---@generic T
---@param tbl T[]
---@param value T
function Self:TblIndexOf(tbl, value)
    for k,v in pairs(tbl) do if v == value then return k end end
end

---@generic T
---@param tbl T[]
---@param value T
function Self:TblIncludes(tbl, value)
    return self:TblIndexOf(tbl, value) ~= nil
end

---@generic T, K
---@param tbl T[]
---@param fn fun(v: T, k: K, currV: T?, currK: K?, tbl: T[]): boolean
---@param start? K
---@param stop? K
---@return K, T
function Self:TblScan(tbl, fn, start, stop)
    local currK, currV = nil, nil
    if start or stop then
        for k=start or 1, stop or #tbl do
            if fn(tbl[k], k, currV, currK, tbl) then currK, currV = k, tbl[k] end
        end
    else
        for k,v in pairs(tbl) do
            if fn(tbl[k], k, currV, currK, tbl) then currK, currV = k, v end
        end
    end
    return currK, currV
end

---@generic T, K
---@param tbl T[]
---@param start? K
---@param stop? K
---@return K, T
function Self:TblFindMin(tbl, start, stop)
    return self:TblScan(tbl, function (v, _, currV) return not currV or v < currV end, start, stop)
end

---@generic T, K
---@param tbl T[]
---@param start? K
---@param stop? K
---@return K, T
function Self:TblFindMax(tbl, start, stop)
    return self:TblScan(tbl, function (v, _, currV) return not currV or v > currV end, start, stop)
end

---@generic T
---@param tbl T[]
---@param fn fun(a: T, b: T): number
---@return T[]
function Self:TblSorted(tbl, fn)
    local t = self:TblCopy(tbl)
    table.sort(t, fn)
    return t
end

-- Hook

---@type table<table, table<string, function>>
Self.hooks = {}

function Self:TblHook(tbl, name, fn)
    if not tbl or self.hooks[tbl] and self.hooks[tbl][name] then return end
    self.hooks[tbl] = self.hooks[tbl] or {}
    self.hooks[tbl][name] = tbl[name]
    tbl[name] = fn
    return self.hooks[tbl][name]
end

function Self:TblUnhook(tbl, name)
    if not tbl or not self.hooks[tbl] or not self.hooks[tbl][name] then return end
    local fn = tbl[name]
    tbl[name] = self.hooks[tbl][name]
    self.hooks[tbl][name] = nil
    return fn
end

function Self:TblGetHooks(tbl)
    return self.hooks[tbl]
end

-- Str

function Self:StrFormatMoney(money)
    local gold = math.floor(money / 10000)
    local silver = math.floor(money % 10000 / 100)
    local copper = money % 100

    return ("%dg %ds %dc"):format(gold, silver, copper)
end

-- Fn

function Self.FnInfinite() return math.huge end

function Self.FnFalse() return false end

function Self.FnTrue() return true end

function Self.FnNoop() end

---@generic T, R, S: table
---@param fn SearchFn<T, R, S>
---@param v T
---@param k? any
---@param s? S
---@param ... any
---@return R
function Self:FnCall(fn, v, k, s, ...)
    if s and k then
        return fn(s, v, k, ...)
    elseif s then
        return fn(s, v, ...)
    elseif k then
        return fn(v, k, ...)
    else
        return fn(v, ...)
    end
end