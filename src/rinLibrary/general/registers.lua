-------------------------------------------------------------------------------
-- Holds the L401 registers
-- @module registers
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local _M = {}

-- Addresses control bits
_M.ADDR_RESP 			= 0x80
_M.ADDR_ERR 		    = 0x40
_M.ADDR_REPLY			= 0x20
_M.ADDR_NOREPLY			= 0x00
_M.ADDR_BROADCAST		= 0x00

-- Commands
_M.CMD_RDLIT			= 0x05
_M.CMD_RDFINALHEX		= 0x11
_M.CMD_RDFINALDEC		= 0x16
_M.CMD_WRFINALHEX 		= 0x12
_M.CMD_WRFINALDEC 		= 0x17
_M.CMD_EX 				= 0x10

--	System
_M.REG_SOFTMODEL		= 0x0003
_M.REG_SOFTVER			= 0x0004
_M.REG_SERIALNO			= 0x0005
_M.REG_KEYBUFFER		= 0x0008
_M.REG_LCD				= 0x0009

_M.REG_SAVESETTING		= 0x0010
_M.REG_FULLPASS			= 0x0019
_M.REG_SAFEPASS			= 0x001A

_M.REG_ADCSAMPLE		= 0x0020
_M.REG_SYSSTATUS		= 0x0021
_M.REG_SYSERR			= 0x0022
_M.REG_ABSMVV			= 0x0023
_M.REG_UNUSED			= 0x0024

_M.SYS_OVERLOAD			= 0x00020000
_M.SYS_UNDERLOAD		= 0x00010000
_M.SYS_ERR				= 0x00008000
_M.SYS_SETUP			= 0x00004000
_M.SYS_CALIBINPROG		= 0x00002000
_M.SYS_MOTION			= 0x00001000
_M.SYS_CENTREOFZERO		= 0x00000800
_M.SYS_ZERO				= 0x00000400
_M.SYS_NET				= 0x00000200

--	Weight
_M.REG_GROSSNET			= 0x0025
_M.REG_GROSS			= 0x0026
_M.REG_NET				= 0x0027
_M.REG_TARE				= 0x0028
_M.REG_PEAKHOLD			= 0x0029
_M.REG_MANHOLD			= 0x002A
_M.REG_GRANDTOT			= 0x002B
_M.REG_ALTGROSS			= 0x002C
_M.REG_RAWADC			= 0x002D
_M.REG_ALTNET			= 0x002E
_M.REG_FULLSCALE		= 0x002F

_M.REG_GROSS_CNT        = 0x0149
_M.REG_NET_CNT          = 0x014A


-- USER VARIABLES
_M.REG_USERID_NAME1		= 0x0080
_M.REG_USERID_NAME2		= 0x0081
_M.REG_USERID_NAME3		= 0x0082
_M.REG_USERID_NAME4		= 0x0083
_M.REG_USERID_NAME5		= 0x0084
_M.REG_USERNUM_NAME1	= 0x0316
_M.REG_USERNUM_NAME2	= 0x0317
_M.REG_USERNUM_NAME3	= 0x0318
_M.REG_USERNUM_NAME4	= 0x0319
_M.REG_USERNUM_NAME5	= 0x031A

_M.REG_USERID1			= 0x0090
_M.REG_USERID2			= 0x0092
_M.REG_USERID3			= 0x0093
_M.REG_USERID4			= 0x0094
_M.REG_USERID5			= 0x0095
_M.REG_USERNUM1			= 0x0310
_M.REG_USERNUM2			= 0x0311
_M.REG_USERNUM3			= 0x0312
_M.REG_USERNUM4			= 0x0313
_M.REG_USERNUM5			= 0x0314

-- Commands
_M.REG_ADC_ZERO         = 0x0300                  -- Execute registers
_M.REG_ADC_TARE         = 0x0301                  
_M.REG_ADC_PT           = 0x0302                  -- Tare value is parameter 
_M.REG_ADC_GROSS_NET    = 0x0303                 

_M.ADCGN_TOGGLE			= 0
_M.ADCGN_GROSS			= 1
_M.ADCGN_NET			= 2

_M.REG_ADC_HI_RES       = 0x0304                   
_M.ADCHIRES_TOGGLE		= 0
_M.ADCHIRES_ON			= 1
_M.ADCHIRES_OFF			= 2
_M.ADCHIRES_DB			= 3                       -- R420 database setting

-- 	Calibrate
_M.REG_CALIBWGT			= 0x0100
_M.REG_CALIBZERO		= 0x0102
_M.REG_CALIBSPAN		= 0x0103
_M.REG_CALIBLIN			= 0x0104
_M.REG_CLRLIN			= 0x0105
_M.REG_CALIBDIRZERO 	= 0x0106
_M.REG_CALIBDIRSPAN		= 0x0107

-- 	Time and Date
_M.REG_TIMECUR			= 0x0150
_M.REG_TIMEFORMAT		= 0x0151
_M.REG_TIMEDAY			= 0x0152
_M.REG_TIMEMON			= 0x0153
_M.REG_TIMEYEAR			= 0x0154
_M.REG_TIMEHOUR			= 0x0155
_M.REG_TIMEMIN			= 0x0156
_M.REG_TIMESEC			= 0x0157
_M.TM_MMDDYYYY			= 0
_M.TM_DDMMYYYY			= 1

--	Errors
_M.ERR_UNKNOWN			= 0xC000
_M.ERR_NOTIMPLMN		= 0xA000
_M.ERR_ACCESSDENIED		= 0x9000
_M.ERR_DATAUNDRNG		= 0x8800
_M.ERR_ILLVALUE			= 0x8200
_M.ERR_ILLOP			= 0x8100
_M.ERR_BADPARAM			= 0x8040
_M.ERR_MENUINUSE		= 0x8020
_M.ERR_VIEWMODEREQ		= 0x8010
_M.ERR_CHECKSUMREQ		= 0x8008

_M.errStrings = 
{
  [0xC000] = "Unknown error",
  [0xA000] = "Feature not implemented",
  [0x9000] = "Access denied",
  [0x8800] = "Data under range",
  [0x8400] = "Data over range",
  [0x8200] = "Illegal value",
  [0x8100] = "Illegal operation",
  [0x8040] = "Bad parameter",--	Errors
  [0x8020] = "Menu in use",
  [0x8010] = "Viewer mode required",
  [0x8008] = "Checksum required"
}



return _M