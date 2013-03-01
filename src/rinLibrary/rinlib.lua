-------------------------------------------------------------------------------
-- Holds functions useful for dealing with L401 devices.
-- @module rinlib
-- @author Merrick Heley
-- @copyright 2013 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local socket = require "socket"
local bit32 = require "bit"

local str = string
local table = table
local assert = assert
local tonum = tonumber

local _M = {}

-- Constants --

-- Addresses
_M.ADDR_RESP 			= 0x80
_M.ADDR_ERR 			= 0x40
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

-- Registers
--	System
_M.REG_SOFTMODEL		= 0x0003
_M.REG_SOFTVER			= 0x0004
_M.REG_SERIALNO			= 0x0005
_M.REG_KEYBUFFER		= 0x0008
_M.REG_LCD				= 0x0009
_M.REG_2NDDISPLEFT 		= 0x000E
_M.REG_2NDDISPRIGHT 	= 0x000F
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

--	Tracing
_M.REG_TRCWGTAVAIL		= 0x0030
_M.REG_TRCID			= 0x0031
_M.REG_TRCWGT			= 0x0032
_M.REG_TRCWGTALT		= 0x0033
_M.REG_TRCWGTP			= 0x0034
_M.REG_TRCTAREWGT		= 0x0035
_M.REG_TRCPT			= 0x0036
_M.REG_TRCYEAR			= 0x0037
_M.REG_TRCMONTH			= 0x0038
_M.REG_TRCDAY			= 0x0039
_M.REG_TRCHOUR			= 0x003A
_M.REG_TRCMIN			= 0x003B
_M.REG_TRCSEC			= 0x003C
_M.TRC_NOTRCWGT			= 0
_M.TRC_VLDTRCWGT		= 1
_M.TRC_NOTARE			= 0
_M.TRC_PRESETTARE		= 1

--	Stream
_M.REG_STREAMDATA		= 0x0040
_M.REG_STREAMMODE		= 0x0041
_M.REG_STREAMREG1		= 0x0042
_M.REG_STREAMREG2		= 0x0043
_M.REG_STREAMREG3		= 0x0044
_M.REG_STREAMREG4		= 0x0045
_M.REG_STREAMREG5		= 0x0046
_M.REG_LUA				= 0x0300	--NOTE: This should be binary or'd with the other stream registers
_M.STM_START			= 1
_M.STM_STOP				= 0
_M.STM_FREQ_MANUAL		= 0
_M.STM_FREQ_AUTO		= 1
_M.STM_FREQ_AUTO10		= 2
_M.STM_FREQ_AUTO3		= 3
_M.STM_FREQ_AUTO1		= 4
_M.STM_FREQ_ONCHANGE	= 5
_M.STM_REG_ADCSAMPLE	= 1
_M.STM_REG_SYSSTATUS	= 2
_M.STM_REG_SYSERR		= 2
_M.STM_REG_ABSMVV		= 4
_M.STM_REG_UNUSED		= 5
_M.STM_REG_GROSSNET		= 6
_M.STM_REG_GROSS		= 7
_M.STM_REG_NET			= 8
_M.STM_REG_TARE			= 9
_M.STM_REG_PEAKHOLD		= 10
_M.STM_REG_MANHOLD		= 11
_M.STM_REG_GRANDTOT		= 12
_M.STM_REG_ALTGROSS		= 13
_M.STM_REG_RAWADC		= 14
_M.STM_REG_ALTNET		= 15
_M.STM_REG_FULLSCALE	= 16
_M.STM_REG_17			= 17

-- 	WHAT SHOULD I BE CALLED?
_M.REG_PRNTTKNSTR		= 0x004C
_M.REG_RPLYTKNSTR		= 0x004D
_M.REG_RPLYREG			= 0x004E
_M.REG_RPLYSTREAMID		= 0x004F

-- 	WHAT SHOULD I BE CALLED?
_M.REG_IOSTATUS			= 0x0051
_M.REG_PIECEWEIGHT		= 0x0053
_M.REG_CONSECPRNTID		= 0x007A
_M.REG_USERID1			= 0x0090
_M.REG_USERID2			= 0x0092
_M.REG_USERID3			= 0x0093
_M.REG_USERID4			= 0x0094
_M.REG_USERID5			= 0x0095

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

--	Session Information
_M.REG_SETOTWGT			= 0x0210
_M.REG_SETOTWGTALT		= 0x0211
_M.REG_SETOTPIECE		= 0x0212
_M.REG_SETOTNUM			= 0x0213

-- 	Grand Total Information
_M.REG_GTWGT			= 0x0220
_M.REG_GTWGTALT			= 0x0221
_M.REG_GTPIECE			= 0x0222
_M.REG_GTNUM			= 0x0223

--	DSD
_M.REG_DSDCLRAUTO		= 0x8290
_M.REG_DSDREAD			= 0x8291
_M.REG_DSDREADNXT		= 0x8292
_M.REG_DSDREADPRV		= 0x8293
_M.REG_DSDREADOLD		= 0x8294
_M.REG_DSDREADNEW		= 0x8295
_M.REG_DSDCLR			= 0x8296
_M.DSD_NOWRITEOVER		= 0
_M.DSD_WRITEOVER		= 1

-- 	Active Product
_M.REG_ACTPRD			= 0xB000
_M.REG_CLRALLTOT		= 0xB002
_M.REG_CLRSETOT			= 0xB003
_M.REG_CLRDCKTOT		= 0xB004

--	Select Product	
_M.REG_SPNAME			= 0xB00F
_M.REG_SPNUM			= 0xB010
_M.REG_SPDEL			= 0xB011
_M.REG_SPRENAME 		= 0xB012
_M.REG_SPNAME			= 0xB013
_M.REG_SPTARE			= 0xB015
_M.REG_SPSAMSZ			= 0xB016
_M.REG_SPSAMWGT 		= 0xB017
_M.REG_SPPCWGT			= 0xB018
_M.REG_SPAUCF			= 0xB019
_M.REG_SPTAR1			= 0xB080
_M.REG_SPTAR2			= 0xB081
_M.REG_SPTAR3			= 0xB082
_M.REG_SPTAR4			= 0xB083
_M.REG_SPTAR5			= 0xB084
_M.REG_SPTAR6			= 0xB085
_M.REG_SPTAR7			= 0xB086
_M.REG_SPTAR8			= 0xB087
_M.REG_SPTOTWGT 		= 0xB102
_M.REG_SPTOTWGTALT		= 0xB103
_M.REG_SPTOTPIECE		= 0xB104
_M.REG_SPTOTNUM			= 0xB105
_M.REG_SPDKTOTWGT 		= 0xB180
_M.REG_SPDKTOTWGTALT	= 0xB181
_M.REG_SPDKTOTPIECE		= 0xB182
_M.REG_SPDKTOTNUM		= 0xB183

--Lua key handling
_M.REG_GET_KEY			= 0x0321
_M.REG_FLUSH_KEYS		= 0x0322
_M.REG_APP_DO_KEYS		= 0x0324
_M.REG_APP_KEY_HANDLER	= 0x0325

--LCD display registers
_M.REG_DISP_BOTTOM_LEFT		= 0x000E	-- Takes string
_M.REG_DISP_BOTTOM_RIGHT 	= 0x000F	-- Takes string
_M.REG_DISP_TOP_LEFT		= 0x00A0	-- Takes string
_M.REG_DISP_TOP_RIGHT		= 0x00A1	-- Takes string
_M.REG_DISP_TOP_ANNUN		= 0x00A2
_M.REG_DISP_TOP_UNIT		= 0x00A3	-- Takes string
_M.REG_DISP_BOTTOM_ANNUN	= 0x00A4
_M.REG_DISP_BOTTOM_UNITS	= 0x00A5
_M.REG_DISP_AUTO_TOP_ANNUN	= 0x00A6	-- Register number
_M.REG_DISP_AUTO_TOP_LEFT	= 0x00A7	-- Register number
_M.REG_DISP_AUTO_BOTTOM_LEFT= 0x00A8	-- Register number

_M.APPLIC_SHOW_TOP_ANNUN_SIGMA			= 0x00001
_M.APPLIC_SHOW_TOP_ANNUN_BALANCE		= 0x00002
_M.APPLIC_SHOW_TOP_ANNUN_COZ			= 0x00004
_M.APPLIC_SHOW_TOP_ANNUN_HOLD			= 0x00008
_M.APPLIC_SHOW_TOP_ANNUN_MOTION			= 0x00010
_M.APPLIC_SHOW_TOP_ANNUN_NET			= 0x00020
_M.APPLIC_SHOW_TOP_ANNUN_RANGE			= 0x00040
_M.APPLIC_SHOW_TOP_ANNUN_ZERO			= 0x00080
_M.APPLIC_SHOW_TOP_ANNUN_BAL_SEG_A		= 0x00100
_M.APPLIC_SHOW_TOP_ANNUN_BAL_SEG_B		= 0x00200
_M.APPLIC_SHOW_TOP_ANNUN_BAL_SEG_C		= 0x00400
_M.APPLIC_SHOW_TOP_ANNUN_BAL_SEG_D		= 0x00800
_M.APPLIC_SHOW_TOP_ANNUN_BAL_SEG_E		= 0x01000
_M.APPLIC_SHOW_TOP_ANNUN_BAL_SEG_F		= 0x02000
_M.APPLIC_SHOW_TOP_ANNUN_BAL_SEG_G		= 0x04000
_M.APPLIC_SHOW_TOP_ANNUN_RNG_SEG_ADG	= 0x08000
_M.APPLIC_SHOW_TOP_ANNUN_RNG_SEG_C		= 0x10000
_M.APPLIC_SHOW_TOP_ANNUN_RNG_SEG_E		= 0x20000

_M.APPLIC_SHOW_BOTTOM_ANNUN_BATTERY		= 0x001
_M.APPLIC_SHOW_BOTTOM_ANNUN_CLOCK		= 0x002
_M.APPLIC_SHOW_BOTTOM_ANNUN_BAT_BOT		= 0x004
_M.APPLIC_SHOW_BOTTOM_ANNUN_BAT_MID_BOT	= 0x008
_M.APPLIC_SHOW_BOTTOM_ANNUN_BAT_MID_TOP	= 0x010
_M.APPLIC_SHOW_BOTTOM_ANNUN_BAT_TOP		= 0x020
_M.APPLIC_SHOW_BOTTOM_ANNUN_WAIT_0		= 0x040
_M.APPLIC_SHOW_BOTTOM_ANNUN_WAIT_135	= 0x080
_M.APPLIC_SHOW_BOTTOM_ANNUN_WAIT_45		= 0x100
_M.APPLIC_SHOW_BOTTOM_ANNUN_WAIT_90		= 0x200

--	Errors
_M.ERR_UNKNOWN			= 0xC000
_M.ERR_NOTIMPLMN		= 0xA000
_M.ERR_ACCESSDENIED		= 0x9000
_M.ERR_DATAUNDRNG		= 0x8800
_M.ERR_DATAOVRRNG		= 0x8400
_M.ERR_ILLVALUE			= 0x8200
_M.ERR_ILLOP			= 0x8100
_M.ERR_BADPARAM			= 0x8040
_M.ERR_MENUINUSE		= 0x8020
_M.ERR_VIEWMODEREQ		= 0x8010
_M.ERR_CHECKSUMREQ		= 0x8008

-- Keys
_M.KEY_0				= 0x0000
_M.KEY_1				= 0x0001
_M.KEY_2				= 0x0002
_M.KEY_3				= 0x0003
_M.KEY_4				= 0x0004
_M.KEY_5				= 0x0005
_M.KEY_6				= 0x0006
_M.KEY_7				= 0x0007
_M.KEY_8				= 0x0008
_M.KEY_9				= 0x0009
_M.KEY_POWER			= 0x000A
_M.KEY_ZERO				= 0x000B
_M.KEY_TARE				= 0x000C
_M.KEY_GN				= 0x000D
_M.KEY_F1				= 0x000E
_M.KEY_F2				= 0x000F
_M.KEY_F3				= 0x0010
_M.KEY_PLUSMINUS		= 0x0011
_M.KEY_DP				= 0x0012
_M.KEY_CANCEL			= 0x0013
_M.KEY_UP				= 0x0014
_M.KEY_DOWN				= 0x0015
_M.KEY_OK				= 0x0016
_M.KEY_SETUP			= 0x0017
_M.KEY_IO1				= 0x0020
_M.KEY_IO2				= 0x0021
_M.KEY_IO3				= 0x0022
_M.KEY_IO4				= 0x0023
_M.KEY_IO5				= 0x0024
_M.KEY_IO6				= 0x0025
_M.KEY_IO7				= 0x0026
_M.KEY_IO8				= 0x0027
_M.KEY_IO9				= 0x0028
_M.KEY_IO10				= 0x0029
_M.KEY_IO11				= 0x002A
_M.KEY_IO12				= 0x002B
_M.KEY_IO13				= 0x002C
_M.KEY_IO14				= 0x002D
_M.KEY_IO15				= 0x002E
_M.KEY_IO16				= 0x002F
_M.KEY_IO17				= 0x0030
_M.KEY_IO18				= 0x0031
_M.KEY_IO19				= 0x0032
_M.KEY_IO20				= 0x0033
_M.KEY_IO21				= 0x0034
_M.KEY_IO22				= 0x0035
_M.KEY_IO23				= 0x0036
_M.KEY_IO24				= 0x0037
_M.KEY_IO25				= 0x0038
_M.KEY_IO26				= 0x0039
_M.KEY_IO27				= 0x003A
_M.KEY_IO28				= 0x003B
_M.KEY_IO29				= 0x003C
_M.KEY_IO30				= 0x003D
_M.KEY_IO31				= 0x003E
_M.KEY_IO32				= 0x003F

-------------------------------------------------------------------------------
-- Receive a message from a socket.
-- Receives one byte at a time, and ends the message based on specified 
-- delimiters
-- @param socket Socket to read data from
-- @param buffer Table containing a string in characters, one entry per char
-- @return A string bounded by delimiters (nil if error)
-- @return An error message (nil if no error)
function _M.recMsg(socket)
	local char, prevchar, error, tabStr
	local buffer = {}

	while true do
		prevchar = char
		char, error = socket:receive(1)

		if error then break end
		
		if char == '' then
			buffer = {}
		end

		table.insert(buffer,char)

		-- Check for delimiters.
		if buffer[1] == '' then
			if char == '' then
				break
			end
		elseif (prevchar == '\r' and char == '\n') or char == ';' then
			break
		end
	end
	
	if error == nil then
		return table.concat(buffer), nil
	end

	return tabStr, error
end

-------------------------------------------------------------------------------
-- Creates a CRC-CCITT (0xFFFF) of the given ASCII data
-- @param message Message to be processed
-- @return CRC-CCITT (0xFFFF) of message
function _M.CCITT(data)
	local poly = 0x1021
	local crc = 0xffff
	
	for c = 1, #data do
		char = string.byte(data, c)
		local x = bit32.band(bit32.bxor(bit32.arshift(crc, 8), char), 0xFF)
		x = bit32.bxor(x, bit32.arshift(x, 4))
		crc = bit32.band(bit32.bxor(crc*2^8, x*2^12, x*2^5, x), 0xFFFF)
	end
	
	return crc
end

-------------------------------------------------------------------------------
-- Processes the message and feeds back the individual parts
-- @param msg Message to be processed
-- @return Indicator address (0x00 to 0x1F)
-- @return addr name (ADDR_*)
-- @return command	(CMD_*)
-- @return register	(REG_*)
-- @return data
-- @return error
function _M.processMsg(msg)
	local validDelim = nil
	local newMsg
	local ind, addr, cmd, reg, data
	
	if msg == nil then
		return nil, nil, nil, nil, nil, "msg was nil"
	end
	
	if str.sub(msg,1,1) == '' then
		if str.sub(msg,-1,-1) == '' then
			validDelim = "CRC"
			newMsg = str.sub(msg, 2, -6)	
		end
	
	elseif str.sub(msg, -2, -1) == '\r\n' then
		validDelim = "NORM"
		newMsg = str.sub(msg, 1, -3)
	
	elseif str.sub(msg,-1,-1) == ';' then
		validDelim = "NORM"
		newMsg = str.sub(msg, 1, -2)
	end
	
	if validDelim == nil then 
		return nil, nil, nil, nil, nil, "bad delimiters" 
		
	elseif validDelim == "CRC" 
			and str.sub(msg,-5,-2) == _M.CCITT(newMsg) then
		return nil, nil, nil, nil, nil, "bad crc"
	end
	
	local semiPos = string.find(msg, ':')
	
	if semiPos == nil then
		return nil, nil, nil, nil, nil, "no separator found"
	end
	
	addr = tonum(str.sub(newMsg, 1, 2), 16)
	cmd = tonum(str.sub(newMsg,3,4), 16)
	reg = tonum(str.sub(newMsg, 5, 8), 16)
	data = str.sub(newMsg, semiPos+1, -1)
	
	if not (addr and cmd and reg and data) then
		return nil, nil, nil, nil, nil, "non-hex msg"
	end
	
	ind = bit32.band(addr, 0x0F)
	addr = bit32.band(addr, 0xF0)
	
	if bit32.band(addr, _M.ADDR_ERR) == _M.ADDR_ERR then
		return nil, nil, nil, nil, data, "device returned error" 
	end
	
	return ind, addr, cmd, reg, data
	
end

return _M