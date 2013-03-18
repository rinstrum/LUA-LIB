-------------------------------------------------------------------------------
-- Offer functions for creating a multi-table database stored and recalled in .CSV format
-- @module rinCSV
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

 _M.tables = {}     -- holds multiple database tables
 
 
 -------------------------------------------------------------------------------
-- Adds '"' around s if it contains ',' or '"' and replaces '"' with '""'
-- @param s string to escape
-- @return escaped string
 
 function _M.escapeCSV(s)  
 -- if s has any commas or '"' in it put "   " around string and replace any '"' with '""' 
 
    if string.find(s, '[,"]') then
        s = '"' .. string.gsub(s,'"','""') .. '"'
    end
    return s    
 end
 
-------------------------------------------------------------------------------
-- Converts a table (1d array) to a CSV string with fields escaped if required
-- @param t table to convert 
-- @return escaped CSV string
 
 function _M.toCSV(t)
 
   local s = '';
    for _,p in pairs(t) do
       s = s .. ',' ..  _M.escapeCSV(p)
    end
    return string.sub(s,2)
end      

-------------------------------------------------------------------------------
-- Takes an escaped CSV string and table (1d array)
-- @param s CSV string
-- @return table (1d array)
 
function _M.fromCSV(s)
  s = s .. ','
  local t = {}
  
    
  local fieldstart = 1
  repeat
     if string.find(s, '^"', fieldstart) then
        local a, c
        local i = fieldstart
        repeat
          a,i,c = string.find(s, '"("?)', i+1)
        until c ~= '"'
        if not i then error ('Unmatched quote') end  
       
        local f = string.sub(s,fieldstart+1,i-1)
        table.insert(t, (string.gsub(f,'""','"')))
        fieldstart = string.find(s,',',i)+1
     else
        local nexti = string.find(s, ',', fieldstart)
        table.insert(t, string.sub(s,fieldstart, nexti-1))
        fieldstart = nexti +1
     end
  until fieldstart > string.len(s)
  
  return (t)          
  
end  
         
         
 -------------------------------------------------------------------------------
-- Adds a table to the database
-- @param t table to add
-- table is in the format 
-- fname name of .csv file associated with table - used to save/restore table contents
-- labels{}  1d array of column labels
-- data{{}}  2d array of data
 function _M.addTable(t)
    created = false
    for k,v in pairs(_M.tables) do
      if v.fname == t.fname then
         _M.tables[k] = t             -- update existing database table with the new data.
         created = true
      end   
     end 
     
    if not created then _M.tables[#_M.tables+1] = t end    -- add database table to database
  end
 

-------------------------------------------------------------------------------
-- restores database contents from file
-- only loads in tables already added to database
  
 function _M.loadDB()
 
  ok = true;
  for k,t in pairs(_M.tables) do
    local f = io.open(t.fname,"r")
    if f == nil then 
       print ([['Can't find ]] .. t.fname)
       ok = false
    else 
      local s = f:read("*l")
      if s == nil then 
         print('empty')
         ok = false 
         f:close()
      else
         t.labels = _M.fromCSV(s)
         local line = 1;
         for s in f:lines() do
           t.data[line] = _M.fromCSV(s)
           line = line + 1
         end
      end   
    
      f:close()
      end
   end   
  return ok
end     
    
-------------------------------------------------------------------------------
-- Save database to CSV files
function _M.saveDB()

  for _,t in pairs(_M.tables) do
      local f = io.open(t.fname,"w+")
      f:write(_M.toCSV(t.labels) .. '\n')
      for _,row in ipairs(t.data) do
         f:write(_M.toCSV(row) .. '\n')
      end   
      f:close()
     end

end

-------------------------------------------------------------------------------
-- Prints contents of the database

function _M.printDB()
 
  for _,t in pairs(_M.tables) do
     print ('-------------------------------------------------------------------------------------') 
     print(_M.toCSV(t.labels))
     for _,row in ipairs(t.data) do
         print(_M.toCSV(row))
      end   
   end
   

end


return _M