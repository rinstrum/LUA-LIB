print('------  Application Started   -----')

bit32 = require "bit"
L401 = require "rinLibrary.L401"
system = require "rinSystem.Pack"
userio = require "IOSocket.Pack"
dialog = require "rinLibrary.rinDialog"


local ini = require "rinLibrary.rinINI"


local config = assert(ini.loadINI("config.ini",{IP = '192.168.1.2',port = 2222, debug = 'off'}))
local s = assert(require "socket".tcp())
s:connect(config.IP, config.port)
s:settimeout(0.1)

-- ini.printINI(config)

L401.connect(s,config.debug == 'on')
system.sockets.addSocket(L401.socket, L401.socketCallback) 
system.timers.addTimer(5,100,L401.timerCallback)
dialog.connect(L401, system)


L401.streamCleanup()	-- Clean up any existing streams on connect
L401.setupKeys()
L401.setupStatus()


 
	
function cleanup()
  L401.restoreLcd()
  L401.streamCleanup()
  L401.endKeys()
  dialog.delay(500)
  print('------  Application Finished ------------')
  os.exit()
end	
	