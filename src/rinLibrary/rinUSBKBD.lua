------------------------------------------------------------------------------
-- Services for saving and restoring settings in a table to .INI config file
-- @module rinLibrary.rinINI
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

local io = io
local type = type
local pairs = pairs
local string = string
local table = table
local ipairs = ipairs
local tostring = tostring


-------------------------------------------------------------------------------
-- Must be called to link these utilities with a particular rinApp application
-- @param app rinApp application
-- @usage
-- local rinApp = require "rinApp"    
-- local usbKBD = require "rinLibrary/rinUSBKBD"
-- usbKBD.link(rinApp)

function _M.link(app)
  _M.app = app
  _M.system = app.system
end



-------------------------------------------------------------------------------
-- Called to get a key from keyboard
-- @return key pressed
function _M.getKey()
    
    local keypressed = ''
    
    local f = _M.app.getUSBKBDCallback()
    local function kbdHandler(key)
        keypressed = key
    end
    _M.app.setUSBKBDCallback(kbdHandler)

    
    while _M.app.running and keypressed == '' do
        _M.system.handleEvents()
    end   
    _M.app.setUSBKBDCallback(f)

    return keypressed  
end
_M.editing = false
-------------------------------------------------------------------------------
-- Check to see if editing routines active
-- @return true of editing false otherwise
function _M.isEditing()
   return _M.editing
end


-------------------------------------------------------------------------------
-- Called to prompt operator to enter a value
-- @param dwi Indicator to use for edit display
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @param typ type of value to enter ('integer','number','string' 
-- @return value and true if ok pressed at end
function _M.edit(dwi, prompt, def, typ)

    local def = def or ''
    if type(def) ~= 'string' then
         def = tostring(def)
     end     
    
    local editVal = def 
    local editType = typ or 'integer'
    _M.editing = true
    
    dwi.saveBot()
    dwi.writeBotRight(prompt)
    dwi.writeBotLeft(editVal)

    local first = true

    local ok = false  
    while _M.editing do
        key = _M.getKey()
        if key == '\n' then         
                _M.editing = false
                 if string.len(editVal) == 0 then
                    editVal = def
                 end    
                ok = true
        elseif key == '\08 \08' then    
            if string.len(editVal) == 0 then
                editVal = def
                _M.editing = false
            else
                editVal = string.sub(editVal,1,-2)
            end 
         --   elseif key == _M.KEY_CANCEL then
         --       editVal = def
         --     _M.editing = false

        elseif editType == 'string' then
            if first then 
                 editVal = key 
            else 
                 editVal = editVal .. key 
            end
            first = false
        elseif key >= '0' and '9' then
            if first then 
                 editVal = key 
            else 
                 editVal = editVal .. key 
            end
            first = false
        elseif key == '.' and editType ~= 'integer' then
            if editType == 'number' then 
                if first or string.len(editVal) == 0 then
                   editVal = '0.'
                   first = false
                elseif not string.find(editVal,'%.')  then
                   editVal = editVal .. '.'
                end
            else 
                editVal = editVal .. '.'             
            end
        end
        if #editVal > 9 then        
            dwi.writeBotLeft(string.format('%-9s',string.sub(editVal,#editVal-8,-1)))
        else
            dwi.writeBotLeft(editVal)
        end    
    end 
    dwi.restoreBot()
   
    if editType == 'string' then
       return editVal, ok
    else
       return tonumber(editVal), ok
    end   
end


return _M