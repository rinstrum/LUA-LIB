require "rinApp"

local msg = ''
local cnt = -1
function slide()
   if cnt == -1 then return end
   
   if cnt == 0 then
      L401.writeBotLeft('')
   else   
      L401.writeBotLeft(string.format('%-9s',string.upper(string.sub(msg,1,9))))
      msg = string.sub(msg,2)
   end 
   	cnt = cnt-1
end

local slider = system.timers.addTimer(200,100,slide)


function showMarquee (s)
   msg = '        ' ..  s
   cnt = #msg
end

showMarquee("This is a very long message for a small LCD screen")
while true do
    local key = dialog.getKey() 
    showMarquee(string.format("%s Pressed ", key))
	if key == L401.KEY_CANCEL then break end
	end  
system.timers.removeTimer(slider)
cleanup()
