-------------------------------------------------------------------------------
-- testDebug
-- 
-- Show capabilities of the rinDebug library
-- 
-------------------------------------------------------------------------------

-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local dbg = require "rinLibrary.rinDebug"


-- set rinDebug to show all messages with date/time stamping
dbg.configureDebug({level = 'DEBUG',timestamp = true, logger = 'console'},'testDebug')

dbg.print('','DEBUG level selected with timestamping')
dbg.debug('Test: ',1,2,3)
-- log debug messages at each level 
dbg.debug("Hello", '')  -- log simple message without label
dbg.info( 'String with CRLF at end: ',"Extra Information\r\n")
dbg.warn('String with SOH and EOT: ',"\01Warning\04")
dbg.error('',"\129Error\245")
dbg.fatal("EVERYTHING HAS GONE WRONG", '')

-- logging numbers, strings and boolean
num = 123456 * 45 / 201
dbg.info('num = ', num)                   -- log numeric
dbg.info('num = ', tostring(num))         -- log same as a string
dbg.info('num > 5? ', num > 5)                      -- log boolean expression evaluation
dbg.info('Num is a new variable: ', Num)  -- log a nil variable

-- logging table contents
t = {}
t['test'] = 1
t[1] = 2/5
t.fred = 'friend'
t.week = {'Sun','Mon','Tue','Wed','Thurs','Fri','Sat'}
dbg.debug('t = ', t)

-- Setup rinDebug to only show messages at  or above level specified
dbg.info("Argument 1 is ", arg[1])    -- show contents of argument 1 passed to program
dbg.setLevel(arg[1])     -- set debug level to arg[1] and see what gets logged
dbg.fatal('',"Fatal logged")
dbg.error('',"Error logged")
dbg.warn('',"Warning Logged")
dbg.info('',"Information logged")
dbg.debug('',"Debug logged")            -- May not print depending on arguement and default debug level




