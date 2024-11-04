---@class Addon
local Addon = select(2, ...)
local Util = Addon.Util

-- STATIC

---@class Promise.Static
local Static = Addon.Promise

---@type Promise
Static.Mixin = {}

-- Add stacktrace to error messages
Static.DEBUG_STACK = true
-- Add locals to error messages
Static.DEBUG_LOCALS = false
-- Max. percentage of frametime used
Static.MAX_FRAMETIME_PERCENT = 0.5
-- Max. absolute frametime used
Static.MAX_FRAMETIME_MS = 100
-- Max. runtime per promise resume (scaled by priority)
Static.MAX_RUNTIME_MS = 2

---@enum Promise.Status
Static.Status = {
    Created = "created",
    Started = "started",
    Running = "running",
    Suspended = "suspended",
    Canceled = "canceled",
    Done = "done",
    Error = "error",
}

---@enum Promise.Event
Static.Event = {
    OnProgress = "progress",
    OnCancel = Static.Status.Canceled,
    OnDone = Static.Status.Done,
    OnError = Static.Status.Error,
    OnFinally = "finally"
}

-- Start time of current frame
Static.start = debugprofilestop()
-- Queue of pending promises
---@type Promise[]
Static.queue = {}
-- Currently runnning promises
---@type Promise[]
Static.stack = {}

---------------------------------------
--                API
---------------------------------------

-- Check if parameter is a promise object
function Static:IsPromise(obj)
    return type(obj) == "table" and obj.__promise__ == true
end

-- Get the currenly running promise
function Static:GetCurrent()
    return Static.stack[#Static.stack]
end

--- Publish progress updates during a running promise
---@vararg any
function Static:Progress(...)
    local current = self:GetCurrent()
    if not current then return end

    Util:TblFill(current.statusResult, ...)

    current:TriggerCallbacks(Static.Event.OnProgress, ...)
end

-- Yield if currently in a coroutine, do nothing if not
---@vararg any
function Static:Yield(...)
    if not coroutine.running() then return end
    return coroutine.yield(...)
end

-- Yield if currently in a promise and some time has passed since resuming it
---@param label? string
function Static:YieldTime(label)
    local current = self:GetCurrent()
    if not current then return end

    local time = (debugprofilestop() - current.start) / current.priority
    if time < Static.MAX_RUNTIME_MS then return end

    if time > Static.MAX_RUNTIME_MS * 2 then
        Addon:Debug(time * current.priority, label or "YieldTime")
    end

    self:Yield()
end

-- Yield if currently in a promise that has not suspended before
---@vararg any
function Static:YieldFirst(...)
    local current = self:GetCurrent()
    if not current or current.hasSuspended then return end
    self:Yield(...)
end

-- Yield if currently in a promise that has suspended before
---@vararg any
function Static:YieldAgain(...)
    local current = self:GetCurrent()
    if not current or not current.hasSuspended then return end
    self:Yield(...)
end

-- Resolves when n promises resolve, rejects if #promises - n reject or cancel
---@param promises Promise[]
---@param n number Number of promises to resolve
---@param level? number Debug info stack level (default: 1)
---@return Promise promise resolves with a table of promise results
function Static:Some(promises, n, level)
    return self:Create(function (resolve, reject)
        local done, failed, results = 0, #promises, {}
        local function onDone(i, result)
            results[i] = result
            done = done + 1
            if done == n then resolve(results) return true end
        end
        local function onFail()
            failed = failed - 1
            if failed < n then reject() return true end
        end

        for i,promise in pairs(promises) do
            if promise.status == Static.Status.Done then
                if onDone(i, promise.statusResult) then break end
            elseif promise:IsFinalized() then
                if onFail() then break end
            else
                promise:RegisterCallback(Static.Event.OnDone, function (...) onDone(i, {...}) end)
                promise:RegisterCallback(Static.Event.OnError, onFail)
                promise:RegisterCallback(Static.Event.OnCancel, onFail)
            end
        end
    end, (level or 1) + 1)
end

-- Resolves when all promises resolve, rejects if any reject or cancel
---@param promises Promise[]
---@return Promise promise resolves with a table of promise results
function Static:All(promises)
    return self:Some(promises, #promises, 2)
end

-- Resolves when any promise resolves, rejects if all reject or cancel
---@param promises Promise[]
---@return Promise promise resolves with first promise results
function Static:Any(promises)
    return self:Some(promises, 1, 2):Done(function (results)
        return unpack(select(2, next(results)))
    end)
end

-- Resolves when any promise resolves or rejects, rejects if all cancel
---@param promises Promise[]
---@return Promise promise resolves with first promise success status and results
function Static:Race(promises)
    return self:Create(function (resolve, reject)
        local n = #promises
        local function onDone(...) resolve(true, ...) end
        local function onError(...) resolve(false, ...) end
        local function onCancel()
            n = n - 1
            if n == 0 then reject() return true end
        end

        for _,promise in pairs(promises) do
            if promise.status == Static.Status.Canceled then
                if onCancel() then break end
            elseif promise:IsFinalized() then
                resolve(promise.status == Static.Status.Done, unpack(promise.statusResult)) break
            else
                promise:RegisterCallback(Static.Event.OnDone, onDone)
                promise:RegisterCallback(Static.Event.OnError, onError)
                promise:RegisterCallback(Static.Event.OnCancel, onCancel)
            end
        end
    end, 2)
end

---------------------------------------
--             Execution
---------------------------------------

-- Queue promise for execution on the next frame
---@param promise Promise
function Static:Enqueue(promise)
    tinsert(self.queue, promise)
end

local function GetTargetFramerate()
    return Util:GetCVarBool("useTargetFPS") and Util:GetCVarNum("targetFPS") or Util:GetCVarBool("useMaxFPS") and Util:GetCVarNum("maxFPS") or max(GetFramerate(), 60)
end

-- Execute promise if there is still time in the current frame
---@param promise? Promise
---@param force? boolean Ignore time, always execute
---@return true? promiseExecuted
function Static:Execute(promise, force)
    local timePerFrame = min(Static.MAX_FRAMETIME_PERCENT * 1000 / GetTargetFramerate(), Static.MAX_FRAMETIME_MS)
    local timeLeft = timePerFrame - (debugprofilestop() - self.start)

    if force or timeLeft > 0 then
        if not promise then promise = tremove(self.queue, 1) end
        if not promise then return end

        promise:Resume()
        if promise:IsPending() then
            self:Enqueue(promise)
        end

        return true
    elseif promise then
        self:Enqueue(promise)
    end
end

CreateFrame("Frame"):SetScript("OnUpdate", function ()
    Static.start = debugprofilestop()
    -- Execute at least one promise per frame
    local res = Static:Execute(nil, true)
    -- Execute as many as possible
    while res do res = Static:Execute() end
end)

-- INSTANCE

---@class Promise
local Self = Static.Mixin

Self.__promise__ = true

-- Create promise, queue for execution on the next frame
---@param runner? fun(resolve: function, reject: function, cancel: fun()): any
---@param level? number Debug info stack level (default: 1)
---@param parent? Promise
function Static:Create(runner, level, parent)
    local promise = CreateAndInitFromMixin(Self, runner, (level or 1) + 2, parent)
    Static:Enqueue(promise)
    return promise
end

-- Create promise that resolves when the function ends
---@param fn function
function Static:Async(fn)
    return Static:Create(function (res) res(fn()) end, 2)
end

---@param runner? fun(resolve: function, reject: function, cancel: fun()): any
---@param level? number Debug info stack level (default: 1)
---@param parent? Promise
function Self:Init(runner, level, parent)
    self.parent = parent
    self.priority = 1

    ---@type Promise.Status
    self.status = Static.Status.Created
    ---@type table
    self.statusResult = {}
    ---@type table<Promise.Event, function[]>
    self.callbacks = {}

    self.resolve = Util:FnBind(self.Resolve, self)
    self.reject = Util:FnBind(self.Reject, self)
    self.cancel = Util:FnBind(self.Cancel, self)

    if runner then
        self.runner = Util:FnBind(runner, self.resolve, self.reject, self.cancel)
    end

    self.startDebugInfo = ("In promise from:\n%s---"):format(self:GetDebugInfo((level or 1) + 1))
end

---------------------------------------
--                API
---------------------------------------

-- Handle resolved or rejected promise
---@param onDone? function
---@param onError? function
---@vararg any
function Self:Then(onDone, onError, ...)
    return self:Chain(onDone, onError, nil, ...)
end

-- Handle resolved promise 
---@param onDone function
---@vararg any
function Self:Done(onDone, ...)
    return self:Chain(onDone, nil, ...)
end

-- Handle rejected promise
---@param onError function
---@vararg any
function Self:Error(onError, ...)
    return self:Chain(nil, onError, ...)
end

-- Start promise immediately
---@param onWait? function Runs once if the promise is still pending, can return another callback to run when the promise is finalized
---@vararg any
function Self:Start(onWait, ...)
    if self.status == Static.Status.Created then
        if self.parent then self.parent:Start() end
        self:Resume()
    end
    if onWait and self:IsPending() then
        local onFinally = onWait(...)
        if type(onFinally) == "function" then self:Finally(onFinally) end
    end
    return self
end

-- Run callback for suspended promise
---@param onProgress function Runs once if the promise is suspended, and every time the promise suspends
---@vararg any
function Self:Progress(onProgress, ...)
    if self:IsPending() then
        self:RegisterCallback(Static.Event.OnProgress, onProgress, ...)
    end
    if self.status == Static.Status.Suspended then
        onProgress(unpack(self.statusResult))
    end
    return self
end

-- Run callback for finalized promise
---@param onFinally function
---@vararg any
function Self:Finally(onFinally, ...)
    if self:IsFinalized() then
        onFinally(...)
    else
        self:RegisterCallback(Static.Event.OnFinally, onFinally, ...)
    end
    return self
end

-- Yield current coroutine until the promise is finalized
---@vararg any
---@return boolean resolved
---@return any ... result
function Self:Await(...)
    while self:IsPending() do coroutine.yield(...) end
    return self.status == Static.Status.Done, unpack(self.statusResult)
end

function Self:Timeout(s)
    C_Timer.After(s, Util:FnBind(self.Reject, self, ("%ds timeout reached"):format(s)))
    return self
end

-- Cancel the promise
function Self:Cancel()
    if self:IsFinalized() then return end

    if self.parent and self.parent:IsPending() then
        self.parent:Cancel()
    else
        self:Finalize(Static.Status.Canceled)
    end
end

-- Resolve the promise
---@vararg any
function Self:Resolve(...)
    if self:IsFinalized() then return end

    local handled, errorMsg = self:Finalize(Static.Status.Done, ...)

    if handled == false then ---@cast errorMsg string
        self:HandleError(errorMsg)
    end
end

-- Reject the promise
---@vararg any
function Self:Reject(...)
    if self:IsFinalized() then return end

    local handled, errorMsg = self:Finalize(Static.Status.Error, ...)
    if handled then return end ---@cast errorMsg string

    if handled == nil then
        self:HandleError(("Unhandled promise error: %s"):format(... or "?"))
    elseif self.runDebugInfo then ---@cast errorMsg string
        self:HandleError(("%s\nCaused by: %s"):format(errorMsg, ... or "?"))
    else ---@cast errorMsg string
        self:HandleError(errorMsg)
    end
end

-- Check if promise has yet to be finalized
function Self:IsPending()
    return Util:OneOf(self.status, Static.Status.Created, Static.Status.Started, Static.Status.Running, Static.Status.Suspended)
end

-- Check if promise has been finalized
function Self:IsFinalized()
    return Util:OneOf(self.status, Static.Status.Canceled, Static.Status.Done, Static.Status.Error)
end

-- Check if promise has been resolved or rejected
function Self:IsSettled()
    return Util:OneOf(self.status, Static.Status.Done, Static.Status.Error)
end

-- Check if promise has been canceled
function Self:IsCanceled()
    return self.status == Static.Status.Canceled
end

-- Set execution priority
---@param priority number Higher priority means the promise will run longer until suspending
function Self:SetPriority(priority)
    self.priority = priority
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

    local promise = Static:Create(nil, 3, self)
    local resolve, reject, cancel = promise.resolve, promise.reject, promise.cancel
    local n = select("#", ...)

    local handleError = function (e)
        promise.runDebugInfo = promise:GetDebugInfo(2)
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

    if self.status == Static.Status.Done then
        promise.runner = function () resolve(unpack(self.statusResult)) end
    elseif self.status == Static.Status.Error then
        promise.runner = function () reject(unpack(self.statusResult)) end
    else
        self:RegisterCallback(Static.Event.OnDone, resolve)
        self:RegisterCallback(Static.Event.OnError, reject)
        self:RegisterCallback(Static.Event.OnCancel, cancel)
    end

    return promise
end

function Self:Resume()
    if self:IsCanceled() then return self end
    if self.status == Static.Status.Created then
        self.status = Static.Status.Started
    end
    if self.runner then
        if not self.coroutine then
            self.coroutine = coroutine.create(self.runner)
        end
        if coroutine.status(self.coroutine) == "suspended" then
            tinsert(Static.stack, self)

            self.start = debugprofilestop()
            self.status = Static.Status.Running

            self:Handle(coroutine.resume(self.coroutine))
        end
    end
    return self
end

---@param success boolean
---@vararg any
function Self:Handle(success, ...)
    tremove(Static.stack)

    if self.status == Static.Status.Running then
        local state = coroutine.status(self.coroutine)

        if not success then
            self.runDebugInfo = self:GetDebugInfo(self.coroutine)
            self:Reject(...)
        elseif state == "dead" and select("#", ...) > 0 then
            self:Resolve(...)
        else
            self.hasSuspended = true

            self.status = Static.Status.Suspended
            Util:TblFill(self.statusResult, ...)

            self:TriggerCallbacks(Static.Event.OnProgress, ...)
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

    self:TriggerCallbacks(Static.Event.OnFinally)
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

    if Util:OneOf(type, Static.Event.OnCancel, Static.Event.OnDone, Static.Event.OnError) then
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

    local info = ""

    -- Stacktrace without internal stacks
    if Static.DEBUG_STACK then
        local skip = false
        for line in debugstack(levelOrCoroutine):gmatch("[^\n]+\n") do
            if line:match("Promise%.lua") then
                if not skip then info = info .. "[string \"Promise\"]: hidden\n" end
                skip = true
            elseif not skip or not (line:match("in function `x?pcall") or line:match("=%(tail call%)")) then
                skip, info = false, info .. line
            end
        end
    else
        info = "\n"
    end

    if Static.DEBUG_LOCALS and not InCombatLockdown() then
        local locals = type(levelOrCoroutine) ~= "thread" and debuglocals(levelOrCoroutine or 1) or nil
        if not Util:StrIsEmpty(locals) then info = info .. "\nLocals:" .. locals end
    end

    return info
end

---@param e string
function Self:HandleError(e)
    e = e .. "\n"
    if self.runDebugInfo then e = e .. self.runDebugInfo end
    error(e .. self.startDebugInfo, 0)
end