require "rinApp"


local function handleWeightStream(data, err)
	data = L401.toWeight(data)
	print(data)
end
local weightStream = L401.addStream(L401.REG_GROSSNET, handleWeightStream, 'change')


local function twiddle()
       L401.rotWAIT(1) 
end
local twiddler = system.timers.addTimer(250,100,twiddle)


lastClick = false
local function click()
  if lastClick then
    L401.turnOn(11)
  else 
    L401.turnOff(11)
  end
 lastClick = not lastClick  
end
local clicker = system.timers.addTimer(500,50,click)



local function F1Pressed(key, state)
	if state == 'short' then
        print ('F1 pressed')
		L401.buzz(3)
		print (dialog.readRegWait(L401.REG_SERIALNO))
        if dialog.RTC.first == 'day' then
		      dialog.RTCdateFormat('month','day','year')
		else 	  
              dialog.RTCdateFormat('day','month','year')
		end	  
	end	
	return true
end
L401.setKeyCallback(L401.KEY_F1, F1Pressed)

local function statusChanged(stat, change)
   local s = ''
   if change then s = 'Active' else s = 'Inactive' end
   print (stat, s)
end
L401.setStatusCallback(L401.STAT_MOTION, statusChanged)
L401.setStatusCallback(L401.STAT_NET, statusChanged)
L401.setStatusCallback(L401.STAT_GROSS, statusChanged)



finished = false
local function F2Pressed(key, state)
	if state == 'short' then
      finished = true
	end	
	return true
end
L401.setKeyCallback(L401.KEY_F2, F2Pressed)

local function F3Pressed(key, state)
	if state == 'short' then
      print(dialog.reqCustomTransmit([[\BF \C0 \D8]]))
	end	
	return true
end
L401.setKeyCallback(L401.KEY_F3, F3Pressed)


local function primary(key, state)
  if key == L401.KEY_ZERO then
     print(key, "block Zero key")
	 return true
  end
  print (key, "ok")
  return false  
end
L401.setKeyGroupCallback(L401.keyGroup.primary, primary)

local function RTCHandler(stat, change)
   dialog.RTCtick()
   print(dialog.RTCtostring())
end
dialog.RTCread();
L401.setStatusCallback(L401.STAT_RTC, RTCHandler)


L401.writeBotLeft("HELLO")
L401.writeBotRight("THERE")
L401.enableOutput(11)
dialog.delay(500)
print(dialog.readRegWait(L401.REG_SOFTMODEL))

while not finished do
   system.handleEvents()
end  
L401.turnOff(11)

cleanup()


