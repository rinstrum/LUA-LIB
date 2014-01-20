package.path = package.path .. ";../src/?.lua"

local dbg = require "rinLibrary.rinDebug"


local logging = require "logging"
require "logging.console"
local config = {
    logger = logging.console("%message\n"),
    level = logging.INFO,
    timestamp = true  
}
dbg.configureDebug(config)

a = 5
dbg.printVar("a is :",a)

t = {}
t.name = 'John'
t.wife = 'Sara'
t.kid1 = 'Amy'
dbg.printVar('Family:',t)
dbg.printVar('kid:',t.kid1)

local rinCSV = require "rinLibrary.rinCSV"
-------------------------------------------------------------------------------
-- Configure the results.csv file structure
rinCSV.addTable('results', 
                {['fname'] = 'results.csv',
                 ['labels'] = {'target','actual'},
                 ['data'] = {}}
                )
rinCSV.loadDB()  -- see if existing data is already saved and load into database
dbg.printVar("Table:",rinCSV.tables)
dbg.printVar("Line 2:",rinCSV.tables.results.data[2])
