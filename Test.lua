---@param weight number
---@param p1 number
---@param p2 number
---@param p3 number
local function GetAllocation(weight, p1, p2, p3)
    local q = 100
    local q2, q3 = 0, 0

    if p3 < p1 and p3 < p2 then return 0, 0, q end

    q3 = math.max(0, weight - q)

    if p2 < p1 and p2 < p3 then return 0, q - q3, q3 end

    local w, r = weight - 2 * q3, weight % 2
    if 2 * p2 <= p1 + p3 then
        q2 = q2 + w
    else
        q2, q3 = r, q3 + (w - r) / 2
    end

    return q - q2 - q3, q2, q3
end

local function AssertAllocation(weight, p1, p2, p3, q1, q2, q3)
    local r1, r2, r3 = GetAllocation(weight, p1, p2, p3)
    assert(r1 == q1 and r2 == q2 and r3 == q3, ("Weight: %d | Prices: %d %d %d | Expected: %d, %d, %d | Found: %d %d %d"):format(weight, p1, p2, p3, q1, q2, q3, r1, r2, r3))
end

-- R2 cheapest
AssertAllocation(  0, 2, 1, 4,   0, 100,   0)
AssertAllocation( 50, 2, 1, 4,   0, 100,   0)
AssertAllocation(100, 2, 1, 4,   0, 100,   0)
AssertAllocation(150, 2, 1, 4,   0,  50,  50)
AssertAllocation(200, 2, 1, 4,   0,   0, 100)
-- R3 cheapest
AssertAllocation(  0, 4, 2, 1,   0,   0, 100)
AssertAllocation( 50, 4, 2, 1,   0,   0, 100)
AssertAllocation(100, 4, 2, 1,   0,   0, 100)
AssertAllocation(150, 4, 2, 1,   0,   0, 100)
AssertAllocation(200, 4, 2, 1,   0,   0, 100)
-- R1 cheapest, 2 * R2 < R1 + R3
AssertAllocation(  0, 1, 2, 4, 100,   0,   0)
AssertAllocation( 50, 1, 2, 4,  50,  50,   0)
AssertAllocation(100, 1, 2, 4,   0, 100,   0)
AssertAllocation(150, 1, 2, 4,   0,  50,  50)
AssertAllocation(200, 1, 2, 4,   0,   0, 100)
-- R1 cheapest, 2 * R2 > R1 + R3
AssertAllocation(  0, 1, 3, 4, 100,   0,   0)
AssertAllocation( 50, 1, 3, 4,  75,   0,  25)
AssertAllocation(100, 1, 3, 4,  50,   0,  50)
AssertAllocation(150, 1, 3, 4,  25,   0,  75)
AssertAllocation(200, 1, 3, 4,   0,   0, 100)

print("All good!")