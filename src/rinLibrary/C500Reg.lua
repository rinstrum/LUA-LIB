-------------------------------------------------------------------------------
--- Register Functions.
-- Functions to read, write and execute commands on instrument registers directly
-- @module rinLibrary.Device.Reg
-- @author Darren Pearson
-- @author Merrick Heley
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local string = string
local tonumber = tonumber
local powersOfTen = require "rinLibrary.powersOfTen"
local timers = require 'rinSystem.rinTimers'
local system = require 'rinSystem'
local dbg = require "rinLibrary.rinDebug"
local rinMsg = require 'rinLibrary.rinMessage'
local canonical = require('rinLibrary.namings').canonicalisation
local bit32 = require "bit"

local lpeg = require "rinLibrary.lpeg"
local space, digit, P, S = lpeg.space, lpeg.digit, lpeg.P, lpeg.S
local math = math

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

private.addRegisters{
    none                    = 0         -- not a register
}

private.registerDeviceInitialiser(function()
    private.addRegisters{
--- Instrument Reading Registers.
--@table rdgRegisters
-- @field adcsample Sample number of current reading
-- @field sysstatus System Status Bits
-- @field syserr System Error Bits
-- @field absmvv Absolute mV/V reading (10,000 = 1mV/V)
-- @field grossnet Gross or Net reading depending on operating mode
-- @field gross Gross weight
-- @field net Net Weight
-- @field tare Tare Weight
-- @field peakhold Peak Hold Weight
-- @field manhold Manually Held weight
-- @field grandtotal Accumulated total
-- @field altgross Gross weight in secondary units
-- @field rawadc Raw ADC reading (2,560,000 = 1.0 mV/V)
-- @field altnet Net weight in secondary units
-- @field fullscale Fullscale weight
-- @field piececount Piece count
-- @field tracevalid Is the traceable weight valid
-- @field traceid Traceable weight unique id
-- @field traceweight Traceable weight
-- @field traceweightalt Alternate traceable weight
-- @field tracetare Tare weight associated with traceable weight
-- @field tracept Traceable preset tare flag
-- @field traceyear Date and time that the traceable weight was acquired
-- @field tracemonth Date and time that the traceable weight was acquired
-- @field traceday Date and time that the traceable weight was acquired
-- @field tracehour Date and time that the traceable weight was acquired
-- @field traceminute Date and time that the traceable weight was acquired
-- @field tracesecond Date and time that the traceable weight was acquired
-- @field piececount Number of pieces corresponding to the current weight
        adcsample               = 0x0020,
--        sysstatus               = 0x0021,
--        syserr                  = 0x0022,
        absmvv                  = 0x0023, 
        grossnet                = 0x0025,
        gross                   = 0x0026,
        net                     = 0x0027,
        tare                    = 0x0028,
        peakhold                = 0x0029,
--        manhold                 = 0x002A,
--        grandtotal              = 0x002B,
--        altgross                = 0x002C,
        rawadc                  = 0x002D,
--        altnet                  = 0x002E,
        fullscale               = 0x002F,
        tracevalid              = 0x0030,
        traceid                 = 0x0031,
        traceweight             = 0x0032,
        traceweightalt          = 0x0033,
        tracetare               = 0x0035,
        tracept                 = 0x0036,
        traceyear               = 0x0037,
        tracemonth              = 0x0038,
        traceday                = 0x0039,
        tracehour               = 0x003A,
        traceminute             = 0x003B,
        tracesecond             = 0x003C,
--        piececount              = 0x0053,
    }
end)

end
