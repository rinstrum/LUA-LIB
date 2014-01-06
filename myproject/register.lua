-- Include the src directory
package.path = package.path .. ";../src/?.lua"

-- Require the rinApp module
local rinApp = require "rinApp"
local csv = require "rinLibrary.rinCSV"
local VT100 = require "rinLibrary.rinVT100"

local dwi = rinApp.addK400("K401")



-------------------------------------------------------------------------------
-- Configure the registers.csv file structure
registers = csv.saveCSV(    {['fname'] = 'registers.csv',
                 ['labels'] = {'Address','Name','Type','Data','Literal'},
                 ['data'] = {}}
                )


VT100.set(VT100.clrScreen())
VT100.set(VT100.scrollSet(3,25))
dwi.removeErrHandler()
local reg_start = tonumber(arg[1]) or 1
local reg_end = tonumber(arg[2]) or reg_start
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
         csv.logLineCSV(registers,{regstr,name,dwi.typStrings[typ],data,lit}) 
         VT100.set(VT100.csrSave().. VT100.csrXY(1,1))
		 print(string.format('%4X (%s): ',reg,dwi.typStrings[typ]),lit,VT100.clrEol(),VT100.csrRestore())
      
	  end
    end   
end

rinApp.cleanup()
csv.loadCSV(registers)
print(VT100.scrollAll()..VT100.clrScreen()..VT100.csrHome()..csv.tostringCSV(registers,15))


