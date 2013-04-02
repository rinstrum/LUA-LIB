------------------------------------------------------------------------------
-- services for saving and restoring settings in a table to .INI config file
-- @module ini
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

-------------------------------------------------------------------------------
-- Saves table t as a .INI name (fname)
-- @param fname  name of file
-- @tparam t is table of settings
-- @return t if successful, nil otherwise
function _M.saveINI(fname, t)
  f = io.open(fname, "w+")
  if f == nil then 
       print ([['Can't find ]] .. fname)
       return nil
    end
  
  for k,v in pairs(t) do    -- do global vars first
     if type(v) ~= 'table' then
        f:write(k,'=',v,'\n')
     end
   end  
  for k,v in pairs(t) do   -- now do section vars
    if type(v) == 'table' then
       f:write('[',k,']','\n')
       for i,s in pairs(v) do
         f:write(i,'=',s,'\n')
       end
    end
   end 
  f:close();  
  return t
end


-------------------------------------------------------------------------------
-- populates table t with contents of INI file fname
-- if fname is not found a new file is created with table def contents
-- @param fname name of file
-- @param def  default table of settings
-- @return table t or nil if file invalid
function _M.loadINI(fname, def)

  local lt = {}
  local t = {}
  local f = io.open(fname,"r")
    if f == nil then 
       if def == nil then  return nil end
	   return _M.saveINI(fname,def)
    end
   lt = t    -- support settings with no section header directly
   for s in f:lines() do
      local first = string.find(s,'%[')
      local last = string.find(s,'%]')
      if first ~= nil and last ~= nil then
         name = string.sub(s,first+1,last-1)
         lt = {}
         t[name] = lt
      else 
        pos = string.find(s,'=')
        if pos ~= nil and pos > 1 then
          name = string.gsub(string.sub(s,1,pos-1),' ','')
          val = string.gsub(string.sub(s,pos+1),' ','')
          lt[name] = val
        end
      end 
    end 
   
   f:close();
   
   local extra = false
   for k,v in pairs(def) do
      if t[k] == nil then  
	     t[k] = def[k]
		 extra = true
		end 
   end
   if extra then _M.saveINI(fname,t) end   -- if extra fields in default table not already in file then save
   return t
end


-------------------------------------------------------------------------------
-- prints table t contents in INI format
-- @param t is table of settings

function _M.printINI(t)

 print ('-------------------------------------------------------------------------------------') 
  
  for k,v in pairs(t) do 
    if type(v) ~= 'table' then
      print(k,'=',v)
    end
  end      
  for k,v in pairs(t) do
    if type(v) == 'table' then
       print('[',k,']')
       for i,s in pairs(v) do
          print(i,'=',s)
       end 
     end    
  end  
end


return _M