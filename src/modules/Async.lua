---@class Addon
local Addon = select(2, ...)

---@class Async
local Self = Addon.Async

Self.MAX_FRAME_TIME_PERCENT = 0.5

Self.start = debugprofilestop()
---@type Promise[]
Self.queue = {}

---@param fn function
function Self:Create(fn)
    return Addon:CreatePromise(function (res) res(fn()) end)
end

---@param obj any
function Self:IsPromise(obj)
    return type(obj) == "table" and obj.__promise__ or false
end

---@vararg any
function Self:Yield(...)
    if not coroutine.running() then return end
    return coroutine.yield(...)
end

---@param promise Promise
function Self:Enqueue(promise)
    tinsert(self.queue, promise)
end

---@param promise? Promise
---@param force? boolean
function Self:Execute(promise, force)
    local msPerFrame = 1000 / GetFramerate()
    local msTimeLeft = msPerFrame - (debugprofilestop() - self.start)

    if force or msTimeLeft >= msPerFrame * Self.MAX_FRAME_TIME_PERCENT then
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

---------------------------------------
--              Ticker
---------------------------------------

CreateFrame("Frame"):SetScript("OnUpdate", function ()
    Self.start = debugprofilestop()
    -- Execute at least one promise per frame
    local res = Self:Execute(nil, true)
    -- Execute as many as possible
    while res do res = Self:Execute() end
end)