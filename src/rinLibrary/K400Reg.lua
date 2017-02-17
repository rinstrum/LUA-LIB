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
-- @field bitmap Bitmap of display
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
-- @field unfiltered_weight Raw weight readings
        bitmap                  = 0x0009,
        adcsample               = 0x0020,
        sysstatus               = 0x0021,
        syserr                  = 0x0022,
        absmvv                  = 0x0023, 
        grossnet                = 0x0025,
        gross                   = 0x0026,
        net                     = 0x0027,
        tare                    = 0x0028,
        peakhold                = private.nonbatching(0x0029),
        manhold                 = private.nonbatching(0x002A),
        grandtotal              = 0x002B,
        altgross                = private.nonbatching(0x002C),
        rawadc                  = 0x002D,
        altnet                  = private.nonbatching(0x002E),
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
        piececount              = private.nonbatching(0x0053),
        unfiltered_weight       = private.k422(0x0055),

--- Product Registers.
--@table productRegisters
-- @field active_product_no Read the Active Product Number, Write to set the active product by number
-- @field active_product_name Read the Active Product Name, Write to set Active Product by name
-- @field clr_all_totals Clears all product totals (EXECUTE)
-- @field clr_docket_totals Clears all docket sub-totals (EXECUTE)
-- @field select_product_no Read the Selected Product Number, Write to set the Selected product by number
-- @field select_product_name Read the Selected Product Name, Write to set the Selected product by Name
-- @field select_product_delete Delete Selected Product, totals must be 0 (EXECUTE)
-- @field select_product_rename Execute with a string as an argument to change name of selected product (EXECUTE)
-- @field product_total_weight ?
-- @field product_total_alt_weight ?
-- @field product_total_count ?
-- @field product_total_number ?
-- @field docket_total ?
        active_product_no       = 0xB000,
        active_product_name     = 0xB006,
        clr_all_totals          = 0xB002,
        clr_docket_totals       = 0xB004,
        select_product_no       = 0xB00F,
        select_product_name     = 0xB010,
        select_product_delete   = 0xB011,
        select_product_rename   = 0xB012,

        product_total_weight    = 0xB102,
        product_total_alt_weight= 0xB103,
        product_total_count     = 0xB104,
        product_total_number    = 0xB105,

        docket_total            = 0xB180,
    }
end)

end
