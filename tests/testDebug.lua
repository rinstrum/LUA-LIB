-------------------------------------------------------------------------------
-- testDebug
-- 
-- Show capabilities of the rinDebug library
-- 
-------------------------------------------------------------------------------

local dbg = require "rinLibrary.rinDebug"



-- set rinDebug to show all messages with date/time stamping
dbg.configureDebug(dbg.DEBUG, true)
dbg.printVar('DEBUG level selected with timestamping')
-- log debug messages at each level 
dbg.printVar("Hello", '' ,dbg.DEBUG)  -- log simple message without label
dbg.printVar("Extra Information\r\n", 'String with CRLF at end: ',dbg.INFO)
dbg.printVar("\01Warning\04", 'String with SOH and EOT: ',dbg.WARN)
dbg.printVar("\129Error\245", '',dbg.ERROR)
dbg.printVar("EVERYTHING HAS GONE WRONG", '',dbg.FATAL)

-- logging numbers, strings and boolean
num = 123456 * 45 / 201
dbg.printVar('num = ', num, dbg.INFO)              		-- log numeric
dbg.printVar('num = ', tostring(num), dbg.INFO)    		-- log same as a string
dbg.printVar('num > 5? ', num > 5)       				-- log boolean expression evaluation
dbg.printVar('Num is a new variable: ', Num, dbg.INFO)  -- log a nil variable

-- logging table contents
t = {}
t['test'] = 1
t[1] = 2/5
t.fred = 'friend'
t.week = {'Sun','Mon','Tue','Wed','Thurs','Fri','Sat'}
dbg.printVar('t = ', t, dbg.DEBUG )

-- Setup rinDebug to only show Warnings without timestamps
dbg.printVar("Argument 1 is ", arg[1], dbg.INFO)  	-- show contents of argument 1 passed to program
dbg.configureDebug(arg[1], false)            		-- set debug level to arg[1] and see what gets logged, also remove timestamp
dbg.printVar("Fatal logged",		'', dbg.FATAL)
dbg.printVar("Error logged",		'', dbg.ERROR)
dbg.printVar("Information logged",	'', dbg.INFO)
dbg.printVar("Debug logged",		'', dbg.DEBUG)	-- May not print depending on arguement and default debug level




