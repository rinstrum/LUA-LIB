#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- This example demonstrates a complete take over of the console.
-- Lots of timers are used to slow things down so the user can see
-- what is going on.  These could be replaced by calls to rinApp.delay
-- in many cases (which itself uses a timer).
--
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- This is a demonstration application that takes complete control of
-- the display and implements a basic poker machine / one armed bandit.
-- It actually implements two different machines and chooses which one
-- to play randomly at start up.  Despite this, the actual game play is
-- identical for both.
--
-- To play, simply run the application.  To exit at any time, press and
-- hold the cancel key.
--
-- On start up, you will be shown some flashed up welcome messages.
-- These messages are different for the two machines which is the first
-- indication as to which of the machines you are playing this session.
--
-- You will then come to the wager screen.  The top left clearly asks
-- "WAGER?", the top right indicates to you the legal betting range: $1-$9,
-- the bottom right shows you your current balance and the bottom left
-- has a flashing message indicating the current level of the jackpot.
-- To continue, enter your wager by pressing one of the numeric keys.
-- You cannot bet more than you have of course and this is checked.
--
-- After entering your wager, you will briefly be shown the value of the
-- bet and then the real game begins.
--
-- You automatically proceed to the PICK screen (PICK being displayed in
-- the top right).  The top left contains the various symbols as they speed
-- past the viewing window.  Press the OK button to choose when to stop
-- the first of the three wheels.  The result appears on the HOLD screen
-- before going back to the PICK screen.  This time you'll see that your
-- first symbol is shown in the bottom left in addition to the rotating
-- view of the second wheel's symbols.  Again press OK to stop the second
-- and finally the third wheels.
--
-- You will then get the results for you spin.  Either a "Sorry" message
-- or a display of the amount you've won.  If you manage to get either of
-- the little or the big jackpots, you get a special flashing message and
-- a greatly increased prize.  Prizes are given for threes of a kind and
-- pairs of cherries.
--
-- Then it is back to the wager screen until either you run out of money
-- and go home broke or break the bank and win!
--
--
-- The video demonstrates the entire process.  The first bet is $5 and the
-- result is "Cherry Cherry Gold" which pays four times ($20).  The second
-- bet is $8 and the result is "Gold Orange Plum" which loses.  The third bet
-- is $9 and the result is "Plum Cherry Plum" which again loses.  The final
-- bet is $4 resulting in "Gold Orange Lemon" which again loses.  At this
-- point the cancel button is used to quit.  Neither jackpot sequence is
-- shown in the video and the alternate machine start up and extra symbols
-- are likewise absent.  You'll just have to play the game to see these.
--
-- If you looked carefully, you might have noticed that the jackpot value
-- increased as you play.  A portion of all bets is added to the jackpot.
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -

-- Require the rinApp module
local rinApp = require "rinApp"
local timers = require 'rinSystem.rinTimers'
local random = math.random
math.randomseed(os.time())      -- shake things up a bit

-- Add control of a device at the given IP and port
local device = rinApp.addK400()

-- Write to the LCD screen -- turn off automatic updates on the left
-- We want complete control here.
device.writeAuto('topLeft', 0)
device.writeAuto('bottomLeft', 0)

-- The names of the faces of each wheel and the payouts for getting triples and
-- pairs of cherries.  We implement two different poker machines fairly close 
-- to those specified on page 215 of ISBN 978-0935696028.  The payouts are 
-- altered very slightly for the eight picture machine and a jackpot has been 
-- added.  The machines still favour the house not the player.
local nSides, longNames, shortNames, triplePay, cherryPay, welcomeMessages
if random(10) > 7 then
    -- This first set has eight pictures on each wheel and has better returns 
    -- but a lower chance winning on any individual spin.
    nSides = 8
    longNames =     { "LEMON", "ORANGE", "BAR", "BELL", "Plum", "CHERRY", "ANCHOR", "Gold" }
    shortNames =    { "LE",    "Or",     "Ba",  "BE",   "Pl",   "Ch",     "An",     "Go"   }
    triplePay =     { 8,       10,       12,    15,     20,     24,       50,       100    }
    cherryPay =     { 2,       4,        6,     8,      10,     24,       12,       14     }
    welcomeMessages = { { "ZOWIE", "POKIE", "GAME" }, { "PLAY", "FUN", "PROFIT" } }
else
    -- This set has six pictures on each wheel and has lower returns but 
    -- individual wins are more likely
    nSides = 6
    longNames =   { "LEMON", "ORANGE", "Plum", "BELL", "Gold", "CHERRY" }
    shortNames =  { "LE",    "Or",     "Pl",   "BE",   "Go",   "Ch"     }
    triplePay =   { 4,       8,        10,     12,     24,     36       }
    cherryPay =   { 2,       3,        4,      5,      6,      0        }
    welcomeMessages = { { "ONE", "ARMED", "BANDIT" }, { "ENJOY", "SPEND", "GAMBLE" } }
end

-- The various state variables we keep
local jackpot = 1000            -- Initial jackpot balance
local balance = 100             -- Player's initial funds
local wager = 0                 -- Current wager
local state = 'begin'
local rolls = { "", "", "" }
local irolls = { 1, 2, 3 }
local nroll = 1
local rng = 1
local jackpottimer, playtimer, jackpotwintimer

-------------------------------------------------------------------------------
-- A function that takes a string and right justifies it to the specified width
-- be prepending spaces.
-- @param msg The message to justify
-- @param n The width of the field
-- @return A justified string
local function JustifyRight(msg, n)
    return string.sub(string.rep(" ", n) .. msg, -n)
end

-------------------------------------------------------------------------------
-- Display a message in the top right position.  It will be right justified.
-- @param msg The message to display
local function promptTR(msg)
    device.write('topRight', JustifyRight(msg, 4))
end

-------------------------------------------------------------------------------
-- Routine to flash between a list of messages in order.
-- @param messages Array of messages to display
-- @param f Function to display each message
-- @param delay Delay before starting the flashing sequence
-- @return Timer reference
local function flashMessage(messages, f, delay)
    delay = delay or 0
    local stage = 1
    local function toggleMessages()
        f(messages[stage])
        stage = stage + 1
        if stage > #messages then
            stage = 1
        end
    end

    return timers.addTimer(0.5, delay, toggleMessages)
end

-------------------------------------------------------------------------------
-- function to enable or disable the jackpot flashing sign in the bottom
-- left display section
-- @param on Boolean to turn on or off the display
local function setjackpot(on)
    if on then
        local m = { "JACKPOT", JustifyRight("$ " .. math.floor(jackpot), 8) }
        timers.removeTimer(jackpottimer)
        jackpottimer = flashMessage(m, device.writeBotLeft)
    else
        device.write('bottomLeft', "")
        timers.removeTimer(jackpottimer)
        jackpottimer = nil
    end
end

-------------------------------------------------------------------------------
-- Schedule the game over flashing message
local function beginGameOver()
    flashMessage({ "GAME", JustifyRight("OVER", 8) }, device.writeBotLeft)
end

-------------------------------------------------------------------------------
-- Set up the wager screen
local function setupWagerScreen()
    state = "bet"
    promptTR("$1-9")
    device.write('topLeft', "WAGER?")
    setjackpot(true)
end

-------------------------------------------------------------------------------
-- Update the player's balance and redisplay on the lower right
-- @param delta The amount to add to the player's balance (can be zero or negative)
local function updateBalance(delta)
    balance = balance + delta
    device.write('bottomRight', JustifyRight("$" .. balance, 8))

    if balance > 10000 then
        device.write('topLeft', "WINNER")
        beginGameOver()
        state = "win"
        setjackpot(false)
        timers.addTimer(0, 4, rinApp.finish)
    end
end

-------------------------------------------------------------------------------
-- Scoring routine
-- The winning results are three of a kind or a pair of cherries.
-- There are three different pairs of cherries available so we've got
-- to check the lot.  These odds are in favour of the house even including
-- the jackpot bonuses.
local function scoringCallback()
    state = "score"

    local payout = 0
    local jp = 0
    if irolls[1] == irolls[2] and irolls[1] == irolls[3] then
        payout = triplePay[irolls[3]]
        if irolls[1] == nSides then jp = 2
        elseif irolls[1] == nSides-1 then jp = 1
        end
    elseif irolls[1] == 6 and irolls[2] == 6 then
        payout = cherryPay[irolls[3]]
    elseif irolls[1] == 6 and irolls[3] == 6 then
        payout = cherryPay[irolls[2]]
    elseif irolls[2] == 6 and irolls[3] == 6 then
        payout = cherryPay[irolls[1]]
    end

    local delay = 2
    if payout > 0 then
        payout = payout * wager
        promptTR("Win")

        if jp == 2 then     -- Big jackpot gets a nice flashing message
            payout = payout + math.floor(jackpot)
            jackpot = 0
            delay = 6
            device.buzz(3)

            local m = { "JACK", JustifyRight("POT", 6) }
            jackpotwintimer = flashMessage(m, device.writeTopLeft, 2)
        elseif jp == 1 then -- Little jackpot gets a flashing message too
            payout = payout + math.floor(jackpot / 2)
            jackpot = jackpot / 2
            delay = 5
            device.buzz(2)

            local m = { "Good", JustifyRight("Win", 6) }
            jackpotwintimer = flashMessage(m, device.writeTopLeft, 2)
        else
            delay = 3
        end
        updateBalance(payout)
        device.write('topLeft', "$" .. payout)
    else
        delay = 2
        device.write('topLeft', "SORRY")
        promptTR("LOSE")
    end
    jackpot = jackpot + wager / 20

    if balance > 0 then
        local function backToWager()
            setupWagerScreen()
            timers.removeTimer(jackpotwintimer)
        end
        timers.addTimer(0, delay, backToWager)
    else
        device.write('topLeft', "BROKE")
        beginGameOver()
        state = "lose"
        setjackpot(false)
        timers.addTimer(0, 4, rinApp.finish)
    end
end

-------------------------------------------------------------------------------
-- Begin playing the game soon
-- @param delay The dealy before we start playing
local function beginPlaying(delay)
    local function setPlayModeCallback()
        state = "play"
        promptTR("PICK")
    end
    timers.addTimer(0, delay, setPlayModeCallback)

    local function playCallback()
        device.write('topLeft', longNames[rng])
        device.write('bottomLeft', rolls[1] .. " " .. rolls[2])
    end
    playtimer = timers.addTimer(0.06, delay, playCallback)
end

-------------------------------------------------------------------------------
-- Key press handler for the OK button
-- @param key Key code pressed (always okay)
-- @param st Type of key press
local function playOkay(key, st)
    if state == "play" then
        local r = rng
        irolls[nroll] = r
        rolls[nroll] = shortNames[r]

        nroll = nroll + 1
        device.write('bottomLeft', rolls[1] .. " " .. rolls[2] .. " " .. rolls[3])
        timers.removeTimer(playtimer)
        device.write('topLeft', longNames[r])
        promptTR("HOLD")
        if nroll < 4 then
            state = "pause"
            beginPlaying(1.3)
        else
            nroll = 1
            timers.addTimer(0, 1.3, scoringCallback)
        end
    end
    return true
end
device.setKeyCallback('ok', playOkay, 'short')


-------------------------------------------------------------------------------
-- Add key to stop the program
-- @param key Key code pressed (always okay)
-- @param state Type of key press
device.setKeyCallback('cancel', rinApp.finish, 'long')


-------------------------------------------------------------------------------
-- Schedule a bet display
-- @param d The delay before displaying the wager screen
local function scheduleWager(d)
    local function showWagerScreen()
        setupWagerScreen()
        updateBalance(0) -- display the balance
    end
    timers.addTimer(0, d, showWagerScreen)
end

-------------------------------------------------------------------------------
-- The bet state waits for a numeric key and then continues using that single
-- digit as a wager.  This is the key handler for numeric keys.  Just accept the
-- wager if it is within the player's current balance.  Display the bet on screen
-- and continue onto playing.
-- @param key The key pressed
-- @param st The state of the press 'long' or 'short'
local function numberPressed(key, st)
    if state == "bet" then
        promptTR("")
        if key > balance then
            state = "error"
            device.write('topLeft', "CAN'T")
            device.buzz(1)
            scheduleWager(2)
        else
            device.write('topLeft', "BET $" .. tostring(key))
            wager = key
            updateBalance(-wager)
            local function startplay()
                nroll = 1
                rolls = { "  ", "  ", "  " }
                irolls = { 0, 0, -1 }
                setjackpot(false)
                beginPlaying(0)
            end
            timers.addTimer(0, 2, startplay)
        end
    end
    return true
end

-- Installed the numberic handler for the keys we're interested in, we
-- use the key group 'numpad' here and trap the zero key separately.
-- An individual key handler overrides a key group handler and we do't want
-- to see the zero key.
device.setKeyGroupCallback('numpad', numberPressed, 'short')
device.setKeyCallback(0, function(k, s) return true end, 'short')

-- Let's ignore all the rest of the keys.  The 'all' key group is the very
-- last one looked for, so a handler here is only invoked when all else
-- fails.
device.setKeyGroupCallback('all', function(k, s) return true end, 'short', 'long')

-------------------------------------------------------------------------------
-- The initial begin state displays a weclome message,
-- then switches to the bet state.  We could use the flash message routine to
-- do this by calling it twice, but we want these synchronised better than that.
local function weclomePlayer()
    local pos = 1
    local function show()
        device.write('topLeft', welcomeMessages[1][pos])
        device.write('bottomLeft', JustifyRight(welcomeMessages[2][pos], 8))
        pos = pos + 1
        if pos <= #(welcomeMessages[1]) then
            timers.addTimer(0, 1.5, show)
        else
            scheduleWager(1.5)
        end
    end
    device.write('topRight', "")
    device.write('bottomRight', "")
    show()
end
weclomePlayer()

-- Keep the entropy spinning around quickly using a recurring timer.
timers.addTimer(0.005, 0, function () rng = random(nSides) end)

-- Main Application Loop
rinApp.run()
