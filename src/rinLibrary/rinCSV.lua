-------------------------------------------------------------------------------
-- Offer functions for creating a multi-table database stored and recalled in .CSV format
-- @module rinLibrary.rinCSV
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local string = string
local table = table
local pairs = pairs
local io = io
local ipairs = ipairs

local dbg = require "rinLibrary.rinDebug"

 
-------------------------------------------------------------------------------
--- CSV Utilities.
-- Functions to convert data to and from .CSV format
-- @section Utilities 
 
-------------------------------------------------------------------------------
-- Adds '"' around s if it contains ',' or '"' and replaces '"' with '""'
-- @param s string to escape
-- @return escaped string
 function _M.escapeCSV(s)
  s = tostring(s)  -- string find & gsub requires a string so make sure we have one
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
-- Converts a table (1d array) to a CSV string with fields escaped if required
-- @param t table to convert 
-- @param w is width of each cell
-- @return escaped CSV string padded to w characters in each cell
 function _M.padCSV(t,w)
 
    local s = '';
    local f = '%%s'
    if w then
        f = string.format("%%%ds",w)
    end    
    for _,p in pairs(t) do
       s = s .. ',' ..  string.format(f,_M.escapeCSV(p))
    end
    
    return string.sub(s,2)
end      

-------------------------------------------------------------------------------
-- Takes an escaped CSV string and returns a line (1d array)
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
            
            if not i then 
                error ('Unmatched quote')
            end  
       
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
-- Checks labels to ensure database table is the same structure  
-- Tolerant of additional whitespace in labels and ignores case
-- @param labels 1d array of labels from a database table
-- @param check 1d array of labels to check
-- @return true if labels and check are the same, false otherwise
function _M.equalCSV(labels, check)
   if #labels ~= #check then
     return false
   end
   
    for col,s in ipairs(labels) do
       -- remove space and convert labels to all lowercase for checking 
       s = string.lower(string.gsub(s,'%s',''))  
       local chk = string.lower(string.gsub(check[col],'%s',''))
       if s ~= chk then
           return false
       end     
    end
    
    return true
        
end 

 

-------------------------------------------------------------------------------
--- CSV Functions.
-- Functions to manage CSV files directly
-- @section CSV 


-------------------------------------------------------------------------------
-- Save table t to a .CSV file
-- @param t database table to save.
-- table is in the format:
--      fname name of .csv file associated with table - used to save/restore table contents
--      labels{}  1d array of column labels
--      data{{}}  2d array of data
function _M.saveCSV(t)
      local f = io.open(t.fname,"w+")
      f:write(_M.toCSV(t.labels) .. '\n')
      for _,row in ipairs(t.data) do
         f:write(_M.toCSV(row) .. '\n')
      end
      f:close()
end



-------------------------------------------------------------------------------
-- Reads a .CSV file and returns a table with the loaded contents
-- If no CSV file found or contents different then file created with structure in t
-- @param t is table with structure of expected CSV included
-- @return table in same format:
--      fname name of .csv file associated with table - used to save/restore table contents
--      labels{}  1d array of column labels
--      data{{}}  2d array of data 
 function _M.loadCSV(t)
     
     local f = io.open(t.fname,"r")   
     if f == nil then    
          _M.saveCSV(t)     -- no file yet so create new one   
     else    
         local s = f:read("*l")   
         if s == nil then    
              f:close()   
              _M.saveCSV(t)  -- file is empty so setup to hold t   
         else   
              if _M.equalCSV(t.labels, _M.fromCSV(s)) then   -- read in existing data   
                 for s in f:lines() do   
                     table.insert(t.data,_M.fromCSV(s))   
                 end   
                 f:close()   
              else             -- different format so initialize to new table format   
                 f:close()   
                 _M.saveCSV(t)   
              end                       
         end     
     end
    return t     
  end        



-------------------------------------------------------------------------------
-- Adds line of data to a CSV file but does not update local data in table
-- @param t is table describing CSV data
-- @param l line (1d array) of data to save
function _M.logLineCSV(t,l)
      local f = io.open(t.fname,"a+")
      f:write(_M.toCSV(l) .. '\n')
      f:close()
end


-------------------------------------------------------------------------------
-- Adds line of data to a table
-- @param t is table holding CSV data
-- @param l line (1d array) of data to save
  
function _M.addLineCSV(t,l)
      table.insert(t.data,l)
end 


-------------------------------------------------------------------------------
-- Removes line of data in a table (does not save .CSV file)
-- @param t is table holding CSV data
-- @param line is row number of table data 1..n to remove.
-- removes last line if line is nil
function _M.remLineCSV(t,line)
      table.remove(t.data)  -- remove last line from the table
end
    

-------------------------------------------------------------------------------
-- Converts contents of the CSV table into a print friendly string
-- @param t table to convert
-- @param w width to pad each cell to
function _M.tostringCSV(t,w)
    local csvtab = {}
 
    table.insert(csvtab, 'File: '.. t.fname..'\r\n') 
    table.insert(csvtab, _M.padCSV(t.labels,w))
    table.insert(csvtab, '\r\n')
    for _,row in ipairs(t.data) do
         table.insert(csvtab, _M.padCSV(row,w))
         table.insert(csvtab, '\r\n')
     end   
 
    return table.concat(csvtab)
end

    
    
-------------------------------------------------------------------------------
--- Database Utilities.
-- Functions to manage multiple tables in a database
-- @section Database 


         
 -----------------------------------------------------------------------------------
-- Adds a database table to the database, updates contents with t if already present
-- @param name is the name of table
-- @param t database table to add
-- database table is in the format 
-- fname name of .csv file associated with table - used to save/restore table contents
-- labels{}  1d array of column labels
-- data{{}}  2d array of data
 function _M.addTableDB(db,name,t)
    local created = false
    for k,v in pairs(db) do
        if v.fname == t.fname then
            db[k] = t             -- update existing database table with the new data.
            created = true
        end   
    end 
     
    if not created then 
        db[name] = t 
    end    -- add database table to database
  end

 
-------------------------------------------------------------------------------
-- Restores database contents from CSV files
-- Only loads in database tables already registered with database
-- @param db database table to populate 
 function _M.loadDB(db)
    for k,t in pairs(db) do
       _M.loadCSV(t)    
    end 
end

-------------------------------------------------------------------------------
-- Adds line of data to a table in the database
-- @param db database table
-- @param name name of table in database to use
-- @param l line (1d array) of data to save  
function _M.addLineDB(db,name,l)
      table.insert(db[name].data,l)
      local f = io.open(db[name].fname,"a+")
      f:write(_M.toCSV(l) .. '\n')
      f:close()
end 
    
-------------------------------------------------------------------------------
-- Removes last line of data in a database table
-- @param db database table
-- @param name name of table to use
-- @param line is row number of table data 1..n to remove.
-- removes last line if line is nil
function _M.remLineDB(db,name,line)
      table.remove(db[name].data,line)  -- remove last line from the table
      _M.saveCSV(db[name])  -- save the table to .CSV file (overwriting the old one)
end
    
    
    
-------------------------------------------------------------------------------
-- Save database to multiple CSV files
-- @param db database table
function _M.saveDB(db)

  for _,t in pairs(db) do
     _M.saveCSV(t) 
     end
end
    
    
    
-------------------------------------------------------------------------------
-- Converts contents of the database into a print friendly string
-- @param db database table
-- @param w width of each cell
function _M.tostringDB(db,w)
    local csvtab = {}
 
    for k,t in pairs(db) do
        table.insert(csvtab, k..':\r\n') 
        table.insert(csvtab, 'File: '.. t.fname..'\r\n') 
        table.insert(csvtab, _M.padCSV(t.labels,w))
        table.insert(csvtab, '\r\n')
        for _,row in ipairs(t.data) do
            table.insert(csvtab, _M.padCSV(row,w))
            table.insert(csvtab, '\r\n')
        end   
      end 
    return table.concat(csvtab)
end


return _M