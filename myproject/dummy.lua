
package.path = package.path .. ";../src/?.lua"


dbg = require "rinLibrary.rinDebug"


function myPrint(...)

  dbg.print('Args: ',arg)
  dbg.print('Number of Args ',arg.n)
  print(unpack(arg))

end


myPrint(1,2,'Fred',8,{1,2})
