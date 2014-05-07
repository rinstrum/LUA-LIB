-------------------------------------------------------------------------------
-- Functions for working with .CSV files and creating multi-table databases
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
local tostring = tostring
local error = error

local dbg = require "rinLibrary.rinDebug"

-------------------------------------------------------------------------------
--- CSV Utilities.
-- Functions to convert data to and from .CSV format
-- @section Utilities

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Functions to check if a table is a CSV table and if it has any data
local function isCSV(t)
    return t ~= nil and t.labels ~= nil
end

local function hasData(t)
    return isCSV(t) and t.data ~= nil
end

-------------------------------------------------------------------------------
-- Adds '"' around s if it contains ',' or '"' and replaces '"' with '""'
-- @param s string to escape
-- @return escaped string
function _M.escapeCSV(s)
    if s ~= nil then
        s = tostring(s)  -- string find & gsub requires a string so make sure we have one
        -- if s has any commas or '"' in it put "   " around string and replace any '"' with '""'
        if string.find(s, '[,"]') then
            s = '"' .. string.gsub(s,'"','""') .. '"'
        end
    end

    return s
end

-------------------------------------------------------------------------------
-- Converts a table (1d array) to a CSV string with fields escaped if required
-- The order of the CSV string returned isn't guaranteed.
-- @param t table to convert
-- @return escaped CSV string
function _M.toCSV(t)
    local s = { }
    if t ~= nil then
        for _,p in pairs(t) do
            table.insert(s, ",")
            table.insert(s, _M.escapeCSV(p))
        end
    end
    s[1] = ""

    return table.concat(s)
end

-------------------------------------------------------------------------------
-- Converts a table (1d array) to a CSV string with fields escaped if required
-- @param t table to convert
-- @param w is width of each cell
-- @return escaped CSV string padded to w characters in each cell
function _M.padCSV(t, w)
    local s = { }

    if t ~= nil then
        local f = w ~= nil and string.format("%%%ds", w) or '%s'

        for _, p in pairs(t) do
            table.insert(s, ",")
            table.insert(s, _M.escapeCSV(string.format(f, p)))
        end
    end
    s[1] = ''

    return table.concat(s)
end

-------------------------------------------------------------------------------
-- Takes an escaped CSV string and returns a line (1d array)
-- @param s CSV string
-- @return table (1d array)

function _M.fromCSV(s)
    if s == nil then return nil end

    if #s > 0 and string.sub(s,-1,-1) == '\r' then
       s = string.sub(s,1,-2)  -- remove \r if present
    end
    if s == '' then return nil end

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

            local f = string.sub(s,fieldstart+1, i-1)
            table.insert(t, (string.gsub(f,'""','"')))
            fieldstart = string.find(s,',',i)+1
        else
            local nexti = string.find(s, ',', fieldstart)
            table.insert(t, string.sub(s,fieldstart, nexti-1))
            fieldstart = nexti + 1
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

local function writerow(f, s)
    f:write(_M.toCSV(s))
    f:write('\n')
end

-------------------------------------------------------------------------------
-- Save table t to a .CSV file
-- @param t database table to save.
-- table is in the format:
--      fname name of .csv file associated with table - used to save/restore table contents
--      labels{}  1d array of column labels
--      data{{}}  2d array of data
-- @return table in same format:

function _M.saveCSV(t)
    if t.differentOnFileSystem then
        dbg.warn("saveCSV: ", string.format("file format is different, overwriting %s", t.fname))
    end

    local f = io.open(t.fname, "w+")
    if f == nil then
        dbg.error("saveCSV: ", string.format("unable to write %s", t.fname))
    else
        writerow(f, t.labels)
        for _, row in ipairs(t.data) do
            writerow(f, row)
        end
        f:close()

        t.differentOnFileSystem = nil
    end

    return t
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Naively determine if two tables have any common fields and if so return a
-- cross mapping.  The algorithm used here is O(n . m) when n and m are the number
-- of columns in the respective CSV tables.  It is possible to implement this in
-- O(n log m) time and this should be done if CSV files with large numbers of columns
-- are expected.
local function checkCommonFields(a, b)
    local map = {}
    local n = 0
    local bname = {}

    -- Cache the converted field names for the second table to speed things a little
    for j = 1, #b do
        table.insert(bname, string.lower(string.gsub(b[j],'%s','')))
    end

    for i = 1, #a do
        map[i] = ''
        local fname = string.lower(string.gsub(a[i],'%s',''))
        for j = 1, #b do
            if fname == bname[j] then
                bname[j] = nil
                map[i] = j
                n = n + 1
                break
            end
        end
    end
    return n, map
end

-------------------------------------------------------------------------------
-- Reads a .CSV file and returns a table with the loaded contents
-- If no CSV file found or contents different then file created with structure in it.
-- @param t is table with structure of expected CSV included
-- @return table in same format:
--      fname name of .csv file associated with table - used to save/restore table contents
--      labels{}  1d array of column labels
--      data{{}}  2d array of data
-- @return A result code describing what was done:
--      create      File didn't exist, returned an empty CSV table
--      empty       File was empty, returned an empty CSV table
--      load        File loaded fine
--      full        File had all fields but some extra fields too
--      reordered   File had all fields but in a different order
--      partial     File had some common fields, returned a populated CSV table
--      immiscable  File had no common fields, returned an empty CSV table
 function _M.loadCSV(t)

     local f = io.open(t.fname,"r")
     local res = nil

     t.differentOnFileSystem = nil

     if f == nil then
          -- no file yet so create new one
          _M.saveCSV(t)
          res = "create"
     else
         local s = f:read("*l")
         if s == nil then
              -- file is empty so setup to hold t
              f:close()
              _M.saveCSV(t)
              res = "empty"
         else
              -- Check the labels are equal
              local fieldnames = _M.fromCSV(s)
              if t.labels == nil then
                 t.labels = fieldnames
              end
              if _M.equalCSV(t.labels, fieldnames) then

                 -- Clear the current table and read in the existing data
                 t.data = {}
                 for s in f:lines() do
                     table.insert(t.data,_M.fromCSV(s))
                 end
                 f:close()
                 res = "load"

              -- different format so initialize to new table format
              else
                 -- Check if there are any common fields or not
                 local n, fieldmap = checkCommonFields(t.labels, fieldnames)
                 if n ~= 0 then
                    t.data = {}
                    for s in f:lines() do
                        local fields = _M.fromCSV(s)
                        local row = {}
                        for i = 1, #fieldmap do
                            if fieldmap[i] == '' then
                                table.insert(row, '')
                            else
                                table.insert(row, fields[fieldmap[i]])
                            end
                        end
                        table.insert(t.data, row)
                    end
                    f:close()

                    t.differentOnFileSystem = true

                    -- Figure out the possible return codes based on the field counts
                    if n == _M.numColsCSV(t) then
                        if n == #fieldnames then
                            res = "reordered"
                        else
                            res = "full"
                        end
                    else
                        res = "partial"
                    end
                 else
                    f:close()
                    t.differentOnFileSystem = true
                    res = "immiscable"
                 end
              end
         end
     end
    return t, res
  end

-------------------------------------------------------------------------------
-- Adds line of data to a CSV file but does not update local data in table
-- @param t is table describing CSV data
-- @param line is a row of data (1d array) to save
function _M.logLineCSV(t, line)
    if t ~= nil and line ~= nil then
        if t.differentOnFileSystem then
            dbg.error("logLineCSV: ", "failed due to format incompatibility, try saveCSV first")
        else
            local f = io.open(t.fname, "a+")
            writerow(f, line)
            f:close()
        end
    end
end

-------------------------------------------------------------------------------
-- Adds line of data to a table
-- @param t is table holding CSV data
-- @param line of data (1d array) to add to the table
-- @return row location of line new line in table

function _M.addLineCSV(t, line)
    if hasData(t) and line ~= nil and #line == _M.numColsCSV(t) then
        table.insert(t.data, line)
        return _M.numRowsCSV(t)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Makes a duplicate copy of a line of data
-- @param line is the line of data (1-d array)
-- @return duplicate copy of line
function _M.dupLineCSV(line)
    if line ~= nil then
        local t = {}
            for k,v in pairs(line) do
                t[k] = v
            end
        return t
    end
    return nil
end

-------------------------------------------------------------------------------
-- Removes line of data in a table (does not save .CSV file)
-- @param t is table holding CSV data
-- @param row is row number of table data 1..n to remove.
-- removes last line of data if row is nil
function _M.remLineCSV(t, row)
    if hasData(t) and row ~= nil and row > 0 and row <= _M.numRowsCSV(t) then
        table.remove(t.data, row)  -- remove line from the table
    end
end

-------------------------------------------------------------------------------
-- Returns a line of data from the table with matching val in column col
-- @param t is table holding CSV data
-- @param val is value of the cell to find
-- @param col is the column of data to match (default is col 1)
-- @return row that val found in or nil if not found
-- @return line of data found at that row with matching val data in column col
function _M.getLineCSV(t,val,col)
   local line = {}
   local col = col or 1
   local row = 0
   for k,v in ipairs(t.data) do
     if string.lower(tostring(v[col])) == string.lower(tostring(val)) then
        line = v
        row = k
     end
   end
   if row == 0 then
      return nil, line
   else
      return row, line
   end
end

-------------------------------------------------------------------------------
-- Returns a column of data in a 1-D table
-- @param csvtbl is table holding CSV data
-- @param col is the column of data to match (default is col 1), column names are allowed
-- @return a column of data
-- @usage
-- names = csv.getColCSV(db.material,2)           -- gather all material names
-- sel = dwi.selectOption('SELECT',names,names[1],true)    -- chose a material
--
function _M.getColCSV(csvtbl, col)
    local column = {}
    local t, c = csvtbl, col

    if not hasData(t) then
        return nil
    end

    if c == nil then
        c = 1
    elseif type(c) == "string" then
        c = _M.labelCol(t, c)
        if c == nil then return nil end
    end
    if c > _M.numColsCSV(t) or c < 1 then
        return nil
    end

    for k,v in ipairs(t.data) do
        table.insert(column, v[c])
    end
    return column
end

-------------------------------------------------------------------------------
-- Replaces a line of data in the table (does not save the .CSV file)
-- @param t is table holding CSV data
-- @param row is the row number of the line of data
-- @param line is the line of data
function _M.replaceLineCSV(t, row, line)
    if row ~= nil and hasData(t) and row > 0 and row <= _M.numRowsCSV(t) then
        if line == nil then
            _M.remLineCSV(t, row)
        elseif #line == _M.numColsCSV(t) then
            t.data[row] = line
        end
    end
end

-------------------------------------------------------------------------------
-- Returns the column number of a particular label
-- @param t is table holding CSV data
-- @param label is name of column to find (not case sensitive)
-- @return column number of the label or nil if not found
function _M.labelCol(t,label)
    if label ~= nil and isCSV(t) then
        local label = string.lower(tostring(label))

        for k,v in pairs(t.labels) do
            if string.lower(v) == label then
                return k
            end
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Converts contents of the CSV table into a print friendly string
-- @param t table to convert
-- @param w width to pad each cell to
-- @return string
function _M.tostringCSV(t,w)
    local csvtab = {}
    local w = w or 10

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
-- Converts contents of the 1-D column of data into a print friendly string
-- @param c column of data convert
-- @return string
function _M.tostringCol(c)
    if c == nil then
        return nil
    end

    local t = {}
    for _,v in ipairs(c) do
        table.insert(t,v)
        table.insert(t,'\r\n')
    end
    return table.concat(t)
end

-------------------------------------------------------------------------------
-- Converts contents of the row into a print friendly string
-- @param line of data to convert
-- @param w width to pad each cell to
-- @return string
function _M.tostringLine(line,w)
    if line == nil then
        return nil
    end
    return _M.padCSV(line, w or 10)
end

-------------------------------------------------------------------------------
-- returns the number of rows of data in CSV table
-- @param t CSV table
-- @return number of rows
function _M.numRowsCSV(t)
    return hasData(t) and #t.data or 0
end

-------------------------------------------------------------------------------
-- returns the number of columns of data in CSV table
-- @param t CSV table
-- @return number of columns
function _M.numColsCSV(t)
    return isCSV(t) and #t.labels or 0
end

-------------------------------------------------------------------------------
--- Database Utilities.
-- Functions to manage multiple tables in a database
-- @section Database

 -----------------------------------------------------------------------------------
-- Adds a database table to the database, updates contents with t if already present
-- @param db is the database table to populate
-- @param name is the name of table
-- @param t is the csv table to add
-- database table is in the format
-- fname name of .csv file associated with table - used to save/restore table contents
-- labels{}  1d array of column labels
-- data{{}}  2d array of data
 function _M.addTableDB(db, name, t)
    local created = false

    -- Update existing database table with the new data.
    for k,v in pairs(db) do
        if v.fname == t.fname then
            db[k] = t
            created = true
        end
    end

    -- Add database table to the rinCSV database
    if not created then
        db[name] = t
    end
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
    local w = w or 10

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
