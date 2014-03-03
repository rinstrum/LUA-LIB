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
-- This first one displays six messages (two are blank) on a repreating cycle
-- with a half second pause between each
dwi.cycleBotRight({"hello", "world", "", "goodbye", "world", ""}, 0.5, true)

-- This one displays a mixture of small numbers and some text.  Again, it is
-- a repeating cycle and runs at a significantly slow frame rate.
dwi.cycleTopRight({ 1 , 2, 3, 4, 666, 5, "wake", 6, 7, 666, 8, 9, 0, 12, "joy" }, 3.1, true)

-- This one displays the alphabet forwards and backwards on a once second repeating cycle.
dwi.cycleBotLeft({"ABC DEF", "HIJ KLMN", "OPQSRT", "UVW XYZ",
				"zyx wvu", "trsqpo", "nmlk jih", "fed cba"}, 1, true)

-- Another selection of fairly random text on a .8 second update interval.  Again repeating.
-- Has two blanks at the end as a short pause.
dwi.cycleTopLeft({"THE", "END", "IS", "NIGH", "BEWARE", "", ""}, .8, true)


-- Main Application Loop
rinApp.run()

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()
