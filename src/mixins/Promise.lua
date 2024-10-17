---@class Addon
local Addon = select(2, ...)
local Async, Util = Addon.Async, Addon.Util

---@class Promise
---@field statusResult table
---@field callbacks table<Promise.Status, function[]>
local Self = { __promise__ = true }

---@param runner? fun(resolve: function, reject: function, cancel: function): any
---@param parent? Promise
function Addon:CreatePromise(runner, parent)
    local promise = CreateAndInitFromMixin(Self, runner, parent)
    Async:Execute(promise)
    return promise
end

---@enum Promise.Status
Self.Status = {
    Created = "created",
    Suspended = "suspended",
    Running = "running",
    Canceled = "canceled",
    Done = "done",
    Error = "error",
}

---@enum Promise.Event
Self.Event = {
    OnProgress = "progress",
    OnCancel = Self.Status.Canceled,
    OnDone = Self.Status.Done,
    OnError = Self.Status.Error,
    OnFinally = "finally"
}

---@todo DEBUG
-- local PROMISES = {}
-- local function GetNumber(p) return Util:TblIndexOf(PROMISES, p) end

---@param runner? fun(resolve: function, reject: function, cancel: function): any
---@param parent? Promise
function Self:Init(runner, parent)
    -- tinsert(PROMISES, self)

    ---@type Promise.Status
    self.status = Self.Status.Created
    ---@type any[]
    self.statusResult = {}
    ---@type table<Promise.Event, function[]>
    self.callbacks = {}

    self.resolve = Util:FnBind(self.Resolve, self)
    self.reject = Util:FnBind(self.Reject, self)
    self.cancel = Util:FnBind(self.Cancel, self)

    if runner then
        self.runner = Util:FnBind(runner, self.resolve, self.reject, self.cancel)
    end
    if parent then
        self.parent = parent
    end
end

---------------------------------------
--                API
---------------------------------------

---@param onWait? function
---@vararg any
function Self:Wait(onWait, ...)
    if self.status == Self.Status.Created then
        self:Resume()
    end
    if onWait and self:IsPending() then
        local onFinally = onWait(...)
        if type(onFinally) == "function" then self:Finally(onFinally) end
    end
    return self
end

---@param onProgress function
---@vararg any
function Self:Progress(onProgress, ...)
    if self:IsPending() then
        self:RegisterCallback(Self.Event.OnProgress, onProgress, ...)
    end
    if self.status == Self.Status.Suspended then
        onProgress(unpack(self.statusResult))
    end
    return self
end

---@param onFinally function
---@vararg any
function Self:Finally(onFinally, ...)
    if self:IsFinalized() then
        onFinally(...)
    else
        self:RegisterCallback(Self.Event.OnFinally, onFinally, ...)
    end
    return self
end

---@param onDone? function
---@param onError? function
---@vararg any
function Self:Then(onDone, onError, ...)
    if self:IsCanceled() then return self end
    if not onDone and not onError then return self end

    if select("#", ...) > 0 then
        if onDone then onDone = Util:FnBind(onDone, ...) end
        if onError then onError = Util:FnBind(onError, ...) end
    end

    return Addon:CreatePromise(function (resolve, reject, cancel)
        if onDone then resolve = Util:FnSafe(onDone, resolve, reject) end
        if onError then reject = Util:FnSafe(onError, resolve, reject) end

        if self.status == Self.Status.Canceled then
            cancel()
        elseif self.status == Self.Status.Done then
            resolve(unpack(self.statusResult))
        elseif self.status == Self.Status.Error then
            reject(unpack(self.statusResult))
        else
            self:RegisterCallback(Self.Event.OnDone, resolve)
            self:RegisterCallback(Self.Event.OnError, reject)
            self:RegisterCallback(Self.Event.OnCancel, cancel)
            self:Wait()
        end
    end, self)
end

---@param onDone function
---@vararg any
function Self:Done(onDone, ...)
    return self:Then(onDone, nil, ...)
end

---@param onError function
---@vararg any
function Self:Error(onError, ...)
    return self:Then(nil, onError, ...)
end

function Self:Cancel()
    if self:IsFinalized() then return end

    self:Finalize(Self.Status.Canceled)
end

function Self:IsPending()
    return Util:OneOf(self.status, Self.Status.Created, Self.Status.Running, Self.Status.Suspended)
end

function Self:IsFinalized()
    return Util:OneOf(self.status, Self.Status.Canceled, Self.Status.Done, Self.Status.Error)
end

function Self:IsCanceled()
    return self.status == Self.Status.Canceled
end

---------------------------------------
--              Execution
---------------------------------------

function Self:Resume()
    if not self.runner then return self end
    if not self.coroutine then
        self.coroutine = coroutine.create(self.runner)
    end
    if coroutine.status(self.coroutine) == "suspended" then
        self.status = Self.Status.Running
        self:Handle(coroutine.resume(self.coroutine))
    end
    return self
end

---@param success boolean
---@vararg any
function Self:Handle(success, ...)
    if self.status == Self.Status.Running then
        local state = coroutine.status(self.coroutine)
        if not success then
            self:Reject(...)
        elseif state == "dead" and select("#", ...) > 0 then
            self:Resolve(...)
        else
            self.status = Self.Status.Suspended
            Util:TblFill(self.statusResult, ...)

            self:TriggerCallbacks(Self.Event.OnProgress, ...)
        end
    elseif not success then
        error(..., 0)
    end
end

---@param status "canceled" | "done" | "error"
---@vararg any
function Self:Finalize(status, ...)
    local first = select(1, ...)
    if type(first) == "table" and first.__promise__ then ---@cast first Promise
        return first:Then(self.resolve, self.reject)
    end

    self.status = status
    Util:TblFill(self.statusResult, ...)

    local handled, errorMsg = self:TriggerCallbacks(status, ...)
    self:TriggerCallbacks(Self.Event.OnFinally)
    wipe(self.callbacks)

    if handled ~= false then return handled end

    error(errorMsg, 0)
end

---@vararg any
function Self:Resolve(...)
    if self:IsFinalized() then return end

    self:Finalize(Self.Status.Done, ...)
end

---@vararg any
function Self:Reject(...)
    if self:IsFinalized() then return end

    local handled = self:Finalize(Self.Status.Error, ...)
    if handled then return end

    error(("Unhandled promise error: %s"):format(... or "?"), 0)
end

---------------------------------------
--             Callbacks
---------------------------------------

---@param type Promise.Event
---@param handler function
---@vararg any
function Self:RegisterCallback(type, handler, ...)
    if select("#", ...) > 0 then handler = Util:FnBind(handler, ...) end

    if not self.callbacks[type] then self.callbacks[type] = {} end

    tinsert(self.callbacks[type], handler)
end

---@param type Promise.Event
---@vararg any
function Self:TriggerCallbacks(type, ...)
    local callbacks = self.callbacks[type]
    if not callbacks or not next(callbacks) then return end

    local handled, errorMsg = true, nil
    for _,handler in ipairs(callbacks) do
        local ok, result = pcall(handler, ...)
        if not ok and handled then handled, errorMsg = ok, result end
    end

    if handled then return handled end

    if Util:OneOf(type, Self.Event.OnCancel, Self.Event.OnDone, Self.Event.OnError) then
        return handled, errorMsg
    end

    error(errorMsg, 0)
end
