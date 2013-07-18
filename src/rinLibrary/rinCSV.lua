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
-- Adds a database table to the database
-- @param name is the name of table
-- @param t database table to add
-- database table is in the format 
-- fname name of .csv file associated with table - used to save/restore table contents
-- labels{}  1d array of column labels
-- data{{}}  2d array of data
 function _M.addTable(name,t)
	local created = false
	for k,v in pairs(_M.tables) do
		if v.fname == t.fname then
         	_M.tables[k] = t             -- update existing database table with the new data.
			created = true
      	end   
	end 
     
    if not created then 
    	_M.tables[name] = t 
    end    -- add database table to database
  end
 

-------------------------------------------------------------------------------
-- Checks labels to ensure database table is the same structure  
-- Tolerant of additional whitespace in labels and ignores case
-- @param labels 1d array of labels from a database table
-- @param check 1d array of labels to check
-- @return true if labels and check are the same, false otherwise
function _M.equalCSV(labels, check)
   
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
-- Restores database contents from CSV files
-- Only loads in database tables already added to database 
 function _M.loadDB()

	for k,t in pairs(_M.tables) do
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
	 end	 
end


-------------------------------------------------------------------------------
-- Adds line of data to a table in the database
-- @param name name of table to use
-- @param l line (1d array) of data to save  
function _M.addLineCSV(name,l)
      table.insert(_M.tables[name].data,l)
	  local f = io.open(_M.tables[name].fname,"a+")
      f:write(_M.toCSV(l) .. '\n')
      f:close()
end	
   
-------------------------------------------------------------------------------
-- Save database table t to a .CSV file
-- @param t database table to save
-- database table is in the format:
-- 		fname name of .csv file associated with table - used to save/restore table contents
-- 		labels{}  1d array of column labels
-- 		data{{}}  2d array of data
function _M.saveCSV(t)
      local f = io.open(t.fname,"w+")
      f:write(_M.toCSV(t.labels) .. '\n')
      for _,row in ipairs(t.data) do
         f:write(_M.toCSV(row) .. '\n')
      end   
      f:close()
end	


	
-------------------------------------------------------------------------------
-- Save database to multiple CSV files
function _M.saveDB()

  for _,t in pairs(_M.tables) do
     _M.saveCSV(t) 
     end
end

-------------------------------------------------------------------------------
-- Converts contents of the database into a print friendly string
function _M.tostringDB()
	local csvtab = {}
 
	for k,t in pairs(_M.tables) do
		table.insert(csvtab, k..':\r\n') 
		table.insert(csvtab, 'File: '.. t.fname..'\r\n') 
		table.insert(csvtab, _M.toCSV(t.labels))
		table.insert(csvtab, '\r\n')
		for _,row in ipairs(t.data) do
			table.insert(csvtab, _M.toCSV(row))
			table.insert(csvtab, '\r\n')
		end   
	end 
    return table.concat(csvtab)
end


return _M