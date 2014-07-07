-------------------------------------------------------------------------------
---  General Utilities.
-- General Functions for configuring the instrument
-- @module rinLibrary.K400Util
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local string = string
local tonumber = tonumber
local type = type
local floor = math.floor
local bit32 = require "bit"
local powersOfTen = require "rinLibrary.powersOfTen"
local rinMsg = require "rinLibrary.rinMessage"

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, depricated)
local REG_LCDMODE          = 0x000D

local instrumentModel = ''
local instrumentSerialNumber = nil

-------------------------------------------------------------------------------
-- Called to setup LCD control.
-- The rinApp framework generally takes care of calling this function for you.
-- However, sometimes you'll want to return control to the display device
-- for a time and grab control again later.
-- @param mode  is 'lua' to control display from script or 'default'
-- to return control to the default instrument application
-- @usage
-- device.lcdControl('default')     -- let the display control itself
-- ...
-- device.lcdControl('lua')         -- switch on Lua display
function _M.lcdControl(mode)
    local mode = mode or ''

    if mode == 'lua' then
        _M.sendRegWait(_M.CMD_EX, REG_LCDMODE,2)
    else
        _M.sendRegWait(_M.CMD_EX, REG_LCDMODE,1)
    end
end

-------------------------------------------------------------------------------
-- Called to connect the K400 library to a socket and a system
-- The rinApp framework takes care of calling this function for you.
-- @param model Software model expected for the instrument (eg "K401")
-- @param sockA TCP sockets to connect SERA port
-- @param sockB TCP sockets to connect SERB port
-- @param app application framework
-- @usage
-- local me = {}
--
-- local sA = _M.system.sockets.createTCPsocket('1.1.1.1', 2222, 0.001)
-- local sB = _M.system.sockets.createTCPsocket('1.1.1.1', 2223, 0.001)
--
-- device.connect('K401', sA, sB, me)
function _M.connect(model, sockA, sockB, app)
    instrumentModel = model
    _M.socketA = sockA
    _M.socketB = sockB
    _M.app = app
    _M.system = app.system
    local ip, port = sockA:getpeername()
end

-------------------------------------------------------------------------------
-- Called to disconnect the K400 library and clean everything up
-- The rinApp framework takes care of calling this function for you.
-- @usage
-- device.terminate()
function _M.terminate()
    _M.restoreLcd()
    _M.lcdControl('default')
    _M.streamCleanup()
    _M.endKeys()
end

-------------------------------------------------------------------------------
-- Called to read a register value and return value and dp position
-- Used to work out the dp position of a register value so subsequent
-- reads can use the hexadecimal format and convert locally using
-- toFloat
-- @param reg  register to read
-- @return register value number and dp position
function private.getRegDP(reg)
    local data, err = _M.sendRegWait(_M.CMD_RDLIT,reg)
    if err then
        _M.dbg.error('getDP: ', reg, err)
        return nil, nil
    else
        local tmp = string.match(data,'[+-]?%s*(%d*%.?%d*)')
        local dp = string.find(tmp,'%.')
        if not dp then
            dp = 0
        else
            dp =  string.len(tmp) - dp
        end

        return tonumber(tmp), dp
    end
end

-------------------------------------------------------------------------------
-- Called to save any changed settings and re-initialise instrument
-- @local
function private.saveSettings()
    _M.sendRegWait(_M.CMD_EX, private.REG_SAVESETTING)
end

local REG_PRIMARY_DISPMODE   = 0x0306
local REG_SECONDARY_DISPMODE = 0x0307

_M.DISPMODE_PRIMARY      = 1
_M.DISPMODE_PIECES       = 2
_M.DISPMODE_SECONDARY    = 3
_M.units = {"  ","kg","lb","t ","g ","oz","N ","  ","p ","l ","  "}
_M.countby = {1,2,5,10,20,50,100,200,500}
_M.settings = {}
_M.settings.fullscale = 3000
_M.settings.dispmode = {}
_M.settings.dispmode[_M.DISPMODE_PRIMARY] =   {reg = REG_PRIMARY_DISPMODE,   units = _M.units[2], dp = 0, countby = {1,2,5}}
_M.settings.dispmode[_M.DISPMODE_PIECES] =    {reg = 0,                      units = _M.units[9], dp = 0, countby = {1,1,1}}
_M.settings.dispmode[_M.DISPMODE_SECONDARY] = {reg = REG_SECONDARY_DISPMODE, units = _M.units[3], dp = 0, countby = {2,5,10}}
_M.settings.curDispMode = _M.DISPMODE_PRIMARY
_M.settings.hiRes = false
_M.settings.curRange = 1

-------------------------------------------------------------------------------
-- Called to load settings
-- @local
local function readSettings()
    _M.settings.fullscale = private.getRegDP(_M.REG_FULLSCALE)
    for mode = _M.DISPMODE_PRIMARY, _M.DISPMODE_SECONDARY do
        if _M.settings.dispmode[mode].reg ~= 0 then
            local data, err = _M.sendRegWait(_M.CMD_RDFINALHEX,_M.settings.dispmode[mode].reg)
            if data and not err then
                data = tonumber(data, 16)
                if data ~= nil then
                    _M.settings.dispmode[mode].dp = bit32.band(data,0x0000000F)
                    _M.settings.dispmode[mode].units = _M.units[1+bit32.band(bit32.rshift(data,4),0x0000000F)]
                    _M.settings.dispmode[mode].countby[3] = _M.countby[1+bit32.band(bit32.rshift(data,8),0x000000FF)]
                    _M.settings.dispmode[mode].countby[2] = _M.countby[1+bit32.band(bit32.rshift(data,16),0x000000FF)]
                    _M.settings.dispmode[mode].countby[1] = _M.countby[1+bit32.band(bit32.rshift(data,24),0x000000FF)]
                else
                    _M.dbg.warn('Bad settings data: ', data)
                end
            else
                _M.dbg.warn('Incorrect read: ',data,err)
            end
        end
    end
    _M.saveAutoLeft()
end

local REG_COMMS_START = 0x0309

-------------------------------------------------------------------------------
-- Called to configure the instrument library
-- The rinApp framework takes care of calling this function for you.
-- @return nil if ok or error string if model doesn't match
-- @usage
-- device.configure('K401')
function _M.configure(model)
    local s, err = _M.sendRegWait(_M.CMD_RDLIT,_M.REG_SOFTMODEL)
    if not err then
        instrumentModel = s
        instrumentSerialNumber, err = _M.sendRegWait(_M.CMD_RDLIT,_M.REG_SERIALNO)
    end

    _M.dbg.info(instrumentModel, instrumentSerialNumber)

    readSettings()

    _M.sendRegWait(_M.CMD_EX, REG_COMMS_START)  -- clear start message

    if err then
        instrumentModel = ''
        return err
    elseif model ~= instrumentModel then
        return "Wrong Software Model"
    else
        return nil
    end
end

-------------------------------------------------------------------------------
-- Called to convert a floating point value to a decimal integer based on then
-- primary instrument weighing settings
-- @param v is value to convert
-- @param dp decimal position (if nil then instrument dp used)
-- @return floating point value suitable for a WRFINALDEC
-- @usage
-- local curWeight = 0
-- device.addStream(dwi.REG_GROSSNET, function(data, err) curWeight = data end, 'change')
-- ...
-- device.writeReg(device.REG_USERNUM3, device.toPrimary(curWeight))
function _M.toPrimary(v, dp)
    local dp = dp or _M.settings.dispmode[_M.settings.curDispMode].dp  -- use instrument dp if not specified otherwise

    if type(v) == 'string' then
        v = tonumber(v)
    end                              -- TODO: how to handle non-numbers elegantly here?
    return floor(0.5 + v * powersOfTen[dp])
end

-------------------------------------------------------------------------------
-- Read a RIS file and send valid commands to the device
-- @param filename Name of the RIS file
-- @usage
-- device.loadRIS('myApp.RIS')
function _M.loadRIS(filename)
    local file = io.open(filename, "r")
    if not file then
      _M.dbg.warn('RIS file not found',filename)
      return
    end
    for line in file:lines() do
         if (string.find(line, ':') and tonumber(string.sub(line, 1, 8), 16)) then
            local endCh = string.sub(line, -1, -1)
            if endCh ~= '\r' and endCh ~= '\n' then
                 line = line .. ';'
            end

            local _,cmd,reg,data,err = rinMsg.processMsg(line)
            if err then
               _M.dbg.error('RIS error: ',err)
            end
            _M.sendRegWait(cmd,reg,data)
         end
    end
    private.saveSettings()
    file:close()
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the depricated fields
depricated.REG_LCDMODE              = REG_LCDMODE
depricated.REG_PRIMARY_DISPMODE     = REG_PRIMARY_DISPMODE
depricated.REG_SECONDARY_DISPMODE   = REG_SECONDARY_DISPMODE

depricated.getRegDP = getRegDP
depricated.readSettings = readSettings
depricated.saveSettings = private.saveSettings

end
