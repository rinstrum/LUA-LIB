package.path = package.path .. ";../src/?.lua"

local dbg = require "rinLibrary.rinDebug"


a = 5
dbg.printVar("a is :",a)

dbg.configureDebug(arg[1], true)

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
