# The Lua Interpretor

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
