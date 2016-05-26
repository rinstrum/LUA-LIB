#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- Finite State Machine
--
-- An example of how to use the finite state machine class.
--
-- Creates a state machine containing various items and runs it.
-- The state machine diagram is saved as demoFSM.dot in the current directory.
-- This can be converted into a PDF file via:
--      dot -Tpdf >demoFSM.pdf <demoFSM.dot
-- A copy of the resultant PDF file is present as fsm.pdf in 
-- /home/lualib_examples
-------------------------------------------------------------------------------
local timers = require 'rinSystem.rinTimers'
local rinApp = require "rinApp"         --  load in the application framework

--=============================================================================
-- Connect to the instruments you want to control
--=============================================================================
local device = rinApp.addK400()         --  make a connection to the instrument
local timer

local fsm = device.stateMachine { 'demoFSM', showState = true }
    .state { 'Start', short='STRT' }
    .state { 'Zero', enter=function() device.write('bottomLeft', 'ZEROED') end }
    .state { 'Motion', short='MOVE', enter=function() device.write('bottomLeft', 'MOVING') end }
    .state { 'Steady', short='OKAY' }
    .state { 'Finish', short='FIN', enter=function()
                timer = timers.addTimer(0, 3.3, rinApp.finish)
            end }
    .state { 'Nowhere', short='LOST', enter=function()
                device.write('bottomLeft', "I AM LOST SOMEWHERE ......", 'once, clear')
            end }
    .state { 'Somewhere', short='HERE', enter=function()
                device.write('bottomLeft', "I AM FOUND", 'once, clear')
            end }

    .trans { 'All', 'motion', status='motion', activate=function()
                timers.removeTimer(timer)
            end }
    .trans { 'Start', 'Zero', status={'zero', 'notmotion'} }
    .trans { 'Start', 'Steady', status={'notzero', 'notmotion'},
                  activate=function() device.write('bottomLeft', 'PLEASE ZERO') end
            }
    .trans { 'Motion', 'Zero', status={'zero', 'notmotion'}, }
    .trans { 'Motion', 'Steady', status={'notzero', 'notmotion'},
                activate=function() device.write('bottomLeft', 'READY') end
            }
    .trans { 'Steady', 'Nowhere', event='fin', time=4 }
    .trans { 'Nowhere', 'Somewhere', time=2.4 }
    .trans { 'Somewhere', 'Finish', event='fin' }
    .trans { 'Somewhere', 'Steady', time=1.8 }

fsm.dump('demoFSM.dot')

device.setKeyCallback(9, function() fsm.raise('fin') return true end, 'short')

device.write('bottomLeft', 'FIND THE WAY OUT', 'wait, clear')
rinApp.setMainLoop(fsm.run)
rinApp.run()
