#!/usr/local/bin/lua

-- Include the src directory
package.path = package.path .. ";/home/src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"
local system = rinApp.system


-- Add control of an dwi at the given IP and port
local dwi = rinApp.addK400("K401")



-- Write to the LCD screen.
dwi.setAutoTopLeft(0)

-- Schedule some message displays
dwi.cycleBotRight({"hello", "world", "", "goodbye", "world", ""}, 0.5, true)
dwi.cycleTopRight({ 1 , 2, 3, 4, 666, 5, "wake", 6, 7, 666, 8, 9, 0, 12, "joy" }, 3.1, true)
dwi.cycleBotLeft({"ABC DEF", "HIJ KLMN", "OPQSRT", "UVW XYZ",
				"zyx wvu", "trsqpo", "nmlk jih", "fed cba"}, 1, true)
dwi.cycleTopLeft({"THE", "END", "IS", "NIGH", "BEWARE", "", ""}, .8, true)


-- Main Application Loop
rinApp.run()

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()
