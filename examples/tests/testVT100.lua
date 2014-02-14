-- Include the src directory
package.path = "/home/src/?.lua;" .. package.path 


VT100 = require "rinLibrary.rinVT100"
  
VT100.set(VT100.clrAttr()..VT100.clrScreen()) 
local data = 100 
while data < 1000 do
  VT100.set(VT100.csrHome() .. VT100.setAttr(VT100.FGWhite,VT100.BGBlack))  
  print('Screen redraw Test')
  VT100.set(VT100.csrXY(1,5) .. VT100.setAttr(VT100.FGGreen,VT100.BGBlack))
   for i = 1,10 do
      data = data + 1 
      print(string.format('Line %d',data),VT100.clrEol())
   end       
end  

print (VT100.csrXY(1,17)..VT100.clrAttr()..'Press any key ... ')
io.read()

VT100.set(VT100.clrScreen()..VT100.csrHome())
print (' Scrolling Test ')
VT100.set(VT100.setAttr(VT100.FGWhite,VT100.BGBlue)..VT100.scrollSet(5,10))
VT100.set(VT100.csrXY(1,5))
data = 0
for i = 1,5000 do 
   print(string.format('scrolling %d',data))
   data = data + 1
end

VT100.set(VT100.clrAttr()..VT100.scrollAll()..VT100.csrXY(1,12))
print ('Press any key ... ')
io.read()   
VT100.set(VT100.clrScreen()..VT100.csrHome())

  