#!/usr/bin/env lua
require "struct"
require "pb"
require "messages"
require "lpeg"
local socket = require "socket"

local server = "aaa.bbb.ccc.ddd"
local port = 2224
local sock = socket.tcp()
sock:connect(server, port)

local req
local somethingToSend = false
local running = true

-------------------------------------------------------------------------------
-- Wrapper up and send a message to the socket
local function sendMessage(m)
    local s = m:Serialize()
    local p = struct.pack("I2c0", #s, s)
    sock:send(p)
end

-------------------------------------------------------------------------------
-- Receive and process a message from the socket
local function recvMessage()
    local read, write, err = socket.select({sock}, nil, .2)
    if err == "timeout" then return end
    if #read == 0 then return end

    local packet = sock:receive(2)
    local s = struct.unpack("I2", packet)
    local msg = sock:receive(s)
    local m = protodemo.FromM4223():Parse(msg)

    -- Now to process the individual parts of the message
    if m.add_result ~= nil then
        print("addition result is " .. m.add_result.result)
    end
    if m.mul_result ~= nil then
        print("multiplication result is " .. m.mul_result.result)
    end
end

-------------------------------------------------------------------------------
-- Utility function to build up an addition request and add it to the message
-- but not to actually send it.
local function calc_add(x, y)
    local reqAdd = protodemo.AddRequest()
    reqAdd.arg1 = x
    reqAdd.arg2 = y
    req.add_request = reqAdd
    somethingToSend = true
end

-------------------------------------------------------------------------------
-- Utility function to build up a multiplication request and add it to the
-- message but not to actually send it.
local function calc_mul(x, y)
    local reqMul = protodemo.MulRequest()
    reqMul.arg1 = x
    reqMul.arg2 = y
    req.mul_request = reqMul
    somethingToSend = true
end

-------------------------------------------------------------------------------
-- Build a simple parser for the users input
local parser
do
    local P, S, R, V, C, Cf, Cg = lpeg.P, lpeg.S, lpeg.R, lpeg.V, lpeg.C, lpeg.Cf, lpeg.Cg
    local l = {}
    lpeg.locale(l)
    local sp = l.space ^ 0
    local digits = l.digit^1
    local mpm = (S"+-")^-1
    local exp = (S"eE" * mpm * digits)^-1
    local float = mpm * (digits * ("."*digits)^-1 + "."*digits) * exp
    local floatc = sp * (float / tonumber) * sp

    parser = P {
        V"add_mul" + V"mul_add" + V"quit",
        quit = P("quit") / function () running = false end,
        add_mul = V"add_expr" * ("," * V"mul_expr")^-1,
        add_expr = Cf(floatc * Cg("+" * floatc), calc_add),
        mul_add = V"mul_expr" * ("," * V"add_expr")^-1,
        mul_expr = Cf(floatc * Cg("*" * floatc), calc_mul)
    }
end

-------------------------------------------------------------------------------
-- Main loop.  Read a line from the user and grab the response back.
while running do
    local il = io.read("*line")
    if il == nil then break end

    req = protodemo.ToM4223()
    lpeg.match(parser, il)

    if somethingToSend then
        sendMessage(req)
        somethingToSend = false
    end
    recvMessage()
end
