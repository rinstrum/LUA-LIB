-------------------------------------------------------------------------------
-- testCSV
-- 
-- Show capabilities of the rinCSV library
-- 
-------------------------------------------------------------------------------

-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local dbg = require "rinLibrary.rinDebug"
local csv = require "rinLibrary.rinCSV"





-------------------------------------------------------------------------------
-- Configure the registers.csv file structure
db = {}   
csv.addTableDB(db,'materials', 
                {['fname'] = 'materials.csv',
                 ['labels'] = {'Mat.No','Name','Density'},
                 ['data'] = {}}
                )
csv.addTableDB(db,'recipes', 
                {['fname'] = 'recipe.csv',
                 ['labels'] = {'Rec.No','Mat1','Target1','Mat2','Target2'},
                 ['data'] = {}}
                )
                
csv.loadDB(db)  
print(csv.tostringDB(db,10))

print(db.materials.data[1][2])


log = csv.loadCSV({['fname'] = 'test1.csv',
                   ['labels'] = {'Target','Actual','Fill Time'},
                   ['data'] = {}})
-- addLineCSV addsline ot the ram copy but does not save to disk
csv.addLineCSV(log,{1000,990,24.5})
csv.addLineCSV(log,{1200,1250,26.5})
csv.saveCSV(log)

-- logLineCSV logs to disk file and does not keep copy in Ram
csv.logLineCSV(log,{1500,1450,30.0})
csv.loadCSV(log)
print(csv.tostringCSV(log,10))







