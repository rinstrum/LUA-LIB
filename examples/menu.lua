-------------------------------------------------------------------------------
-- Menu
--
-- An example of how to use the menu UI class.
--
-- Creates a menu containing the various items available and runs it.
-------------------------------------------------------------------------------
local rinApp = require "rinApp"         --  load in the application framework

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local device = rinApp.addK400("K401")   --  make a connection to the instrument

local menu = device.createMenu { 'TOP MENU' }       -- create a menu
    .integer    { 'INTEGER', 3, min=1, max=5 }      -- Add an integer item
    .integer    { 'ANOTHER', 1 }                    -- Another integer without min and max limits
    .menu       { 'NUMBERS', loop=true }            -- A submenu called NUMBERS
        .integer    { 'COUNT', 0, min=0, max=9 }
        .number     { 'SCALE', 1, min=0.9, max=1.1} -- A real number with limits
        .number     { 'FUDGE', 2.718281828495 }     -- Another real number
        .passcode   { 'SECRET', 1111 }              -- A pass code entry field
        .fin()                                      -- End the sub menu
    .menu       { 'STRINGS' }
        .string     { 'SHORT', 'abc', 3 }           -- Three character string
        .string     { 'LONG', 'hello', 15 }         -- A longer string
        .fin        {}
    .list       { 'PRODUCT',                        -- A pick list of three elements
                    { 'WHEAT', 'RICE', 'CORN' },
                    loop = true }                   -- That wraps top to bottom
    .menu       { 'REGISTER' }
        .register   { 'USER 1', 'userid1', prompt = true }
        .register   { 'USER 2', 'userid2', prompt = 'U2' }
        .auto       { 'MVV', 'absmvv' }
        .fin()
    .item       { 'PRESS ME', run=function() print('hello user') end }
    .exit       { 'QUIT' }

device.write('bottomLeft', 'WELCOME TO THE MENU')
device.write('bottomRight', 'F3 FOR THE MENU')
device.setKeyCallback('f3', menu.run, 'short')

-- We can query out menu fields via the top level menu
function printMenuContents()
    for _, n in ipairs{'integer', 'another', 'count', 'scale', 'fudge',
                        'secret', 'short', 'long', 'product'
    } do
        print(n, menu.getValue(n))
    end
end
device.setKeyCallback('f2', printMenuContents, 'short')

device.setKeyCallback('f1', function()
    device.write('bottomLeft', 'SAVING', 'time=2, clear')
    menu.toCSV('settings.csv')
end, 'short')
device.setKeyCallback('f1', function()
    device.write('bottomLeft', 'LOADING', 'time=2, clear')
    menu.fromCSV('settings.csv')
end, 'long')

rinApp.run()

-- Cleanup the application and exit
rinApp.cleanup()
os.exit()
