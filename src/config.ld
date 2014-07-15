project="rinLIB"
title="Rinstrum Lua Library API"
format='markdown'   -- 'discount' is faster but isn't available on the device.
readme= { 'src/topics' }

output='index'
examples={          -- We should be able to wildcard this.
    'examples/helloLua.lua',
    'examples/hello.lua',
    'examples/multi-hello.lua',
    'examples/external.lua',
    'examples/marquee.lua',
    'examples/myApp.lua',
    'examples/myCalApp.lua',
    'examples/myUSBApp.lua',
    'examples/printCopy.lua',
    'examples/setpIO/setpIO.lua',
}

full_description=[[
# rinLIB: API for programming the M4223 in Lua 

Copyright (C) 2013-2014 Rinstrum.

If you do not know where to begin, please start with the <a href="topics/overview.md.html">introduction</a>.

]]
