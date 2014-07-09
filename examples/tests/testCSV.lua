-------------------------------------------------------------------------------
-- testCSV
-- 
-- Show capabilities of the rinCSV library
-- 
-------------------------------------------------------------------------------

local csv = require "rinLibrary.rinCSV"

-- Create an empty database
local db = {}

-- Create a materials table for the database. This will be called materials.csv,
-- and will have the headings Mat.No, Name, and Density.
-- This will also populate the database with some initial data of a material 
-- called cement that has a Mat.No of 1 and a Density of 1.0.
csv.addTableDB(db,'materials', {
                ['fname'] = 'materials.csv',
                ['labels'] = {'Mat.No','Name','Density'},
                ['data'] = {{1,'CEMENT',1.0}}
            })

-- Create a recipes table for the database. This file will have 3 rows of 
-- initial data.
csv.addTableDB(db,'recipes', {
                ['fname'] = 'recipe.csv',
                ['labels'] = {'Rec.No','Mat1','Target1','Mat2','Target2'},
                ['data'] = {{1,1,1000,0,0},
                            {2,1,2000,0,0}}
            })

-- Attempt to load the database from existing files on disk. If 
csv.loadDB(db)  

print('Database Contents:')
print(csv.tostringDB(db,10))

print('Material Table Details')
print(string.format('%d Columns, %d Rows',csv.numColsCSV(db.materials),csv.numRowsCSV(db.materials)))

print('Names from Column 2')
print(csv.tostringCol(csv.getColCSV(db.materials,2)))

print("Material Data for material 'CEMENT'")
local row, line = csv.getLineCSV(db.materials,'CEMENT',2)
print(' Row : ', row)
print('Line : ',csv.tostringLine(line,10))

print('Change Density to 5')
line[3] = 5
csv.replaceLineCSV(db.materials,row,line)
print(csv.tostringCSV(db.materials,10))

print('---------------------------------------------------')
print('Logging Data to File')

local log, kind = csv.loadCSV({ ['fname'] = 'test1.csv',
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
