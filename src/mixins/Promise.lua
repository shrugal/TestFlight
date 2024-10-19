---@class Addon
local Addon = select(2, ...)
local Async, Util = Addon.Async, Addon.Util

---@class Promise
---@field statusResult table
---@field callbacks table<Promise.Status, function[]>
local Self = { __promise__ = true }

---@param runner? fun(resolve: function, reject: function, cancel: function): any
---@param level? number
---@param parent? Promise
function Addon:CreatePromise(runner, level, parent)
    local promise = CreateAndInitFromMixin(Self, runner, (level or 1) + 2, parent)
    Async:Enqueue(promise)
    return promise
end

Self.DEBUG_LOCALS = false

---@enum Promise.Status
Self.Status = {
    Created = "created",
    Started = "started",
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

---@param runner? fun(resolve: function, reject: function, cancel: function): any
---@param level? number
---@param parent? Promise
function Self:Init(runner, level, parent)
    self.parent = parent

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

    self.debugInfo = ("In promise from:\n%s---"):format(self:GetDebugInfo((level or 1) + 1))
end

---------------------------------------
--                API
---------------------------------------

---@param onWait? function
---@vararg any
function Self:Wait(onWait, ...)
    if self.status == Self.Status.Created then
        if self.parent then self.parent:Wait() end
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
    return self:Chain(onDone, onError, nil, ...)
end

---@param onDone function
---@vararg any
function Self:Done(onDone, ...)
    return self:Chain(onDone, nil, ...)
end

---@param onError function
---@vararg any
function Self:Error(onError, ...)
    return self:Chain(nil, onError, ...)
end

function Self:Cancel()
    if self:IsFinalized() then return end

    self:Finalize(Self.Status.Canceled)
end

---@vararg any
function Self:Resolve(...)
    if self:IsFinalized() then return end

    local handled, errorMsg = self:Finalize(Self.Status.Done, ...)

    if handled == false then ---@cast errorMsg string
        self:HandleError(errorMsg)
    end
end

---@vararg any
function Self:Reject(...)
    if self:IsFinalized() then return end

    local handled, errorMsg = self:Finalize(Self.Status.Error, ...)
    if handled then return end ---@cast errorMsg string

    if handled == false then ---@cast errorMsg string
        self:HandleError(("%s\nCaused by: %s"):format(errorMsg, (... or "?")))
    else
        self:HandleError(("Unhandled promise error: %s"):format(... or "?"))
    end
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

---@param onDone? function
---@param onError? function
---@vararg any
function Self:Chain(onDone, onError, ...)
    if self:IsCanceled() then return self end
    if not onDone and not onError then return self end

    local promise = Addon:CreatePromise(nil, 3, self)
    local resolve, reject, cancel = promise.resolve, promise.reject, promise.cancel
    local n = select("#", ...)

    local handleError = function (e)
        promise.debugInfo = promise:GetDebugInfo(2) .. promise.debugInfo
        return e
    end

    if onDone then
        if n > 0 then onDone = Util:FnBind(onDone, ...) end
        resolve = Util:FnCapture(onDone, resolve, reject, handleError)
    end
    if onError then
        if n > 0 then onError = Util:FnBind(onError, ...) end
        reject = Util:FnCapture(onError, resolve, reject, handleError)
    end

    if self.status == Self.Status.Done then
        resolve(unpack(self.statusResult))
    elseif self.status == Self.Status.Error then
        reject(unpack(self.statusResult))
    else
        self:RegisterCallback(Self.Event.OnDone, resolve)
        self:RegisterCallback(Self.Event.OnError, reject)
        self:RegisterCallback(Self.Event.OnCancel, cancel)
    end

    return promise
end

function Self:Resume()
    if self.status == Self.Status.Created then
        self.status = Self.Status.Started
    end
    if self.runner then
        if not self.coroutine then
            self.coroutine = coroutine.create(self.runner)
        end
        if coroutine.status(self.coroutine) == "suspended" then
            self.status = Self.Status.Running
            self:Handle(coroutine.resume(self.coroutine))
        end
    end
    return self
end

---@param success boolean
---@vararg any
function Self:Handle(success, ...)
    if self.status == Self.Status.Running then
        local state = coroutine.status(self.coroutine)
        if not success then
            self.debugInfo = self:GetDebugInfo(self.coroutine) .. self.debugInfo
            self:Reject(...)
        elseif state == "dead" and select("#", ...) > 0 then
            self:Resolve(...)
        else
            self.status = Self.Status.Suspended
            Util:TblFill(self.statusResult, ...)

            self:TriggerCallbacks(Self.Event.OnProgress, ...)
        end
    elseif not success then
        self:HandleError(... or "?")
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

    return handled, errorMsg
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

    ---@type boolean, string
    local handled, errorMsg = true, nil

    for _,handler in ipairs(callbacks) do
        local ok, result = pcall(handler, ...)
        if not ok and handled then handled, errorMsg = false, result end
    end

    if handled then return handled end

    if Util:OneOf(type, Self.Event.OnCancel, Self.Event.OnDone, Self.Event.OnError) then
        return handled, errorMsg
    end

    self:HandleError(errorMsg)
end

---------------------------------------
--             Errors
---------------------------------------

---@param levelOrCoroutine? number | thread
function Self:GetDebugInfo(levelOrCoroutine)
    if type(levelOrCoroutine) == "number" then levelOrCoroutine = levelOrCoroutine + 1 end

    local info = debugstack(levelOrCoroutine)

    if Self.DEBUG_LOCALS and not InCombatLockdown() then
        local locals = type(levelOrCoroutine) ~= "thread" and debuglocals(levelOrCoroutine or 1) or nil
        if not Util:StrIsEmpty(locals) then info = info .. "\nLocals:" .. locals end
    end

    return info
end

---@param e string
---@param levelOrCoroutine? number | thread
function Self:HandleError(e, levelOrCoroutine)
    if type(levelOrCoroutine) == "number" then levelOrCoroutine = levelOrCoroutine + 1 end

    if levelOrCoroutine then e = e .. self:GetDebugInfo(levelOrCoroutine) end

    error(e .. "\n" .. self.debugInfo, 0)
end