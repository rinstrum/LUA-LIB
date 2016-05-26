--------------------------------------------------------------------------------
--- Documentation of the ldoc features
-- @module rinLibrary.ldocUsage
-- @author Darren Pearson
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--- Section Comments.
-- Description of the section goes here
-- @section sectionName

--- Table Definition.
--@table tableName
-- @field FIELD1 Field 1 Description
-- @field FIELD2 Field 2 DescriptionREG_SOFTVER Software Version eg "V1.00"
-- @field FIELD3 Field 3 DescriptionREG_SERIALNO Serial Number

-------------------------------------------------------------------------------
-- General Function Description goes here.
-- @param p1 Parameter 1 description
-- @param p2 Parameter 2 description
-- @return return description
-- @see anotherFunction
-- @usage
--       a = myFunction(1,2)  -- comment in example code
function myFunction(p1,p2)
 
end

-------------------------------------------------------------------------------
-- Another Function Description goes here.
-- You can add multiple lines of description and link to standard 
-- Lua functions also.
-- @param p1 Parameter 1 description
-- @param p2 Parameter 2 description
-- @return  returns description
-- @see string.sub
-- @usage
--       b = anotherFunction(1,2)  -- comment in example code
function anotherFunction(p1,p2)
 
end

-------------------------------------------------------------------------------
-- Private Method
-- You need -a flag or 'all=true' to see these
-- @local
local function localFunction(p1,p2)
 
end
