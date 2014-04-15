local p10 = require "rinLibrary.powersOfTen"

-- Load some mysterious values up
local a = p10[111]
a = p10[39]
a = p10[128]
a = p10[-122]
for i=12, -40, -1 do
    a = p10[i]
end

-- Compare these values against what they sohuld be
for k,v in pairs(p10) do
    local s = string.format("%.0e", v)
    local r = tostring(math.abs(k))
    if math.abs(k) < 10 then
        r = "0" .. r
    end
    if k < 0 then
        r = "-" .. r
    else
        r = "+" .. r
    end
    r = "1e" .. r
    if r ~= s then
        print("test failed: " .. s .. " is not the expected " .. r)
    end
end
