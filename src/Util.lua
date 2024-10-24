local Name = ...
---@class Addon
local Addon = select(2, ...)

---@class Util
local Self = Addon.Util

---@alias SearchFn<T, R, S> (fun(v: T, ...:any): R) | (fun(v: T, k: any, ...: any): R) | (fun(self: S, v: T, ...: any): R) | (fun(self: S, v: T, k: any, ...: any): R)

---@generic T
---@param val T
---@param ... T
function Self:OneOf(val, ...)
    for i=1,select("#", ...) do
        if select(i, ...) == val then return true end
    end
    return false
end

---@param targetAddonName string
---@param addonName string
function Self:IsAddonLoadingOrLoaded(targetAddonName, addonName)
    return addonName == targetAddonName or addonName == Name and C_AddOns.IsAddOnLoaded(targetAddonName)
end

-- Tbl

---@param tbl table
---@param path string
function Self:TblGet(tbl, path)
    while true do
        if not tbl then return end
        local i = path:find(".", nil, true)
        if not i then return tbl[path] end
        tbl, path = tbl[path:sub(1, i-1)], path:sub(i+1)
    end
end

---@generic K, T
---@param a Enumerator<T, K> | table<K, T>
---@param b? table<K, T>
---@param c? K
---@return Enumerator<T, K>
---@return table<K, T>?
---@return K?
function Self:Each(a, b, c, ...)
    if type(a) == "table" then
        return pairs(a)
    elseif type(a) == "function" then
        return a, b, c
    else
        return next, { a, b, c, ... }
    end
end

---@generic K, T
---@param a Enumerator<T, K> | table<K, T>
---@param b? table<K, T>
---@param c? K
---@return Enumerator<T, K>
---@return table<K, T>?
---@return K?
function Self:IEach(a, b, c, ...)
    if type(a) == "table" then
        return ipairs(a)
    else
        return self:Each(a, b, c, ...)
    end
end

---@param tbl table
function Self:TblKeys(tbl)
    local t = {}
    for k in pairs(tbl) do tinsert(t, k) end
    return t
end

function Self:TblValues(tbl)
    local t = {}
    for _,v in pairs(tbl) do tinsert(t, v) end
    return t
end

---@generic T: table
---@param tbl T | Enumerator<T>
---@param recursive? boolean
---@return T
function Self:TblCopy(tbl, recursive)
    local t = {}
    for k,v in self:Each(tbl) do
        if recursive and type(v) == "table" then
            t[k] = self:TblCopy(v, recursive)
        else
            t[k] = v
        end
    end
    return t
end


---@generic T
---@param tbl T[]
---@param ... T
---@return T[]
function Self:TblPush(tbl, ...)
    for i=1,select("#", ...) do
        tinsert(tbl, (select(i, ...)))
    end
    return tbl
end

---@param tbl table
---@param ... any
---@return table
function Self:TblFill(tbl, ...)
    return self:TblPush(wipe(tbl), ...)
end

---@generic T
---@param tbl T[]
---@param ... T[]
---@return T[]
function Self:TblMerge(tbl, ...)
    for i=1,select("#", ...) do
        self:TblPush(tbl, unpack(select(i, ...)))
    end
    return tbl
end

---@generic T, R, S: table
---@param tbl T[] | Enumerator<T>
---@param fn SearchFn<T, R, S>
---@param key? boolean
---@param obj? S
---@param ... any
---@return R[]
function Self:TblMap(tbl, fn, key, obj, ...)
    local t = {}
    for k,v in self:Each(tbl) do
        t[k] = self:FnCall(fn, v, key and k, obj, ...)
    end
    return t
end

---@generic T, R, S: table
---@param tbl T[] | Enumerator<T>
---@param by SearchFn<T, R, S> | string
---@param key? boolean
---@param obj? S
---@param ... any
---@return table<R, T[]>
function Self:TblGroupBy(tbl, by, key, obj, ...)
    local t, l = {}, self:TblIsList(tbl)
    for k,v in self:Each(tbl) do
        local g
        if type(by) == "string" then
            g = self:TblGet(v, by)
        else
            g = self:FnCall(by, v, key and k, obj, ...)
        end
        if g ~= nil then
            if not t[g] then t[g] = {} end
            if l then tinsert(t[g], v) else t[g][k] = v end
        end
    end
    return t
end

---@generic T, S: table
---@param tbl T[] | Enumerator<T>
---@param fn SearchFn<T, boolean, S>
---@param key? boolean
---@param obj? S
---@param ... any
---@return T[]
function Self:TblFilter(tbl, fn, key, obj, ...)
    local t, l = {}, self:TblIsList(tbl)
    for k,v in self:Each(tbl) do
        if self:FnCall(fn, v, key and k, obj) then
            if l then tinsert(t, v) else t[k] = v end
        end
    end
    return t
end

---@param tbl table
---@param ... any
function Self:TblMatch(tbl, ...)
    for i=1,select("#", ...), 2 do
        local k,v = select(i, ...), select(i+1, ...)
        if self:TblGet(tbl, k) ~= v then return false end
    end
    return true
end

---@generic T
---@param tbl T[] | Enumerator<T>
---@param ... any
---@return T?
function Self:TblWhere(tbl, ...)
    for _,v in self:Each(tbl) do
        if self:TblMatch(v, ...) then return v end
    end
end

---@generic T
---@param tbl T[] | Enumerator<T>
---@param ... any
---@return T[]
function Self:TblFilterWhere(tbl, ...)
    local t = {}
    for _,v in self:Each(tbl) do
        if self:TblMatch(v, ...) then tinsert(t, v) end
    end
    return t
end

---@generic T
---@param tbl T[] | Enumerator<T>
---@param ... any
---@return any?, T?
function Self:TblFindWhere(tbl, ...)
    for k,v in self:IEach(tbl) do
        if self:TblMatch(v, ...) then return k, v end
    end
end

---@generic T, R, S: table
---@param tbl T[] | Enumerator<T>
---@param fn (fun(prev: R, curr: T): R) | (fun(self: S, prev: R, curr: T): R)
---@param value? R
---@param obj? S
---@return R
function Self:TblReduce(tbl, fn, value, obj)
    for k,v in self:IEach(tbl) do
        if obj then
            value = fn(obj, value, v)
        else
            value = fn(value, v)
        end
    end
    return value
end

---@generic T, S: table
---@param tbl T[] | Enumerator<T>
---@param fn SearchFn<T, boolean, S>
---@param key? boolean
---@param obj? S
---@param ... any
---@return any?, T?
function Self:TblFind(tbl, fn, key, obj, ...)
    for k,v in self:Each(tbl) do
        if self:FnCall(fn, v, key and k, obj, ...) then return k, v end
    end
end

---@generic T
---@param tbl T[] | Enumerator<T>
---@param value T
function Self:TblIndexOf(tbl, value)
    for k,v in self:Each(tbl) do if v == value then return k end end
end

---@generic T
---@param tbl T[]
---@param value T
function Self:TblIncludes(tbl, value)
    return self:TblIndexOf(tbl, value) ~= nil
end

---@generic T
---@param tbl T[]
---@param fn? fun(a: T, b: T): number
---@return T[]
function Self:TblSort(tbl, fn)
    table.sort(tbl, fn)
    return tbl
end

function Self:TblSortBy(tbl, by)
    return Self:TblSort(tbl, self:FnCompareBy(by))
end

-- Tbl scan

---@generic T, K
---@param tbl table<K, T>
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

---@param fn fun(v: any, k: any, currV: any?, currK: any?, tbl: table): boolean
local function CreateScanFn(fn)
    ---@generic T, K
    ---@param self Util
    ---@param tbl table<K, T>
    ---@param start? K
    ---@param stop? K
    ---@return K, T
    return function (self, tbl, start, stop)
        return self:TblScan(tbl, fn, start, stop)
    end
end

---@param fn fun(v: any, k: any, currV: any?, currK: any?, tbl: table): boolean
local function CreateScanValueFn(fn)
    ---@generic T, K
    ---@param self Util
    ---@param tbl table<K, T>
    ---@param start? K
    ---@param stop? K
    ---@return T
    return function (self, tbl, start, stop)
        return select(2, self:TblScan(tbl, fn, start, stop))
    end
end

---@param fn fun(v: any, k: any, currV: any?, currK: any?, tbl: table): boolean
local function CreateScanKeyFn(fn)
    ---@generic T, K
    ---@param self Util
    ---@param tbl table<K, T>
    ---@param start? K
    ---@param stop? K
    ---@return K
    return function (self, tbl, start, stop)
        return (self:TblScan(tbl, fn, start, stop))
    end
end

Self.TblFindMin = CreateScanFn(function (v, _, currV) return not currV or v < currV end)
Self.TblFindMax = CreateScanFn(function (v, _, currV) return not currV or v > currV end)
Self.TblMin = CreateScanValueFn(function (v, _, currV) return not currV or v < currV end)
Self.TblMax = CreateScanValueFn(function (v, _, currV) return not currV or v > currV end)
Self.TblMinKey = CreateScanKeyFn(function (_, k, _, currK) return not currK or k < currK end)
Self.TblMaxKey = CreateScanKeyFn(function (_, k, _, currK) return not currK or k > currK end)

function Self:TblIsList(tbl)
    return #tbl == self:TblCount(tbl)
end

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
        if not fn or self:FnCall(fn, tbl[k], k, obj, ...) then c = c + 1 end
        k = next(tbl, k)
    end
    return c
end

---@generic T
---@param tbl T[] | Enumerator<T>
---@param ... any
---@return number
function Self:TblCountWhere(tbl, ...)
    local c = 0
    for _,v in self:Each(tbl) do
        if self:TblMatch(v, ...) then c = c + 1 end
    end
    return c
end

---@param tbl table
---@param sep string
function Self:TblJoin(tbl, sep)
    return table.concat(tbl, sep)
end

-- Mixin

-- Create a Mixin from all class methods
---@generic T: table
---@param tbl T[] | Enumerator<T>
---@return T
function Self:TblCreateMixin(tbl)
    local t = {}
    for k,v in self:Each(tbl) do
        if type(v) == "function" and type(k) == "string" and k:match("^[A-Z]") then
            t[k] = v
        end
    end
    return t
end

-- Like Mixin, but combines "OnXYZ" event handlers, instead of overriding them
---@generic T: table
---@vararg T
---@return T
function Self:TblCombineMixins(...)
    local n, r = select("#", ...), {}
    for i=1,n do
        for k,v in pairs(select(i, ...)) do
            if type(v) == "function" and type(k) == "string" and k:match("^On[A-Z]") then
                if not r[k] then
                    local fns = {}
                    for j=1,n do local t = select(j, ...) if t[k] then tinsert(fns, t[k]) end end
                    r[k] = self:FnCombine(fns)
                end
            else
                r[k] = v
            end
        end
    end
    return r
end

-- Hook

---@type table<table, table<string, function>>
Self.hooks = {}

---@param tbl? table
---@param key string
---@param fn? function
---@param obj? table
---@return function?
function Self:TblHook(tbl, key, fn, obj)
    if not tbl or self.hooks[tbl] and self.hooks[tbl][key] then return end
    if fn and obj then fn = self:FnBind(fn, obj) end

    self.hooks[tbl] = self.hooks[tbl] or {}
    self.hooks[tbl][key] = tbl[key]
    tbl[key] = fn

    return self.hooks[tbl][key]
end

---@param tbl? table
---@param key string
---@return function?
function Self:TblUnhook(tbl, key)
    if not tbl or not self.hooks[tbl] or not self.hooks[tbl][key] then return end

    local fn = tbl[key]
    tbl[key] = self.hooks[tbl][key]
    self.hooks[tbl][key] = nil

    return fn
end

---@param tbl table
function Self:TblGetHooks(tbl)
    return self.hooks[tbl]
end

---@param tbl table
---@param key string
function Self:TblIsHooked(tbl, key)
    return self.hooks[tbl] and self.hooks[tbl][key] ~= nil
end

---@param tbl table
---@param key string
---@return function
function Self:TblGetHooked(tbl, key)
    if self:TblIsHooked(tbl, key) then return self.hooks[tbl][key] end
    return tbl[key]
end

-- Str

function Self:StrIsEmpty(str)
    return not str or str == "" or str:gsub("%s+", "") == ""
end

---@param str string
function Self:StrUcFirst(str)
    return str:sub(1, 1):upper() .. str:sub(2)
end

-- Num

function Self:NumCurrencyString(amount)
    local str = C_CurrencyInfo.GetCoinTextureString(math.abs(amount))
    if amount < 0 then str = "|c00ff0000-" .. str .. "|r" end
    return str
end

function Self:NumRound(n, p)
    local f = math.pow(10, p or 0)
    return math.floor(0.5 + n * f) / f
end

-- Fn

function Self.FnInfinite() return math.huge end

function Self.FnFalse() return false end

function Self.FnTrue() return true end

function Self.FnId(...) return ... end

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

function Self:FnCompareBy(by)
    return function (a, b)
        if type(by) == "string" then
            a, b = self:TblGet(a, by), self:TblGet(b, by)
        else
            a, b = by(a), by(b)
        end
        return a and a < b or false
    end
end

---@param fn function
---@param ... any
---@return function
function Self:FnBind(fn, ...)
    return GenerateClosure(fn, ...)
end

---@generic T: function
---@param fns T[] | T
---@vararg T
---@return T
function Self:FnCombine(fns, ...)
    if type(fns) == "function" then fns = { fns, ... } end

    local n = #fns
    if n == 1 then return fns[1] end

    return function (...)
        for i,fn in ipairs(fns) do
            if i < n then fn(...) else return fn(...) end
        end
    end
end

---@param fns function[] | function
---@vararg function
---@return function
function Self:FnCompose(fns, ...)
    if type(fns) == "function" then fns = { fns, ... } end

    local n = #fns
    if n == 1 then return fns[1] end

    return function (...)
        local args = {...}
        for _,fn in ipairs(fns) do
            self:TblFill(args, fn(unpack(args)))
        end
        return unpack(args)
    end
end

---@param fn function
---@param onSuccess? function
---@param onFailure? function
---@param errorHandler? function
function Self:FnCapture(fn, onSuccess, onFailure, errorHandler)
    if not onSuccess then onSuccess = Self.FnId end
    local result = {}
    return function(...)
        self:TblFill(result, xpcall(fn, errorHandler or self.FnId, ...))
        if result[1] then
            return onSuccess(unpack(result, 2))
        elseif onFailure then
            return onFailure(unpack(result, 2))
        end
    end
end

-- Chain

local CHAIN_PREFIX = {
    table = "Tbl",
    string = "Num",
    boolean = "Bool",
    ["function"] = "Fn"
}

local chainKey, chainVal
local chainFn = function (self, ...)
    local prefix = CHAIN_PREFIX[type(chainVal)]
    local fn = Self[(prefix or "") .. chainKey]
    return Self(fn(Self, chainVal, ...))
end

local Chain = setmetatable({}, {
      __index = function (_, key) chainKey = key return chainFn end,
      __call = function () return chainVal end
})

setmetatable(Self, {
      __call = function (_, val) chainVal = val return Chain end
})