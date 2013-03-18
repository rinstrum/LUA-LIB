------------------------------------------------------------------------------
-- Offer functions for converting variables into strings for debugging
-- @module debug
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------



local _M = {}

-------------------------------------------------------------------------------
-- Converts table t into a string
-- @param t is a table
function _M.tableString(t)
  local s = '{'
  for k,v in pairs(t) do
     if v == nil then
	     s = s .. (string.format('%s = <nil>, ',k))
	 elseif type(v) == "table" then
	    s = s .. string.format('%s = %s, ',k,_M.tableString(v))
	 else
       	s = s .. string.format('%s = %s, ',k,_M.varString(v))
     end
  end
  if #s < 3 then
      return ('{}')
  else	  
     return string.sub(s,1,-3) .. '}'   -- take off the last 2 chars for the last member of the table
  end	 
end

-------------------------------------------------------------------------------
-- Converts arg into a string
-- @param arg is any variable
function _M.varString(arg)
  if arg == nil then
     return '<nil>'
  else
     t = type(arg)
  end

  if t == 'number' then
    return string.format("%d",arg)
  elseif t == "string" then
    return string.format('\"%s\"',string.gsub(arg,"[^\32-\126]",   -- replace any characters not between ASCII 32 and ASCII126 with [xx] 
	          function(x) 
			      return string.format("[%02X]",string.byte(x)) 
			  end))
  elseif t == "boolean" then
    if arg then return "true" else return "false" end
  elseif t == "table" then
    return _M.tableString(arg)
  elseif t == "function" then
    return "<function>"
  else
    return "<unknown>"
  end
end

-------------------------------------------------------------------------------
-- prints variable v contents to stdio with optional name tag
-- @param v is a variable whose contents are to be printed
-- @param name is the name of the variable (optional)
function _M.printVar(v,name)
    if name == nil then
      name = ''
	end
  print(name .._M.varString(v))
end

-------------------------------------------------------------------------------
-- Function to test the module
function _M.testDebug()
	local a = nil
	local b = "Hello"
	local c = 25.7
	local d = true
	local e = {var = 1, tab = {a = 1, b= 2}}
	local f = {fred = 'friend', address = nil, phone = 123456, happy = false, find = function() print("go look yourself") end}


	print (_M.varString(a))
	print (_M.varString(b))
	print (_M.varString(c))
	print (_M.varString(d))
	print (_M.varString(e))
	print (_M.varString(f))
end



return _M


