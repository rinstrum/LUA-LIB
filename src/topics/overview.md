# Overview

The Rinstrum M4223 is an embedded linux device with Ethernet and USB Host ports that mounts 
to the accessory bus of the R420 series weighing indicators.

The device hosts a webserver onboard and exposes a number of linux services including

    * Telnet
    * SSH
    * FTP
    * SFTP

There are a number of pre-installed applications running on the M4223, some written in embedded C 
and some written in an open source scripting language called Lua.
The Lua engine is configured to automatically load and run custom lua script files.
