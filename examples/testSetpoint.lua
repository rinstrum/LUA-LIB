-------------------------------------------------------------------------------
-- testSetpoint
-- 
-- example of seting up a setpoint to fill to target, print and log results 
-- to results.csv 
-- 
-- to use this example, first configure the R420 to have 2 setpoints
-- Setp1 is an OVER setpoint with LOGIC set to LOW (ie on below target, off above)
-- Setp2 is an UNDER setpoint with LOGIC set to LOW also
-- Setp2 target should probably be set a little over zero to allow for any
-- product build up
-- leave the setp outputs set to NONE as they are controlled by the LUA application
-------------------------------------------------------------------------------
-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local rinCSV = require "rinLibrary.rinCSV"
local rinApp = require "rinApp"
local L401 = rinApp.addL401("172.17.1.95", 2222)
local system = rinApp.system
local dbg = rinApp.dbg

-------------------------------------------------------------------------------
-- Configure the results.csv file structure
rinCSV.addTable('results', 
                {['fname'] = 'results.csv',
                 ['labels'] = {'target','actual'},
				 ['data'] = {}}
                )
rinCSV.loadDB()  -- see if existing data is already saved and load into database

-------------------------------------------------------------------------------
local curGross = 0
-- Stream setup to monitor changes to current gross weight and keep a local copy 
-- in curGross
local function handleWeightStream(data, err)
	curGross = data
end
local wgt = L401.addStream(L401.REG_GROSS, handleWeightStream, 'change')

-------------------------------------------------------------------------------
-- Timer to rotate activity annunciator on LCD screen
local function twiddle()
       L401.rotWAIT(1) 
end
local twiddler = system.timers.addTimer(250,100,twiddle)


-------------------------------------------------------------------------------
-- Filling Control

local IDLE = 0
local FILL = 1
local DUMP = 2
local curState = IDLE       -- curState keeps track of state machine

local paused = false        -- flag to control pause status

-------------------------------------------------------------------------------
-- physical outputs used
local FILL_OUTPUT = 8
local DUMP_OUTPUT = 7
-------------------------------------------------------------------------------
-- setpoints used
local FILL_SETP = 1
local DUMP_SETP = 2

-------------------------------------------------------------------------------
--  local copy of the setpoint targets used by the instrument
local target = 0
local empty = 0

-------------------------------------------------------------------------------
-- timeouts
local timeout = 0   -- count down timer
local FILL_TIMEOUT = 200  -- 2 seconds
local DUMP_TIMEOUT = 100  -- 1 second

-------------------------------------------------------------------------------
-- run the filling stages
-- enable the right setpoint depending on the status of the state machine
-- typically called after weight reading has been stabilised and captured
local function startNext()
  if paused then
    return
  end
  
  if curGross >= target then
 	   curState = DUMP
	   L401.setpIO(FILL_SETP,0)          -- remove output from the fill setpoint
       L401.setpIO(DUMP_SETP,DUMP_OUTPUT) -- enable DUMP output
	   timeout = DUMP_TIMEOUT
	   dbg.printVar('CurState = DUMP')
  else
     curState = FILL
	 L401.setpIO(DUMP_SETP,0)           -- remove output from the dump setpoint
	 L401.setpIO(FILL_SETP,FILL_OUTPUT) -- enable fill output 
	 timeout = FILL_TIMEOUT
	 dbg.printVar('CurState = FILL')
  end  
 
end

-------------------------------------------------------------------------------
-- stop the filling process 
local function abort()
  -- leave setpoint enabled but remove any physical output to run
  L401.setpIO(FILL_SETP,0)   
  L401.setpIO(DUMP_SETP,0)

  -- initialise the state machine flags
  paused = false
  curState = IDLE
  timeout = 0
  
  dbg.printVar('Aborted')
end

-------------------------------------------------------------------------------
local function pause(reason)
 paused = true
 dbg.printVar('Paused: ', reason)
 
 -- remove outputs from the setpoints
 L401.setpIO(FILL_SETP, 0)
 L401.setpIO(DUMP_SETP, 0)  
end

-------------------------------------------------------------------------------
local function resume()
 paused = false
 if curState == FILL then 
    if curGross >= target then       -- if paused after filling finished then move to dump
      startNext()
    else 	  
      L401.setpIO(FILL_SETP, FILL_OUTPUT)  -- otherwise enable fill output
	end  
 elseif curState == DUMP then
   if curGross <= empty then         -- if paused after dumping finished then move to fill 
      startNext()
   else	  
      L401.setpIO(DUMP_SETP, DUMP_OUTPUT)  -- otherwise enable dump output
   end	  
 end 
end

-------------------------------------------------------------------------------
-- Timer to monitor filling state machine and abort if taking too long
local function fillTimerCallback()
    
	if paused then 
	   return
	end   
	   
	if timeout > 0 then
       timeout = timeout - 1
	   if timeout == 0 then   
	        pause('Timeout')
		end
	end	
end
-- setup a timer to run every 10 msec after an initial 100 msec delay
local fillTimer = system.timers.addTimer(100,10,fillTimerCallback)  

-------------------------------------------------------------------------------
-- Callback to capture changes to Motion,Net and Zero status  
local function statusChanged(status, active)
   if status == L401.STAT_MOTION then
      if not active then                -- if weight stable
		  if curState == FILL and curGross >= target then
	         dbg.printVar('Final = ', curGross)  -- log result to console
			 -- print date and time along with target and actual to printer 
			 -- on SER1 of the instrument
			 L401.printCustomTransmit(string.format('\\BF \\C0: Target = %s, Actual = %s\\C1',
			                                tostring(target),tostring(curGross)))
		     
			 --  Add new data to the results database table
			 rinCSV.addLineCSV('results',{target,curGross})			 
		  end	
	   if curState ~= IDLE then -- if running then move to the next stage in the process
   	       startNext() 
       end 		   
	  end	  
   elseif status == L401.STAT_NOTERROR then  -- if weighing errors detected then pause
      if not active then 
          pause('Error')
      end
   end
         
end
-- setup monitoring of motion and error status
L401.setStatusCallback(L401.STAT_MOTION, statusChanged)
L401.setStatusCallback(L401.STAT_NOTERROR, statusChanged)

-------------------------------------------------------------------------------
-- Handler to capture ABORT key and end program
local function cancelPressed(key, state)
	if state == 'long' then
      rinApp.running = false
	end	
	return true
end
L401.setKeyCallback(L401.KEY_CANCEL, cancelPressed)

-------------------------------------------------------------------------------
-- Handle all the primary keys here 
-- ZERO, TARE, GROSS?NET, F1, F2, F3
local function primary(key, state)
  if state == 'short' then
     -- ZERO is blocked if running but supported otherwise
	 if key == L401.KEY_ZERO then
        return curState ~= IDLE
     -- TARE and GROSS/NET keys blocked
  	 elseif key == L401.KEY_TARE or key == L401.KEY_GN then
	    return true
     -- F1 to start/resume the filling process
	 elseif key == L401.KEY_F1 then
           if paused then
		       resume()
			elseif curState == IDLE then
				local tmp, ok
			    -- get current target value
			    tmp = L401.readRegWait(L401.setpRegAddress(FILL_SETP,L401.REG_SETP_TARGET)) 
				-- prompt user for target and start filling if OK pressed
			    tmp, ok = L401.edit('TARGET',tmp,'number') 
				if ok then
				   L401.setpTarget(FILL_SETP,tmp)  -- save target value to setpoint 
				   -- read setpoint targets for local monitoring and logging
   		           target = L401.readRegWait(L401.setpRegAddress(FILL_SETP,L401.REG_SETP_TARGET))  
        		   empty = L401.readRegWait(L401.setpRegAddress(DUMP_SETP,L401.REG_SETP_TARGET))
				   startNext()  -- start filling process
				end
           end		   
		   return true  -- key handled in LUA
	 -- F2 to Pause
  	 elseif key == L401.KEY_F2 and not paused then
            pause('OPERATOR')
			return true
	 --F3 to abort
     elseif key == L401.KEY_F3 then
            abort()
			return true
	 end
   end	 
  return false  -- any other keys not handled here
end
L401.setKeyGroupCallback(L401.keyGroup.primary, primary)

-------------------------------------------------------------------------------
L401.writeBotLeft("FILLING")

-- Main application loop
while rinApp.running do
   system.handleEvents()
end  

-- cleanup and exit
rinApp.cleanup()
os.exit()


