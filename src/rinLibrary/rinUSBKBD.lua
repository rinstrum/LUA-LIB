------------------------------------------------------------------------------
-- Functions to setu and use a USB keyboard
-- @module rinLibrary.rinUSBKBD
-- @author Darren Pearson
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local io = io
local type = type
local pairs = pairs
local string = string
local table = table
local ipairs = ipairs
local tostring = tostring

local _M = {}

local usb = require "rinLibrary.rinUSB"
local editing = false
local rinApp

-------------------------------------------------------------------------------
-- Must be called to link these utilities with a particular rinApp application
-- @param app rinApp application
-- @usage
-- local rinApp = require "rinApp"
-- local usbKBD = require "rinLibrary/rinUSBKBD"
-- usbKBD.link(rinApp)
function _M.link(app)
    rinApp = app
end

-------------------------------------------------------------------------------
-- Called to get a key from keyboard
-- @return key pressed
-- @usage
-- while true do
--     print('key press:', device.getKey())
-- end
function _M.getKey()

    local keypressed = ''

    local f = rinApp.getUSBKBDCallback()
    local function kbdHandler(key)
        keypressed = key
    end
    usb.setUSBKBDCallback(kbdHandler)

    while rinApp.running and keypressed == '' do
        rinApp.system.handleEvents()
    end
    usb.setUSBKBDCallback(f)

    return keypressed
end

-------------------------------------------------------------------------------
-- Check to see if editing routines active
-- @return true of editing false otherwise
function _M.isEditing()
    return editing
end

-------------------------------------------------------------------------------
-- Called to prompt operator to enter a value
-- @param dwi Indicator to use for edit display
-- @param prompt string displayed on bottom right LCD
-- @param def default value
-- @param typ type of value to enter ('integer','number','string')
-- @param units optional units to display
-- @param unitsOther optional other units to display
-- @return value and true if ok pressed at end
function _M.edit(dwi, prompt, def, typ, units, unitsOther)

    local def = def or ''
    if type(def) ~= 'string' then
         def = tostring(def)
     end

    local u = units or 0
    local uo = unitsOther or 0

    local editVal = def
    local editType = typ or 'integer'
    editing = true

    dwi.saveBot()
    dwi.writeBotRight(prompt)
    dwi.writeBotLeft(editVal)
    dwi.writeBotUnits(u, uo)
    local first = true

    local ok = false
    while editing do
        key = _M.getKey()
        if key == '\n' then
                editing = false
                 if string.len(editVal) == 0 then
                    editVal = def
                 end
                ok = true
        elseif key == '\08 \08' then
            if string.len(editVal) == 0 then
                editVal = def
                editing = false
            else
                editVal = string.sub(editVal,1,-2)
            end
         --   elseif key == _M.KEY_CANCEL then
         --       editVal = def
         --     editing = false

        elseif editType == 'string' then
            if first then
                 editVal = key
            else
                 editVal = editVal .. key
            end
            first = false
        elseif key >= '0' and key <= '9' then
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
