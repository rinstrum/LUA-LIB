-- Include the src directory
package.path = package.path .. ";../src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"
local csv = require "rinLibrary.rinCSV"

local dwi = rinApp.addK400("K401")



-------------------------------------------------------------------------------
-- Configure the registers.csv file structure
csv.addTable('registers', 
                {['fname'] = 'registers.csv',
                 ['labels'] = {'Address','Name','Type','Data','Literal'},
                 ['data'] = {}}
                )
csv.saveDB()  -- create csv file


dwi.removeErrHandler()
local reg_start = arg[1] or 1
local reg_end = arg[2] or reg_start
for reg = reg_start,reg_end do
   data, err = dwi.sendRegWait(dwi.CMD_RDFINALDEC,reg)
   if not err then
     lit, err = dwi.sendRegWait(dwi.CMD_RDLIT, reg)
     name, err = dwi.sendRegWait(dwi.CMD_RDNAME,reg)
     typ, err = dwi.sendRegWait(dwi.CMD_RDTYPE,reg)
     if not err and typ then
         typ = tonumber(typ,16)
         lit = lit or ''
         name = name or ''
         regstr = string.format('%4X',reg)
         csv.addLineCSV('registers',{regstr,name,dwi.typStrings[typ],data,lit}) 
         print(string.format('%4X (%s):',reg,dwi.typStrings[typ]),lit)
       end
    end   
end

csv.saveDB()
rinApp.cleanup()

