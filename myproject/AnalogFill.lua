-------------------------------------------------------------------------------
-- Analogue Fill Application
-- 
-- based on myApp Application template
--    
-- Monitors the status of the K412 batching and outputs an analogue voltage
-- based on fill speed.
-- Operator can set the voltage for each speed setting and 
-- store this for each product recipe 
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"
local rinApp = require "rinApp"
local csv = require "rinLibrary.rinCSV" 

local dwi = rinApp.addK400("K412")  -- replace this with the instrument application name if other than K401

levels = csv.loadCSV({['fname'] = 'speed.csv',
                   ['labels'] = {'Product No','Fast','Medium','Slow'},
                   ['data'] = {{'default',9.0,6.0,2.0}}})

local curRow = 1
local speeds = levels.data[curRow]
local FAST_COL = csv.labelCol(levels,'fast')
local MED_COL = csv.labelCol(levels,'medium')
local SLOW_COL = csv.labelCol(levels,'slow')



-------------------------------------------------------------------------------
-- Stream setup to monitor changes to current weight and print to console
-------------------------------------------------------------------------------
local function handleProductStream(data, err)
-- insert code here to handle changes in weight
   activeProduct = tonumber(data)
   rinApp.dbg.info('Active Product = ',activeProduct)

-- look up the speed settings for this product   
   local row, line = csv.getLineCSV(levels,activeProduct)
   if row then
      curRow = row
	  speeds = line
   end	  
	   
end
dwi.addStream(dwi.REG_ACTIVE_PRODUCT_NO, handleProductStream, 'change')
-- keeps track of which product is active so we can load the correct speed settings





local SPEED_NONE = 0
local SPEED_SLOW = 1
local SPEED_MED = 2
local SPEED_FAST = 3
local speed = SPEED_NONE

local NOT_RUNNING = 0
local RUNNING = 1
local batchRun = NOT_RUNNING

-------------------------------------------------------------------------------
-- Do the actual analogue voltage setting
local function setAnalogVolts (volts)
   if volts ~= lastVolts then
      dwi.setAnalogVolt(volts)
      lastVolts = volts
      rinApp.dbg.info("volts", volts)
   end
end

-------------------------------------------------------------------------------
-- Callback to capture changes to batch info status
local function statusChanged(status, active)
  local analogueVolts = OFF_VOLTS
  -- keep local variables up to date
  if (active == true) then
    if status == dwi.STAT_RUN then
      batchRun = RUNNING
    elseif status == dwi.STAT_FAST then
      speed = SPEED_FAST
    elseif status == dwi.STAT_MED then
      speed = SPEED_MED
    elseif status == dwi.STAT_SLOW then
      speed = SPEED_SLOW
    else
      speed = SPEED_NONE
    end
  else
    if status == dwi.STAT_RUN then
      batchRun = NOT_RUNNING
    end
  end
   
  -- set required voltage if the batch is running
  if (batchRun == RUNNING) then
    if speed == SPEED_FAST then
      analogueVolts = speeds[FAST_COL]
    end
    if speed == SPEED_MED then
      analogueVolts = speeds[MED_COL]
    end
    if speed == SPEED_SLOW then
      analogueVolts = speeds[SLOW_COL]
    end
  end
  -- OFF_VOLTS for all other states
  setAnalogVolts (analogueVolts)
end
dwi.setStatusCallback(dwi.STAT_FAST, statusChanged)
dwi.setStatusCallback(dwi.STAT_MED, statusChanged)
dwi.setStatusCallback(dwi.STAT_SLOW, statusChanged)
dwi.setStatusCallback(dwi.STAT_TIME, statusChanged)
dwi.setStatusCallback(dwi.STAT_INPUT, statusChanged)
dwi.setStatusCallback(dwi.STAT_NO_INFO, statusChanged)
dwi.setStatusCallback(dwi.STAT_RUN, statusChanged)
-- statusChanged() called whenever batch info status
-- changes on the instrument




 
function editSpeed()
    
	if activeProduct then
	   local row, line = csv.getLineCSV(levels,activeProduct)
	   if row == nil then
	      speeds = csv.dupLineCSV(speeds)
		  speeds[1] = activeProduct
		  curRow = csv.addLineCSV(levels,speeds)
		  csv.saveCSV(levels)
	   else
	      curRow = row
		  speeds = line
	   end
	end
	
    sel = csv.labelCol(levels,dwi.selectOption('LEVEL',{'SLOW','MEDIUM','FAST'},'SLOW',true))
	if sel then
	   newLevel = dwi.edit('VOLTAGE',speeds[sel],'number')
	   if (newLevel < 10.0) and (newLevel > 0.0) then
	      speeds[sel] = newLevel
		  csv.replaceLineCSV(levels,curRow,speeds)	  
		  csv.saveCSV(levels)
		  end
	end   
end





-------------------------------------------------------------------------------
-- Key Handler for F1 
-------------------------------------------------------------------------------
local function F1Pressed(key, state)
    
    editSpeed() 
    return false    -- send F1 down to instrument to complete the task
end
dwi.setKeyCallback(dwi.KEY_F1, F1Pressed)


-------------------------------------------------------------------------------
-- Handler to capture PWR+ABORT key and end program
-------------------------------------------------------------------------------
local function pwrCancelPressed(key, state)
    if state == 'long' then
      rinApp.running = false
      return true
    end 
    return false
end
dwi.setKeyCallback(dwi.KEY_PWR_CANCEL, pwrCancelPressed)


-------------------------------------------------------------------------------
-- Initialisation 
-------------------------------------------------------------------------------
--  This is a good place to put your initialisation code 
-- (eg, setup outputs or put a message on the LCD etc)

dwi.setAnalogSource(dwi.ANALOG_COMMS)
dwi.setAnalogType(dwi.VOLT)




-------------------------------------------------------------------------------
-- Main Application Loop
-------------------------------------------------------------------------------
while rinApp.running do
    rinApp.system.handleEvents()           -- handleEvents runs the event handlers 
end  

-------------------------------------------------------------------------------
-- cleanup and exit
-------------------------------------------------------------------------------

rinApp.cleanup()                   -- shutdown application resources


