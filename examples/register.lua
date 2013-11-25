-- Include the src directory
package.path = package.path .. ";../src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"

local dwi = rinApp.addK400("K401")


local reg = 0
for i = 0,0x0200 do
   
   data, err = dwi.sendRegWait(dwi.CMD_RDLIT,reg)
   if not err then
      print(string.format('%8X:',reg),data)
    end
    reg = reg + 1    

end

rinApp.cleanup()

