local p10 = require "rinLibrary.powersOfTen"
local n, f = 0, 0

-- Load some mysterious values up
local a = p10[111]
a = p10[39]
a = p10[128]
a = p10[-122]
for i= -40, 12 do
    a = p10[i]
end


-- Compare these values against what they sohuld be
for k,v in pairs(p10) do
    local s = tonumber(string.format("%.0e", v):sub(3), 10)
    if k ~= s then
        print("test failed: " .. s .. " is not the expected " .. k)
        f = f + 1
    end
    n = n + 1
end

print("Failed " .. f .. " tests out of " .. n)
