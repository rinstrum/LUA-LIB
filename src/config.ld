project="rinLIB Framework"
title="rinLIB Framework"
format='markdown'
--readme='src/readme.md'
output='index'

full_description=[[
# rinLIB: API for programming the M4223 in Lua 

Copyright (C) 2013-2014 Rinstrum.

## Overview

The Rinstrum M4223 is an embedded linux device with Ethernet and USB Host ports that mounts 
to the accessory bus of the R420 series weighing indicators.
The device hosts a webserver onboard and exposes a number of linux services including
    * Telnet and SSH
    * FTP and sFPT
There are a number of pre-installed applications running on the M4223, some written in embedded C 
and some written in an open source scripting language called Lua.
The Lua engine is configured to automatically load and run custom lua script files.

## Lua Development tools
Lua is a plain text scripting language and so can be created with any text editor.  
The M4223 ships with an onboard text editor for the purpose called vi.  
Lua script can therefore be developed on the M4223 directly using a remote telnet service like PuTTY.

Usually though it is more convenient to edit the lua script files using a more advanced editor on a remote computer and copy the files to the M4223 using the built in FTP services.  
Windows editors like Notepad++ recognise LUA syntax and highlight the script accordingly to make editing more convenient.  Notepad++ is a free product and can be configured to work with the files remotely using a FTP plugin.  Alternatively there are many FTP programs like winSCP that can be used to synchronise the files from your development computer to the M4223.
For existing developers it is very likely that your existing programmers editor will support Lua so you can develop scripts for the M4223 in a familiar environment.  Eclipse for example is a popular programming environment that fully supports the Lua scripting language and is available on many platforms including Mac, PC and Linux.

## Resources
The M4223 has a total of 64Mbytes of onboard flash memory and supports an onboard file system
that typically ships with around 40mB of free space to store custom scripts and data.

The USB host port is supported with USB drivers for all generic devices including keyboards, barcode readers, ticket printers, serial ports, bluetooth, and flash memory sticks.  It is therefore possible to extend the memory capacity of the M4223 using external storage.
The USB port fully supports the use of USB hubs including externally powered hubs so the range of connectivity options is not restricted
## The Lua Interpretor
From the linux command line simply type in lua<CR> to start the lua script engine in interactive mode.  In this mode you can type commands directly via the keyboard and they are executed immediately.

    >[root@m4223 /home]# lua
    Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio

    x = 5
    y = 2
    print(x,y,x+y)
    5       2       7
    ^D
    [root@m4223 /home]#

To run a preprepared script launch lua with the name of the application to run:
>
>lua myApp.lua
>

The script /home/autostart/run.lua is started automatically when the instrument powers up and this script is used to issue linux operating system commands and launch custom .Lua scripts automatically.

## System Architecture
The M4223 mounts to the R420 like all other accessory modules and from the R420's point of view looks like any other serial accessory device with a bi-directional and unidirectional serial port.  In the R420 the M4223 maps into SER3A and SER3B.  
Configuration of SER3A is fixed as a network port so the M4223 can interact with the R420.  SER3B though can be configured like any other serial port in the R420.  For example it might be configured as a print port and take a custom print ticket from the R420.
Serial data on SER3A and SER3B is accessible to Lua applications through socket connections through the linux operating system and also through ports 2222 and 2223 on the Ethernet port.

This means that the Lua application on the M4223 interacts with the R420 in exactly the same way as any other external control program.  For example the View400 configuration utility for Windows uses the exactly same process to communicate with the R420 remotely.

Built into the M4223 is a local program that manages multiple connections to SER3A so multiple programs can have their own virtual channels to the R420.  In this way it is possible to have multiple Lua applications running on the M4223 as well as multiple remote connections to other computers with each connection kept independent

This also means that networking multiple R420 instruments using the M4223 is trivial as the interface from the Lua application to the local R420 is exactly the same as a connection to any remote R420.  Applications can be written therefore that maintain a central control process and database across multiple indicators without the complexity of connecting multiple scales and associated control interfaces all to the one indicator.

To make developing applications easy to do on the M4223 Rinstrum has developed a complete set of open source libraries written entirely in Lua referred to as the rinLIB framework.  In addition there are a number of application templates for common classes of applications and a myriad of worked examples

]]
