-------------------------------------------------------------------------------
-- Network support for tests.
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local rinApp = require "rinApp"
local ftp = require "socket.ftp"
local posix = require "posix"

local _M = {}

_M.upperIPaddress = 'm4223testbox-upper.rinstrumau.local' -- '172.17.1.26'
_M.lowerIPaddress = 'm4223testbox-lower.rinstrumau.local' -- '172.17.1.27'
_M.upperPort = 2222
_M.lowerPort = 2222
_M.username = 'root'
_M.password = 'root'

-------------------------------------------------------------------------------
-- Open connections to two K400 units.
-- @param upper The address of the upper unit (default upperIPaddress)
-- @param lower The address of the lower unit (default lowerIPaddress)
-- @return Upper unit device
-- @return Lower unit device
function _M.openDevices(upper, lower)
    upper = upper or _M.upperIPaddress
    lower = lower or _M.lowerIPaddress

    upperDevice = rinApp.addK400("K401", upper, _M.upperPort)
    lowerDevice = rinApp.addK400("K401", lower, _M.lowerPort)

    return upperDevice, lowerDevice
end

-------------------------------------------------------------------------------
-- Close the connections to the K400 units.
-- @param upper The address of the upper unit (default upperIPaddress)
-- @param lower The address of the lower unit (default lowerIPaddress)
function _M.closeDevices(upper, lower)
end

-------------------------------------------------------------------------------
-- Generate a temporary file name that is relatively unique.
-- @param base The test name for the test being undertaken
function _M.tmpname(base)
    local s, n = posix.clock_gettime()
    return table.concat {
        '/tmp/test-', base, '-', posix.uname('%n'), '-', posix.getpid('pid'), '@', s+n*1e-9
    }
end

local function checkHost(host)
    return type(host) == 'table' and host.ipaddress or host
end

local function ftpurl(host, filepath)
    local h = checkHost(host)
    return table.concat {
        'ftp://', _M.username, ':', _M.password, '@', h, filepath
    }
end

-------------------------------------------------------------------------------
-- Get a file from the target host using the FTP protocol
-- @param host Either a string host address or a device descriptor
-- @param filepath The full path to the file sought including the leading '/'
-- @return The contents of the specified file or nil if it doesn't exist
function _M.getFile(host, filepath)
    return ftp.get(ftpurl(host, filepath))
end

-------------------------------------------------------------------------------
-- Push a file to the target host using the FTP protocol
-- @param host Either a string host address or a device descriptor
-- @param filepath The full path to the file sought including the leading '/'
-- @param The contents for the file
function _M.putFile(host, filepath, contents)
    return ftp.put(ftpurl(host, filepath), contents)
end

-------------------------------------------------------------------------------
-- Delete a file from the target host
-- @param host Either a string host address or a device descriptor
-- @param filepath The full path to the file sought including the leading '/'
function _M.deleteFile(host, filepath)
    _M.xeq(host, 'rm -f '..filepath)
end

-- Telnet commands
local tn_se, tn_nop, tn_dm, tn_brk, tn_ip = 240, 241, 242, 243, 244
local tn_ao, tn_ayt, tn_ec, tn_el, tn_ga = 245, 246, 247, 248, 249
local tn_sb, tn_will, tn_wont, tn_do, tn_dont, tn_iac = 250, 251, 252, 253, 254, 255

local tn_binary, tn_echo, tn_suppressGoAhead, tn_status, tn_timingMark = 0, 1, 3, 5, 6
local tn_term, tn_window, tn_speed, tn_flowControl, tn_linemode = 24, 31, 32, 33, 34
local tn_environ = 36

-- Convert an array of numbers into a telnet command string
local function tncmd(t)
    local s = {}
    for i = 1, #t do
        table.insert(s, string.char(t[i]))
    end
    return table.concat(s)
end

-- Wait for a specific character to arrive and send the response command
local function waitFor(s, c, response)
    local res, l = '', #c
    while res ~= c do
        local ch = s:receive(1)
        if ch == nil then
            break
        end
        res = (res .. ch):sub(-l)
    end
    if response ~= nil then
        s:send(response)
    end
    return res ~= nil
end

-------------------------------------------------------------------------------
-- Open a new telnet connection
-- @param host Host to connect to
-- @param port Port to conenct to (default 23)
-- @return Telnet session identifier
function _M.telnetOpen(host, port)
    local s = socket.connect(host, port or 23)

    -- Don't let us stall forever
    s:settimeout(1.1)

    -- We're pretty brutal about what we send and accept.
    -- We should parse the responses and deal with the options properly.
    s:send(tncmd({   tn_iac, tn_will, tn_suppressGoAhead,
                     tn_iac, tn_wont, tn_echo,
                     tn_iac, tn_will, tn_window,
                     tn_iac, tn_wont, tn_term,
                     tn_iac, tn_wont, tn_speed,
                     tn_iac, tn_wont, tn_flowControl,
                     tn_iac, tn_will, tn_linemode,
                     tn_iac, tn_wont, tn_environ,
                     tn_iac, tn_wont, tn_status,
                 }))
    -- The expected response from the 4223 is:
    --  tn_iac, tn_do, tn_echo,
    --  tn_iac, tn_do, tn_window,
    --  tn_iac, tn_will, tn_echo,
    --  tn_iac, tn_will, tn_suppressGoAhead
    if s:receive('*line') == nil then
        s:close()
        return nil
    end

    s:send(tncmd({   tn_iac, tn_wont, tn_echo,
                     tn_iac, tn_sb, tn_window, 0, 80, 0, 48,
                     tn_iac, tn_se,
                     tn_iac, tn_do, tn_echo,
                 }))

    -- The expected response here is a null options string
    if s:receive('*line') == nil then
        s:close()
        return nil
    end

    if not waitFor(s, 'login: ', 'root\n') or -- login
       not waitFor(s, 'Password: ', 'root\n') or -- password
       not waitFor(s, ']# ', nil) then    -- shell prompt
       s:close()
       return nil
    end
    return s
end

-------------------------------------------------------------------------------
-- Close a telnet connection
-- @param s Telnet session to close
function _M.telnetClose(s)
    s:send('exit\r\n\r\n')
    s:close()
end

-------------------------------------------------------------------------------
-- Send a command to a telnet connection and return the output
-- @param s Telnet session to send the command to
function _M.telnetSend(s, ...)
    local z = {}
    local lastNL, firstNL = nil, false

    s:send(table.concat({..., '\r\n'}))
    local prompt, pos = ']# ', 1
    while true do
        local x = s:receive(1)
        if x == nil then
            break
        elseif not firstNL then
            if x == '\n' then
                firstNL = true
            end
        else
            table.insert(z, x)
            if x == prompt:sub(pos, pos) then
                pos = pos + 1
                if pos > #prompt then
                    break
                end
            else
                pos = 1
            end
            if x == '\r' then
                lastNL = #z
            end
        end
    end
    if lastNL ~= nil then
        while #z >= lastNL do
            table.remove(z)
        end
    end
    return table.concat(z)
end

-------------------------------------------------------------------------------
-- Execute a command on the specified host using a telnet connection.
-- @param host Either a string host address or a device descriptor
-- @return The output from the command
function _M.xeq(host, ...)
    local h = checkHost(host)
    local s = _M.telnetOpen(host)
    local z = _M.telnetSend(s, ...)
    _M.telnetClose(s)
    return z
end

return _M
