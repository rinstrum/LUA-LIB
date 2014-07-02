-------------------------------------------------------------------------------
--- Status Monitoring.
-- Functions associated with the status monitoring
-- @module rinLibrary.K400Status
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local string = string
local pairs = pairs
local ipairs = ipairs
local bit32 = require "bit"

-------------------------------------------------------------------------------
-- Function to test if any of the specified bits are set in the data.
-- @param data The value to check against.
-- @param ... The bit positions of interest.
-- @return true iff one of the bits is set.
-- @local
local function anyBitSet(data, ...)
    if arg.n == 0 then
        return false
    end

    for i,v in ipairs(arg) do
        if bit32.band(bit32.lshift(0x01, v-1), data) ~= 0 then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Function to test if all of the specified bits are set in the data.
-- @param data The value to check against.
-- @param ... The bit positions of interest.
-- @return true iff all of the bits is set.
-- @local
local function allBitSet(data, ...)
    if arg.n == 0 then
        return false
    end

    for i,v in ipairs(arg) do
        if bit32.band(bit32.lshift(0x01, v-1), data) == 0 then
            return false
        end
    end
    return true
end


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, depricated)

--- Status Bits for REG_SYSSTATUS.
--@table sysstatus
-- @field SYS_OVERLOAD         Scale overloaded
-- @field SYS_UNDERLOAD        Scale underload
-- @field SYS_ERR              Error active
-- @field SYS_SETUP            Instrument in setup mode
-- @field SYS_CALINPROG      Instrument calibration in progress
-- @field SYS_MOTION           Weight unstable
-- @field SYS_CENTREOFZERO     Centre of Zero (within 0.25 divisions of zero)
-- @field SYS_ZERO             Weight within zero band setting
-- @field SYS_NET              Instrument in Net mode

_M.SYS_OVERLOAD         = 0x00020000
_M.SYS_UNDERLOAD        = 0x00010000
_M.SYS_ERR              = 0x00008000
_M.SYS_SETUP            = 0x00004000
_M.SYS_CALINPROG        = 0x00002000
_M.SYS_MOTION           = 0x00001000
_M.SYS_CENTREOFZERO     = 0x00000800
_M.SYS_ZERO             = 0x00000400
_M.SYS_NET              = 0x00000200

local REG_LUA_STATUS   = 0x0329
local REG_LUA_ESTAT    = 0x0305
local REG_LUA_STAT_RTC = 0x032A
local REG_LUA_STAT_RDG = 0x032B
local REG_LUA_STAT_IO  = 0x032C
local REG_SETPSTATUS   = 0x032E
local REG_LUA_STAT_NET = 0x030A

-- Status
_M.STAT_NET             = 0x00000001
_M.STAT_GROSS           = 0x00000002
_M.STAT_ZERO            = 0x00000004
_M.STAT_NOTZERO         = 0x00000008
_M.STAT_COZ             = 0x00000010
_M.STAT_NOTCOZ          = 0x00000020
_M.STAT_MOTION          = 0x00000040
_M.STAT_NOTMOTION       = 0x00000080
_M.STAT_RANGE1          = 0x00000100
_M.STAT_RANGE2          = 0x00000200
_M.STAT_PT              = 0x00000400
_M.STAT_NOTPT           = 0x00000800
_M.STAT_ERROR           = 0x00001000
_M.STAT_ULOAD           = 0x00002000
_M.STAT_OLOAD           = 0x00004000
_M.STAT_NOTERROR        = 0x00008000
-- Batching specific status bits
_M.STAT_IDLE            = 0x00010000
_M.STAT_RUN             = 0x00020000
_M.STAT_PAUSE           = 0x00040000
_M.STAT_SLOW            = 0x00080000
_M.STAT_MED             = 0x00100000
_M.STAT_FAST            = 0x00200000
_M.STAT_TIME            = 0x00400000
_M.STAT_INPUT           = 0x00800000
_M.STAT_NO_INFO         = 0x01000000
_M.STAT_FILL            = 0x02000000
_M.STAT_DUMP            = 0x04000000
_M.STAT_PULSE           = 0x08000000
_M.STAT_START           = 0x10000000
_M.STAT_NO_TYPE         = 0x20000000
_M.STAT_INIT            = 0x80000000

-- Extended status bits
_M.ESTAT_HIRES           = 0x00000001
_M.ESTAT_DISPMODE        = 0x00000006
_M.ESTAT_DISPMODE_RS     = 1
_M.ESTAT_RANGE           = 0x00000018
_M.ESTAT_RANGE_RS        = 3
_M.ESTAT_MENU_ACTIVE     = 0x00000020
_M.ESTAT_PROD_LOAD       = 0x00000040
_M.ESTAT_PROD_SAVE       = 0x00000080
_M.ESTAT_POWER_OFF       = 0x00000100
_M.ESTAT_INIT            = 0x01000000
_M.ESTAT_RTC             = 0x02000000
_M.ESTAT_RDG             = 0x04000000
_M.ESTAT_IO              = 0x08000000
_M.ESTAT_SER1            = 0x10000000
_M.ESTAT_SER2            = 0x20000000

local statBinds = {}
local statID = nil

local eStatBinds = {}
local eStatID = nil

local IOBinds = {}
local IOID = nil

local SETPBinds = {}
local SETPID = nil

local curStatus, curIO, curSETP

-------------------------------------------------------------------------------
-- Called when stream data is being renewed
-- @local
function private.renewStatusBinds()
    for _, v in pairs(IOBinds) do
        v.lastStatus = 0xFFFFFFFF
    end
    for _, v in pairs(SETPBinds) do
        v.lastStatus = 0xFFFFFFFF
    end
    for _, v in pairs(statBinds) do
        v.lastStatus = 0xFFFFFFFF
    end
    for _, v in pairs(eStatBinds) do
        v.lastStatus = 0xFFFFFFFF
    end
end

-------------------------------------------------------------------------------
-- Called when status changes are streamed
-- @param data Data on status streamed
-- @param err Potential error message
-- @local
local function statusCallback(data, err)
    curStatus = data
    for k,v in pairs(statBinds) do
       local status = bit32.band(data,k)
       if status ~= v.lastStatus  then
           if v.running then
               _M.dbg.warn('Status Event lost: ',string.format('%08X %08X',k,status))
           else
              v.running = true
              v.lastStatus = status
              v.f(k, status ~= 0)
              v.running = false
           end
        end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a status bit
-- @param stat STAT_ status bit
-- @param callback Function to run when there is an event on change in status
-- @usage
-- device.setStatusCallback(device.STAT_MOTION, function(stat, value) print('motion of', stat, 'is', value) end)
function _M.setStatusCallback(stat, callback)
    statBinds[stat] = {}
    statBinds[stat]['f'] = callback
    statBinds[stat]['lastStatus'] = 0xFF
end

-------------------------------------------------------------------------------
-- Called when IO status changes are streamed
-- @param data Data on SETP status streamed
-- @param err Potential error message
-- @local
local function IOCallback(data, err)
    curIO = data
    for k,v in pairs(IOBinds) do
       local status = bit32.band(data,k)
       if k == 0 then  --handle the all IO case
          status = curIO
       end
       if status ~= v.lastStatus  then
           if v.running then
               if k == 0 then
                   _M.dbg.warn('IO Event lost: ',v.IO,string.format('%08X',status))
               else
                   _M.dbg.warn('IO Event lost: ',v.IO,status ~=0)
               end
           else
              v.running = true
              v.lastStatus = status
              if k == 0 then
                  v.f(status)
              else
                  v.f(v.IO, status ~= 0)
              end
              v.running = false
           end
        end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a IO
-- @param IO 1..32
-- @param callback Function taking IO and on/off status as parameters
-- @usage
-- function handleIO1(IO, active)
--     if (active) then
--         print (IO,' is on!')
--     end
-- end
-- device.setIOCallback(1, handleIO1)
function _M.setIOCallback(IO, callback)
    local status = bit32.lshift(0x00000001, IO-1)
    if callback then
       IOBinds[status] = {}
       IOBinds[status]['IO'] = IO
       IOBinds[status]['f'] = callback
       IOBinds[status]['lastStatus'] = 0xFFFFFFFF
    else
        IOBinds[status] = nil
       _M.dbg.warn('','setIOCallback:  nil value for callback function')
    end
end

-------------------------------------------------------------------------------
-- Set a callback function that is called whenever any IO status changes
-- @param callback Function taking current IO status as a parameter
-- @usage
-- function handleIO(data)
--     -- 4 bits of status information for IO 3..6 turned into a grading indication
--     curGrade = bit32.rshift(bit32.band(data,0x03C),2)
-- end
-- device.setAllIOCallback(handleIO)
function _M.setAllIOCallback(callback)
    if callback ~= nil then
        IOBinds[0] = {}   -- setup a callback for all SETP changes
        IOBinds[0]['IO'] = 'All'
        IOBinds[0]['f'] = callback
        IOBinds[0]['lastStatus'] = 0xFFFFFF
    else
        IOBinds[0] = nil
       _M.dbg.warn('','setIOCallback:  nil value for all callback function')
    end
end

-------------------------------------------------------------------------------
-- Called when SETP status changes are streamed
-- @param data Data on SETP status streamed
-- @param err Potential error message
-- @local
local function SETPCallback(data, err)
    curSETP = bit32.band(data, 0xFFFF)
    for k,v in pairs(SETPBinds) do
       local status = bit32.band(data, k)
       if k == 0 then  --handle the all setp case
          status = curSETP
       end
       if status ~= v.lastStatus  then
           if v.running then
               if k == 0 then
                   _M.dbg.warn('SETP Event lost: ', v.SETP,string.format('%04X', status))
               else
                   _M.dbg.warn('SETP Event lost: ', v.SETP, status ~=0)
               end
           else
              v.running = true
              v.lastStatus = status
              if k == 0 then
                  v.f(status)
              else
                  v.f(v.SETP, status ~= 0)
              end
              v.running = false
           end
        end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for a SETP
-- @param SETP 1..16
-- @param callback Function taking SETP and on/off status as parameters
-- @usage
-- function handleSETP1(SETP, active)
--     if (active) then
--         print (SETP,' is on!')
--     end
-- end
-- device.setSETPCallback(1, handleSETP1)
function _M.setSETPCallback(SETP, callback)
    local status = bit32.lshift(0x00000001, SETP-1)
    SETPBinds[status] = {}
    SETPBinds[status]['SETP'] = SETP
    SETPBinds[status]['f'] = callback
    SETPBinds[status]['lastStatus'] = 0xFF
end

-------------------------------------------------------------------------------
-- Set a callback function that is called whenever any SETP status changes
-- @param callback Function taking current SETP status as a parameter
-- @usage
-- function handleSETP(data)
--     -- 4 bits of status information for SETP 3..6 turned into a grading indication
--     curGrade = bit32.rshift(bit32.band(data,0x03C),2)
-- end
-- device.setAllSETPCallback(handleSETP)
function _M.setAllSETPCallback(callback)
    SETPBinds[0] = {}   -- setup a callback for all SETP changes
    SETPBinds[0]['SETP'] = 'All'
    SETPBinds[0]['f'] = callback
    SETPBinds[0]['lastStatus'] = 0xFFFFFF
end

-------------------------------------------------------------------------------
-- Called when extended status changes are streamed
-- @param data Data on status streamed
-- @param err Potential error message
-- @local
local function eStatusCallback(data, err)
    _M.settings.hiRes       = bit32.band(data,_M.ESTAT_HIRES) > 0
    _M.settings.curDispMode = 1 + bit32.rshift(bit32.band(data,_M.ESTAT_DISPMODE),_M.ESTAT_DISPMODE_RS)
    _M.settings.curRange    = 1 + bit32.rshift(bit32.band(data,_M.ESTAT_RANGE),_M.ESTAT_RANGE_RS)

    for k,v in pairs(eStatBinds) do
        local status = bit32.band(data,k)
        if status ~= v.lastStatus  then
            if v.running then
                _M.dbg.warn('Ext Status Event lost: ',string.format('%08X',k),status ~= 0)
            else
                v.running = true
                v.lastStatus = status
                if v.mainf then
                    v.mainf(k,status ~= 0)
                end
                if v.f then
                    v.f(k, status ~= 0)
                end
                v.running = false
            end
         end
    end
end

-------------------------------------------------------------------------------
-- Set the callback function for an extended status bit
-- @param eStat ESTAT_ status bit
-- @param callback Function to run when there is an event on change in status
function _M.setEStatusCallback(eStat, callback)
    eStatBinds[eStat] = eStatBinds[eStat] or {}
    eStatBinds[eStat]['f'] = callback
    eStatBinds[eStat]['lastStatus'] = 0xFF
end

-------------------------------------------------------------------------------
-- Set the main library callback function for an extended status bit
-- @param eStat ESTAT_ status bit
-- @param callback Function to run when there is an event on change in status
function _M.setEStatusMainCallback(eStat, callback)
    eStatBinds[eStat] = eStatBinds[eStat] or {}
    eStatBinds[eStat]['mainf'] = callback
    eStatBinds[eStat]['lastStatus'] = 0xFF
end

-------------------------------------------------------------------------------
-- Called to get current instrument status
-- @return 32 bits of status data with bits as per STAT_ definitions
-- @usage
-- print('curnet status bits are', device.getCurStatus())
function _M.getCurStatus()
    return curStatus
end

-------------------------------------------------------------------------------
-- Called to check state of current instrument status
-- @return true if any of the status bits are set in current instrument status
-- @usage
-- device.enableOutput(5)
-- if device.anyStatusSet(device.STAT_MOTION,
--                     device.STAT_ERR,
--                     device.STAT_OLOAD,
--                     device.STAT_ULOAD) then
--     device.turnOn(5)  -- turn on output 5 if motion or any errors
-- else
--     device.turnOff(5)
-- end
function _M.anyStatusSet(...)
    if arg.n == 0 then
        return false
    end

    for i,v in ipairs(arg) do
        if bit32.band(curStatus, v) ~= 0 then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Called to check state of current instrument status
-- @return true if all of the status bits are set in cur instrument status
-- @usage
-- device.enableOutput(5)
-- if device.allStatusSet(device.STAT_NOTMOTION,
--                        device.STAT_NOTZERO,
--                        device.STAT_GROSS) then
--     device.turnOn(5)  -- turn on output 5 if stable gross weight not in zeroband
-- else
--     device.turnOff(5)
-- end
function _M.allStatusSet(...)
    if arg.n == 0 then
        return false
    end

    for i,v in ipairs(arg) do
        if bit32.band(curStatus, v) == 0 then
            return false
        end
    end
    return true
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO
-- @return 32 bits of IO data
-- @usage
-- print('curnet IO bits are', device.getCurIO())
function _M.getCurIO()
    return curIO
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO as a string of 1s and 0s
-- @param data The binary integer being converted
-- @param bits The number of significant bits in data
-- @return 32 characters of IO data
-- @local
local function getBitStr(data, bits)
    local s = {}
    for i = bits-1, 0, -1 do
        if bit32.band(data, bit32.lshift(0x01, i)) ~= 0 then
            ch = '1'
        else
            ch = '0'
        end
        table.insert(s,ch)
    end
    return table.concat(s)
end

-------------------------------------------------------------------------------
-- Called to get current state of the 32 bits of IO as a string of 1s and 0s
-- @return 32 characters of IO data
-- @usage
-- print('curnet IO bits are: ' .. device.getCurIOStr())
function _M.getCurIOStr()
    return getBitStr(curIO, 32)
end

-------------------------------------------------------------------------------
-- Called to check state of current IO
-- @return true if any of the listed IO are active
-- @usage
-- device.enableOutput(3)
-- if not device.anyIOSet(1,2,4,5) then
--     device.turnOn(3)  -- turn on output 3 if no other outputs on
-- else
--     device.turnOff(3)
-- end
function _M.anyIOSet(...)
    return anyBitSet(curIO,...)
end

-------------------------------------------------------------------------------
-- Called to check state of IO
-- @return true if all of the listed IO are active
-- @usage
-- device.enableOutput(3)
-- if device.allIOSet(1,2) then
--     device.turnOn(3)  -- turn on output 3 if IO 1 and 2 both on
-- else
--     device.turnOff(3)
-- end
function _M.allIOSet(...)
    return allBitSet(curIO,...)
end

-------------------------------------------------------------------------------
-- Called to get current state of the 16 setpoints
-- @return 16 bits of SETP status data
-- @usage
-- print('curnet setpoint bits are', device.getCurSETP())
function _M.getCurSETP()
    return curSETP
end

-------------------------------------------------------------------------------
-- Called to check state of current SETP
-- @return true if any of the listed SETP are active
-- @usage
-- device.enableOutput(1)
-- if not device.anySETPSet(1,2) then
--     device.turnOn(1)  -- turn on output 1 if setpoints 1 and 2 are both inactive
-- else
--     device.turnOff(1)
-- end
function _M.anySETPSet(...)
    return anyBitSet(curSETP,...)
end

-------------------------------------------------------------------------------
-- Called to check state of SETP
-- @return true if all of the listed IO are active
-- @usage
-- device.enableOutput(1)
-- if device.allSETPSet(1,2) then
--     device.turnOn(1)  -- turn on output 1 if Setpoints 1 and 2 are active
-- else
--     device.turnOff(1)
-- end
function _M.allSETPSet(...)
    return(allBitSet(curSETP,...))
end

-------------------------------------------------------------------------------
-- Wait until selected status bits are true
-- @usage
-- device.waitStatus(device.STAT_NOTMOTION)  -- wait for no motion
-- device.waitStatus(device.STAT_COZ)        -- wait for Centre of zero
-- device.waitStatus(device.STAT_ZERO, device.STAT_NOTMOTION) -- wait for no motion and zero
function _M.waitStatus(...)
    local stat = bit32.bor(...)
    while bit32.band(curStatus, stat) ~= stat do
        _M.system.handleEvents()
    end
end

-------------------------------------------------------------------------------
-- Wait until IO is in a particular state
-- @param IO 1..32
-- @param state true to wait for IO to come on or false to wait for it to go off
-- @usage
-- device.waitIO(1, true) -- wait until IO1 turns on
function _M.waitIO(IO, state)
    local mask = bit32.lshift(0x00000001,(IO-1))
    while _M.app.running do
        local data = bit32.band(curIO, mask)
        if (state and data ~= 0) or (not state and data == 0) then
            break
        end
        _M.system.handleEvents()
    end
end

-------------------------------------------------------------------------------
-- Wait until SETP is in a particular state
-- @param SETP 1..16
-- @param state true to wait for SETP to come on or false to wait for it to go off
-- @usage
-- device.waitSETP(1, true) -- wait until Setpoint 1 turns on
function _M.waitSETP(SETP, state)
    local mask = bit32.lshift(0x00000001,(SETP-1))
    while _M.app.running do
        local data = bit32.band(curSETP, mask)
        if (state and data ~= 0) or (not state and data == 0) then
            break
        end
        _M.system.handleEvents()
    end
end

-------------------------------------------------------------------------------
-- Control the use of RTC status bit.
-- The RTC status is enabled as part of the normal initialisation process
-- for the application framework.  You shouldn't need to call this and if
-- in doubt don't.
-- @param s true to enable RTC change monitoring, false to disable
-- @usage
-- device.writeRTCStatus(true)  -- enable RTC monitoring
-- device.writeRTCStatus(false) -- disable RTC monitoring
function _M.writeRTCStatus(s)
    _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_LUA_STAT_RTC, s == false and 0 or 1)
end

-------------------------------------------------------------------------------
-- Process a RTC update tick
-- @param status Status
-- @param active Active?
-- @local
local function handleRTC(status, active)
    private.RTCtick()
end

-------------------------------------------------------------------------------
-- Process initialisation status message
-- @param status Status
-- @param active Active?
-- @local
local function handleINIT(status, active)
--   _M.dbg.info('INIT',string.format('%08X',status),active)
--   if active then
--       _M.readSettings()
--       _M.RTCread()
--   end
end

-------------------------------------------------------------------------------
-- Control the use of Net status bits
-- @param s net1, net2, both or none
-- @usage
-- device.writeNetStatus('net1')
-- device.writeNetStatus('none')
-- device.writeNetStatus('both')
function _M.writeNetStatus(s)
    if type(s) == 'string' then
        s = ({ net1 = 1, net2 = 2, both = 3, none = 0, ["1"] = 1, ["2"] = 2 })[s]
    end
    _M.sendRegWait(_M.CMD_WRFINALHEX, _M.REG_LUA_STAT_NET, s or 0)
end

-------------------------------------------------------------------------------
-- Setup status monitoring via a stream.
-- This routine is called automatically by the rinApp application framework.
-- @usage
-- device.setupStatus()
function _M.setupStatus()
    curStatus = 0
    statID  = _M.addStreamLib(_M.REG_LUA_STATUS, statusCallback,  'change')
    eStatID = _M.addStreamLib(_M.REG_LUA_ESTAT,  eStatusCallback, 'change')
    IOID    = _M.addStreamLib(_M.REG_IO_STATUS,  IOCallback,      'change')
    SETPID  = _M.addStreamLib(_M.REG_SETPSTATUS, SETPCallback,    'change')
    _M.RTCread()
    _M.setEStatusMainCallback(_M.ESTAT_RTC,  handleRTC)
    _M.setEStatusMainCallback(_M.ESTAT_INIT, handleINIT)
    _M.writeRTCStatus(true)
end

-------------------------------------------------------------------------------
-- Cancel status handling
-- There is typically no need to ever call this.
-- @usage
-- device.endStatus()
function _M.endStatus()
    _M.removeStreamLib(statID)
    _M.removeStreamLib(eStatID)
    _M.removeStreamLib(IOID)
    _M.removeStreamLib(SETPID)
end

-------------------------------------------------------------------------------
-- Cancel IO status handling
-- There is typically no need to ever call this.
-- @usage
-- device.endIOStatus()
function _M.endIOStatus()
    _M.removeStreamLib(IOID)
end

-------------------------------------------------------------------------------
-- Cancel SETP status handling
-- There is typically no need to ever call this.
-- @usage
-- device.endSETPStatus()
function _M.endSETPStatus()
    _M.removeStreamLib(SETPID)
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Fill in all the depricated fields
depricated.REG_LUA_STATUS   = REG_LUA_STATUS
depricated.REG_LUA_ESTAT    = REG_LUA_ESTAT
depricated.REG_LUA_STAT_RTC = REG_LUA_STAT_RTC
depricated.REG_LUA_STAT_RDG = REG_LUA_STAT_RDG
depricated.REG_LUA_STAT_IO  = REG_LUA_STAT_IO
depricated.REG_SETPSTATUS   = REG_SETPSTATUS
depricated.REG_LUA_STAT_NET = REG_LUA_STAT_NET

end
