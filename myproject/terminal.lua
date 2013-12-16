function VT100Home()
  return('\27[H')
end

function VT100XY(x,y)
  local x = x or 0
  local y = y or 0
  return(string.format('\27[%d;%df',y,x))
end

function VT100Up(r)
  local r = r or 0
  return(string.format('\27[%dA',r))
end

function VT100Down(l)
  local r = r or 0
  return(string.format('\27[%dB',r))
end

function VT100Left(c)
  local c = c or 0
  return(string.format('\27[%dD',c))
end

function VT100Right(c)
  local c = c or 0
  return(string.format('\27[%dC',c))
end

function VT100Save()
  return('\27[s')
end

function VT100Restore()
  return('\27[u')
end
  
function VT100ClrScreen()
 return('\27[2J')
end 

function VT100ClrEol()
 return('\27[K')
end
 
function VT100ClrSol()
  return ('\27[1K')
end  

function VT100ClrRow()
  return ('\27[2K')
end  

function VT100ClrAbove()
  return ('\27[1J')
end  

function VT100ClrBelow()
  return ('\27[J')
end  
 
function VT100ClrAttr() 
   return('\27[0m')
end 

function VT100ScrollAll() 
   return('\27[r')
end 

function VT100ScrollSet(r1,r2) 
   return(string.format('\27[%d;%dr',r1,r2))
end 




BGBlack = '40'
BGRed = '41'
BGGreen = '42'
BGYellow = '43'
BGBlue = '44'
BGMagenta = '45'
BGCyan = '46'
BGWhite = '47'

FGWhite = '37'
FGRed = '31'
FGGreen= '32'
FGYellow = '33'
FGBlue = '34'
FGMagenta = '35'
FGCyan = '36'
FGWhite = '37'

function VT100SetAttr(fg,bg) 
   local fg = fg or FGWhite
   local bg = bg or BGBlack
   
   return '\27['..fg..';'..bg..'m'
end 

  
function VT100Set(s)
  io.write(s)
end
  
  
VT100Set(VT100ClrAttr()..VT100ClrScreen()) 
local data = 100 
while data < 1000 do
  VT100Set(VT100Home() .. VT100SetAttr(FGRed,BGBlack))  
  print('This is a test')
   for i = 1,10 do
      data = data + 1 
    
      if i < 5 then  
          VT100Set(VT100SetAttr(FGBlack, BGRed))
      else
          VT100Set(VT100SetAttr(FGGreen, BGWhite))
      end 
      print(string.format('Line %d',data),VT100ClrEol())
      
   end       
end  

VT100Set(VT100ClrAttr())
VT100Set(VT100ScrollSet(5,10))
VT100Set(VT100XY(1,5))
for i = 1,50 do 
   print(string.format('scrolling %d',data))
   data = data + 1
end
   
VT100Set(VT100ClrAttr()..VT100ClrScreen()..VT100ScrollAll())

  