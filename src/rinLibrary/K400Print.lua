-------------------------------------------------------------------------------
--- Printing Functions.
-- Functions to control instrument printing
-- @module rinLibrary.Device.Print
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local type = type
local tostring = tostring
local table = table
local loadstring = loadstring

local bit32 = require "bit"
local dbg = require "rinLibrary.rinDebug"
local naming = require 'rinLibrary.namings'
local can = naming.canonicalisation
local utils = require 'rinSystem.utilities'

local lpeg = require 'rinLibrary.lpeg'
local C, Cg, Cs, Ct = lpeg.C, lpeg.Cg, lpeg.Cs, lpeg.Ct
local P, Pi, V, S, spc = lpeg.P, lpeg.Pi, lpeg.V, lpeg.S, lpeg.space
local R = lpeg.R

local REG_PRINTPORT         = 0xA317
local REG_REPLYLUATOKEN     = 0x004B
local REG_PRINTTOKENSTR     = 0x004C
local REG_PRINT_AUTO        = 0x900D

local PRINT_SER1A           = 0
local PRINT_SER1B           = 1
local PRINT_SER2A           = 2
local PRINT_SER2B           = 3

local portMap = {
    ser1a = PRINT_SER1A,    ['1a'] = PRINT_SER1A,
    ser1b = PRINT_SER1B,    ['1b'] = PRINT_SER1B,
    ser2a = PRINT_SER2A,    ['2a'] = PRINT_SER2A,
    ser2b = PRINT_SER2B,    ['2b'] = PRINT_SER2B
}

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Print string formatting setup
local formatAttributes, formatSingle = {
    width = '-',        -- - or number
    align = 'left',     -- left or right
    supress = 'no'      -- no, field or line
}, {}
local formatFailed, formatPosition, formatSubstitutions

local autoModes = {
    auto = 1,
    manual = 0
}

local name, num, value, s = C(lpeg.alpha * lpeg.alnum^0), C(lpeg.digit^1), C(lpeg.alnum^1), spc^0
local POS = P(function(t, p) formatPosition = p return p end)
local eql = s * P'=' * s

-------------------------------------------------------------------------------
-- Format a hex pair for output
-- @param x Hex string for format $xx
-- @return Hex output string \XX
-- @local
local function formatHex(x)
    return '\\' .. string.upper(x:sub(2))
end

-------------------------------------------------------------------------------
-- Set an attribute value just for this field
-- @param x Attribute table
-- @return ''
-- @local
local function setLocalAttribute(x)
    formatSingle[string.lower(x[1])] = x[2]
    return ''
end

-------------------------------------------------------------------------------
-- Set an attribute value globally
-- @param x Attribute table
-- @return ''
-- @local
local function setGlobalAttribute(x)
    formatAttributes[string.lower(x[1])] = x[2]
    return ''
end

-------------------------------------------------------------------------------
-- Apply a substitution.
-- @param x Table containing name list to be substituted
-- @return Substituted value.
-- @local
local function substitute(x)
    local p, singles, last = formatSubstitutions, formatSingle
    formatSingle = {}

    local function getAttribute(n)
        if singles[n] ~= nil then
            return singles[n]
        end
        return formatAttributes[n]
    end

    local width = getAttribute'width'

    for _, k in ipairs(x) do
        local cank = can(k)
        local z = tonumber(k) or cank
        if type(p) ~= 'table' or (p[z] == nil and p[cank] == nil) then
            local supress = getAttribute'supress'
            if supress == 'line' then
                formatFailed = true
                return ''
            else
                local w = width == '-' and 1 or width
                local c = supress == 'field' and ' ' or '?'
                return string.rep(c, w)
            end
        end
        p, last = p[z] or p[cank], p[z] and z or cank
    end
    if type(p) == 'table' then
        p = p[last]
    end

    local format = '%'
    if width ~= '-' then
        format = format .. (getAttribute'align' == 'left' and '-' or '') .. width
    end
    return string.format(format .. 's', tostring(p))
end

local printFormatter = P{
            Cs((P'{'*s/'' * POS * V'cmd' * (s*P'}'/'') + (1-P'{'))^0) * P(-1),
    cmd =   Cs(V'attr' + V'sub' + V'hex'),
    hex =   P'$' * lpeg.xdigit * lpeg.xdigit / formatHex,
    sub =   Ct(name * ((S':.'+spc^1) * (V'subat' + name + num))^0) / substitute,
    subat = Cg(Ct(V'align' + V'width' + V'sup') / setLocalAttribute, ''),

    attr =  Ct(V'align' + V'width' + V'sup') / setGlobalAttribute,
    align = C(Pi'align') * eql * C(Pi'left' + Pi'right'),
    width = C(Pi'width') * eql * C(num + '-'),
    sup =   C(Pi'supress') * eql * C(Pi'no' + Pi'field' + Pi'line')
}

-------------------------------------------------------------------------------
-- Format a passed in string using the print format escapes.
-- This function can either format a single string or a table of strings.
-- A failed substitution will cause a nil return for a single string or
-- no entry for a table of strings.
-- @param s String to format or table of strings
-- @return Formatted string(s).
-- @local
local function formatObject(s)
    local r = nil
    if type(s) == 'string' then
        formatFailed = false
        local z = printFormatter:match(s)
        if z == nil then
            dbg.error('Error:', ' '..s)
            dbg.error('   at ', string.rep('_', formatPosition)..'|')
        elseif not formatFailed then
            r = z
        end
    else
        r = {}
        for line, v in ipairs(s) do
            local q = formatObject(v)
            if q ~= nil then
                table.insert(r, q)
            end
        end
    end
    return r
end

-------------------------------------------------------------------------------
-- Takes a non-printable character and escapes it
-- @param c Non-printable character
-- @return Escaped string
-- @local
local function escapeNonPrintable(c)
    return string.format("\\%02X", string.byte(c))
end

-------------------------------------------------------------------------------
-- Takes a string s and returns a formatted CustomTransmit string with all
-- non-printable characters escaped in \xx format
-- @param s string to convert
-- @return string with all non-printable characters escaped in \xx format
-- @local
local function expandCustomTransmit(s)
  return (string.gsub(s, "[^\32-\126]", escapeNonPrintable))
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

local curPrintPort = nil

-------------------------------------------------------------------------------
-- @string str String to split
-- @int len Length to split string into
-- @func f Function to call with split string
-- @local
local function splitStringWithTokens(str,len, f)
    local i = 1
    local sendStr
    -- Break up the string as we send it, preventing tokens from being split
    while i < #str do
      if string.sub(str, i+len-2, i+len-2) == '\\' then
        sendStr = string.sub(str, i, i+len)
        i = i + len + 1
      elseif string.sub(str, i+len-1, i+len-1) == '\\' then
        sendStr = string.sub(str, i, i+len+1)
        i = i + len + 2
      else
        sendStr = string.sub(str, i, i+len-1)
        i = i + len
      end
      
      f(sendStr)
    end
end

-------------------------------------------------------------------------------
-- Send custom print token string to instrument comms port
-- If the port is unspecified, the previous port will be used or 'ser1a' if
-- no previous port has been used.
-- @string tokenStr String containing custom print tokens
-- @string comPortName Port to use: 'ser1a', 'ser1b', 'ser2a' or 'ser2b'
-- @see reqCustomTransmit
-- @usage
-- -- A usage application can be found in the printCopy example.
--
-- device.printCustomTransmit([[--------------------------\C1]], 'ser1a')
-- for k,v in ipairs(printCopy) do
--     device.printCustomTransmit(v, 'ser1a')
-- end
-- device.printCustomTransmit([[<<Copy>>\C1]], 'ser1a')
function _M.printCustomTransmit(tokenStr, comPortName)
    local comPort = naming.convertNameToValue(comPortName, portMap, curPrintPort or PRINT_SER1A)
    tokenStr = expandCustomTransmit(tokenStr)
    
    -- Write the output string in chunks
    splitStringWithTokens(tokenStr, 100, function (s) 
        if comPort ~= curPrintPort  then
            curPrintPort = comPort
            private.writeRegHex(REG_PRINTPORT, comPort)
        end
        private.writeRegHex(REG_PRINTTOKENSTR, s)
    end)
end

-------------------------------------------------------------------------------
-- Called to request response based on custom transmit token string
-- @string tokenStr Custom token string
-- @treturn string Expanded token string or nil on error
-- @treturn string Nil on success or error code on failure
-- @see printCustomTransmit
-- @usage
-- -- get the current weight as a string
-- local weightString = device.reqCustomTransmit([[\D7]])
function _M.reqCustomTransmit(tokenStr)
    local result = ""
    
    -- Send in chunks and return concatenated result
    splitStringWithTokens(tokenStr, 100, function (s) 
        result = result .. private.writeRegHex(REG_REPLYLUATOKEN, s, 1)
    end)
    
    return result
end

local defaultHeadings = {
  "serial port",
  "instructions",
  "baud",
  "new line",
  "tokens",
  "print"
}

local function unescape(input)
  return loadstring("return \"" .. input .. "\"")() 
end

local headingPat = Ct{
  P"===" * V'heading' * (P"=")^1 * P(-1),
  heading = Cg((R"AZ"+R"az"+R"09"+P" ")^1 / string.lower, 'heading'),
}

-------------------------------------------------------------------------------
-- Print format file parser
-- Default headings are "serial port", "instructions", "baud", "new line",
-- "tokens", "print", will automatically be returned. Other headings can be
-- added by the user. Tokens can then be passed by formatPrintString
-- @string fileName File to load strings from
-- @tparam[opt] {string,...} headings Table of strings to load. This will be merged with defaults.
-- @treturn {heading=string,...} Return a table where headings are matched to
-- their strings loaded from the file. Nil on error.
-- @treturn string nil if no error, error string otherwise.
-- @see formatPrintString
-- @usage
-- --Printer.txt should look like this 
----[[
--===INSTRUCTIONS========
--Fill out SERIAL PORT with a K400 serial port (e.g. ser1a, ser1b, etc.) or 'usb'.
--Build up your print message under the PRINT heading using the tokens defined in
--TOKENS. If usb is used, BAUD can be set to attempt to use that baud rate for USB.
--
--NEW LINE should contain the escaped new line character. For the K400 serial this
--is \\C1, \n for usb (or whatever the printer expects as newline).
--===SERIAL PORT=========
--usb
--===BAUD================
--9600
--===NEW LINE============
--\r\n
--===TOKENS==============
--
--{plu}                   PLU selected for this item
--{description1}          Description from PLU Table (1st line)
--{description2}          Description from PLU Table (2nd line)
--{useby}                 Product lifespan (e.g. 9) from PLU Table.
--{tare_weight}           Tare weight from PLU Table.
--{address1}              Address from PLU Table (1st line)
--{address2}              Address from PLU Table (2nd line)
--
--{package_date}          Date receipt printed. Uses instrument format.
--{useby_date}            PACKAGE_DATE+USEBY
--
--{weight}                GROSS_WEIGHT-TARE_WEIGHT
--{units}                 Units of gross weight.
--
--===PRINT===============
--Scale
--
--{plu}
--{description1}
--{description2}
--{address1}
--===PRINT2==============
--{useby}
--{package_date}
--{useby_date}
--
--{weight}{units}
-- --]]
--local strs, err = device.loadPrintStrings("printer.txt", {"PRINT2"})
--
--if err then
--  print(strs, err)
--end
--
--for k,v in pairs(strs) do
--  print(k)
--  print("=============")
--  print(v)
--  print("-------------")
--end
function _M.loadPrintStrings(fileName, headings)
  local modes = {}
  local mode = nil
  headings = headings or {}
  
  -- Add the defaultHeadings to the headings table
  for k, heading in pairs(defaultHeadings) do
    table.insert(headings, heading)
  end
  
  -- Populate the modes table using the headings and empty strings
  for k, heading in pairs(headings) do
    modes[string.lower(heading)] = ""
  end
  
  -- Load the file
  local lines, err = utils.loadFileByLines(fileName)
  if err then
    return nil, err 
  end  
  
  -- Iterate over each line
  for k,line in pairs(lines) do
  
    -- Remove \r if it exists
    if (string.sub(line, -1) == '\r') then
      line = string.sub(line, 1, -2)
    end
    
    -- Check if this is a control line
    local m = headingPat:match(line)
    if m ~= nil then
      mode = m.heading
    -- Append line to the current mode if it's not a control line
    elseif mode ~= nil then
      modes[mode] = modes[mode] .. line .. unescape(modes['new line'] or "")
    end
  end
  
  return modes
end

-------------------------------------------------------------------------------
-- Format a passed in string using the print format escapes.
-- This function can either format a single string or a table of strings.
-- A failed substitution will cause a nil return for a single string or
-- no entry for a table of strings.
-- @tab subs Table of substitution values
-- @string s String to format or table of strings
-- @treturn string Formatted string(s).
-- @usage
--local tokens = {
--   id1 = true,
--   id2 = "13434",
--   id3 = 132413,
--   id4 = "boot",
--   id5 = {t1 = 1, t2 = 3},
--   id6 = "test this now"
--}
--
--local testStr = [[
--id1 = {id1}
--id2 = {id2}
--id3 = {id3}
--id4 = {id4}
--id5 = {id5.t1} {id5.t2}
--id6 = {id6}
--]]
--
--print(device.formatPrintString(tokens, testStr))
function _M.formatPrintString(subs, s)
    formatSubstitutions = {}
    for k, v in pairs(subs) do
      formatSubstitutions[can(k)] = v
    end

    return formatObject(s)
end

-------------------------------------------------------------------------------
-- Set the print auto mode
-- @string setting The auto mode to enter ('manual' or 'auto')
-- @usage
-- device.printModeAuto('auto')
function _M.printModeAuto(setting)
    local v = naming.convertNameToValue(setting, autoModes, autoModes.manual)
    private.writeRegAsync(REG_PRINT_AUTO, v)
end

if _TEST then
    _M.escapeNonPrintable = escapeNonPrintable
    _M.expandCustomTransmit = expandCustomTransmit
end

end

