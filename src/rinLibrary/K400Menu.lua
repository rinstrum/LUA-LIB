-------------------------------------------------------------------------------
--- Menuing Functions.
-- An easy to use menuing subsystem.
--
-- Look at the <a href="../examples/menu.lua.html">menu.lua</a> example file
-- for a more detailed usage example of this subsystem.
--
-- @module rinLibrary.K400Menu
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local dbg = require "rinLibrary.rinDebug"
local canonical = require('rinLibrary.namings').canonicalisation
local utils = require 'rinSystem.utilities'
local deepcopy = utils.deepcopy
local callable, cb = utils.callable, utils.cb
local null, True, False = utils.null, utils.True, utils.False
local csv = require 'rinLibrary.rinCSV'

-------------------------------------------------------------------------------
-- A function that wrappers another function with a check for a readonly field
-- @return wrappered function
-- @local
local function ro(item, f)
    return function(...)
        if not item.readonly then
            return f(...)
        end
    end
end

-------------------------------------------------------------------------------
-- Interogate an item and return the appropriate prompt for it
-- @param item Item to be prompted for
-- @return Prompt for the item
-- @local
local function getPrompt(item)
    local p = item.prompt
    if item.uppercasePrompt and type(p) == 'string' then
        p = string.upper(p)
    end
    return p
end

-------------------------------------------------------------------------------
-- Function to run an item
-- @param item Item to run
-- @local
local function run(item)
    item.onRun()
    item.run()
end

-------------------------------------------------------------------------------
-- Function to show an item
-- @param item Item to show
-- @local
local function show(item)
    item.show()
    item.onShow()
end

-------------------------------------------------------------------------------
-- Function to hide an item
-- @param item Item to hide
-- @local
local function hide(item)
    item.onHide()
    item.hide()
end

-------------------------------------------------------------------------------
-- Function to update an item
-- @param item Item to update
-- @local
local function update(item)
    item.update()
    item.onUpdate()
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

--- Fields Definition Arguments.
--
-- All of these field arguments are optional with sensible defaults.  Not all of these
-- fields are meaningful for all field kinds.  For example, getValue doesn't make sense
-- for a field without a value.  Likewise, run is replaced by all fields (except item) and
-- cannot be overridden.
--
-- @table FieldDefinition
-- @field default Default item in a list selection.
-- @field enabled Boolean or function returning a boolean to indicate if this
-- field should be visible or not.
-- @field exit Boolean, true means selecting this item exits the containing menu.
-- @field getValue Function to return the value of a field's contents.
-- @field hide Function to execute when field is moved away from.  This function is used
-- internally by the memnu subsystem and generally shouldn't be replaced.  Use the <i>onHide</i>
-- call back instead.
-- @field leave Function to execute when leaving the top level menu, it is passed a boolean
-- which indicates if the menu exited via an EXIT field item (true) or by cancelling at the
-- top level (false).
-- @field loop Should a list or menu item loop from bottom to top? Default is yes.
-- @field max Maximum value a numeric, integer or passcode  field can take
-- @field min Minimum value a numeric, integer or passcode field can take
-- @field no The name of the no item in a boolean field (default: no).
-- @field onHide Function to call before the menu system's hide call.
-- @field onRun Function that is called by the menu systems run call.
-- @field onShow Function to call after the menu system's show call.
-- @field onUpdate Function to call repeatedly during the display of a field.
-- @field prompt Prompt to be displayed when this field is being edited or viewed.
-- @field readonly Boolean indicating is the field is immutable or not (default false).
-- @field ref Reference name used to identify a field, this defaults to the name and must be
-- unique through the entire menu and submenus.
-- @field rememberPosition Does this menu remember its position between invocations or not.
-- @field run Function to execute when field is activated.  This function is used
-- internally by the memnu subsystem and generally shouldn't be replaced.  Use the <i>onRun</i>
-- call back instead.
-- @field secondary Name of type of item which is displayed in the value area if field has no value.
-- @field setList Function to set the contents of a list field.
-- @field setValue Function to set the field's contents.
-- @field show Function to execute when field is displayed.  This function is used
-- internally by the memnu subsystem and generally shouldn't be replaced.  Use the <i>onShow</i>
-- call back instead.
-- @field unitsOther Extra units annunciators to display when active.
-- @field units Units annunciators to display when this field is active.
-- @field update Function that is called while field is displayed.  This function is used
-- internally by the memnu subsystem and generally shouldn't be replaced.  Use the <i>onUpdate</i>
-- call back instead.
-- @field uppercasePrompt Boolean to force the prompt to be upper case or not (default: true for upper case)
-- @field yes The name of the yes item in a boolean field (default: yes).
-- @field length Length of a string field (usually the third positional argumnet would be used for this)
-- @field name Name of field (usually the first positional argumnet would be used for this)
-- @field register Register to use with field (usually the second positional argumnet would be used for this)
-- @field value Value to set field to (usually the second positional argumnet would be used for this)

-------------------------------------------------------------------------------
-- Create a new empty menu
-- @param args Menu field arguments
-- @param parent Menu's parent menu
-- @param fields Table of all fields defined
-- @return The menu
-- @see FieldDefinition
-- @local
local function makeMenu(args, parent, fields)
    local posn, menu = 1
    local rememberPosition = args.rememberPosition == true

-------------------------------------------------------------------------------
-- Initialise a new item to the defaults
-- @param args arguments passed in by user
-- @param typeName Optional name of field type that will be displayed in absence of a value
-- @return New item
-- @local
    local function newItem(args, typeName)
        local name = args[1] or args.name
        local prompt = name
        if args.prompt ~= nil then
            prompt = args.prompt
        end

        local enabled
        if type(args.enabled) == 'boolean' then
            enabled = args.enabled and True or False
        else
            enabled = cb(args.enabled, True)
        end

        local r
        r = {
            name = name,
            ref = canonical(args.ref or name),
            prompt = prompt,
            uppercasePrompt = (args.uppercasePrompt == nil) and true or args.uppercasePrompt,
            units = args.units or 'none',
            unitsOther = args.unitsOther or 'none',
            loop = args.loop == nil and true or args.loop,
            secondary = args.secondary or typeName or '',
            readonly = args.readonly or false,
            exit = args.exit or false,

            run = cb(args.run, null),
            show = cb(args.show, function()
                    _M.write('topLeft', getPrompt(r))
                    _M.writeUnits('bottomLeft', r.units, r.unitsOther)
                    _M.write('topRight', r.readonly and 'FIXD' or '')
                end),
            hide = cb(args.hide, null),
            update = cb(args.update, function()
                    local m = callable(r.getValue) and r.getValue() or r.secondary
                    _M.write('bottomLeft', m, 'align=right')
                    return false
                end),
            onRun = cb(args.onRun, null),
            onShow = cb(args.onShow, null),
            onHide = cb(args.onHide, null),
            onUpdate = cb(args.onUpdate, null),
            enabled = enabled
        }
        return r
    end
    menu = newItem(args, 'MENU')

-------------------------------------------------------------------------------
-- Add an item to this menu
-- @param item Item to add to this menu
-- @return This menu
-- @local
    local function add(item)
        table.insert(menu, item)
        if fields[item.ref] then
            if item.getValue or fields[item.ref].getValue then
                error('Two items with reference '..item.ref..', one or both have values.')
            else
                dbg.error('Ambigious menu field reference:', item.ref)
            end
        end
        fields[item.ref] = item
        return menu
    end

-------------------------------------------------------------------------------
-- Create one of the numeric fields
-- @param args Field arguments
-- @param type Type of field (interger, number or passcode)
-- @return The containing menu
-- @see FieldDefinition
-- @local
    local function numericEdit(args, type)
        local item = newItem(args)
        local value = tonumber(args[2] or args.value or 0)
        local min, max = args.min, args.max

        item.run = ro(item, function()
            local v, ok = _M.edit(getPrompt(item), value, type, item.units, item.unitsOther)
            if ok then
                if min then v = math.max(min, v) end
                if max then v = math.min(max, v) end
                item.setValue(v)
            end
        end)
        item.getValue = function() return value end
        item.setValue = function(v) value = tonumber(v) end
        if type == 'passcode' then
            item.update = cb(args.update, function()
                _M.write('bottomLeft', string.rep('+', #tostring(value)), 'align=right')
                return false
            end)
        end
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add an integer field to a menu
-- @function integer
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . integer { 'NUMBER', 3 }
    function menu.integer(args)
        return numericEdit(args, 'integer')
    end

-------------------------------------------------------------------------------
-- Add a real field to a menu
-- @function number
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . number { 'PI', 3.14 }
    function menu.number(args)
        return numericEdit(args, 'number')
    end

-------------------------------------------------------------------------------
-- Add a pass code field to a menu
-- @function passcode
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . passcode { 'PI', 1234 }
    function menu.passcode(args)
        return numericEdit(args, 'passcode')
    end

-------------------------------------------------------------------------------
-- Add a string field to a menu
-- @function string
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } . string { 'NAME', 'fred' }
    function menu.string(args)
        local item = newItem(args)
        local value = args[2] or args.value or ''
        local len = args[3] or args.length or #value

        item.run = ro(item, function()
            local v, ok = _M.sEdit(getPrompt(item), value, len, item.units, item.unitsOther)
            if ok then
                value = v
            end
        end)
        item.getValue = function() return value end
        item.setValue = function(v) value = v end
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add a boolean field to a menu
-- @function boolean
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' }
--                      .boolean { 'OKAY?' }
--                      .boolean { 'COLOUR', 'RED', 'RED', 'BLUE' }
    function menu.boolean(args)
        local value
        local item = newItem(args)
        local yesItem = args[3] or args.yes or 'YES'
        local noItem = args[4] or args.no or 'NO'

        local function set(v)
            value = (canonical(v) == canonical(yesItem)) and yesItem or noItem
        end
        set(args[2] or args.value)

        item.run = ro(item, function()
            local v = _M.selectOption(getPrompt(item), { yesItem, noItem }, value, item.loop, item.units, item.unitsOther)
            if v then
                set(v)
            end
        end)
        item.getValue = function() return value end
        item.setValue = set
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add a register field to a menu.  When invoked, the register will be edited.
-- @function register
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' }
--                      .register { 'USER 1', 'userid1', prompt=true }
    function menu.register(args)
        local item = newItem(args)
        local reg = args[2] or args.register

        local writePerm
        local function checkWritable()
            if writePerm == nil then
                writePerm = private.getRegPermissions(reg).write
            end
            return writePerm
        end

        item.show = function()
            _M.write('topLeft', item.prompt)
            _M.writeAuto('bottomLeft', reg)
            _M.write('topRight', (item.readonly or not checkWritable()) and 'FIXD' or '')
        end
        item.hide = function()
            _M.writeAuto('bottomLeft', 'none')
        end
        item.update = null
        item.run = ro(item, function()
            if checkWritable() then
                local v = _M.editReg(reg, getPrompt(item))
                _M.write('bottomLeft', v, 'align=right')
            end
        end)
        item.getValue = function()
            return (_M.getRegister(reg))
        end
        item.setValue = function(v)
            _M.setRegister(reg, v)
        end
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add a list pick field to a menu
-- @function list
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' }
--                      .list { 'PICK', { 'ABC', 123, 'BYE BYE' }, default=123 }
    function menu.list(args)
        local item = newItem(args)
        local itemList = deepcopy(args[2] or args.value)
        local value = args.default or itemList[1]

        item.run = ro(item, function()
            local v = _M.selectOption(getPrompt(item), itemList, value, item.loop, item.units, item.unitsOther)
            if v then
                value = v
            end
        end)
        item.getValue = function() return value end
        item.setValue = function(v) value = v end
        item.setList = function(l) itemList = deepcopy(l) end
        return add(item)
    end

-------------------------------------------------------------------------------
-- Add a sub-menu to a menu
-- @function menu
-- @param args Field arguments
-- @return The sub-menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } .
--                      .menu { 'SUBMENU' }
--                          .number { 'TWO', 2 }
--                      .fin()
    function menu.menu(args)
        local item = makeMenu(args, menu, fields)
        add(item)
        return item
    end

-------------------------------------------------------------------------------
-- Mark the end of a sub-menu
-- @function fin
-- @return The parent menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' } .
--                      .menu { 'SUBMENU' }
--                          .integer { 'THREE', 3 }
--                      .fin()
    function menu.fin()
        if parent then
            return parent
        else
            dbg.error('menu:', 'Too many fin elements')
        end
        return menu
    end

-------------------------------------------------------------------------------
-- Terminate a menu
-- @function finish
-- @usage
-- mymenu.finish()
    function menu.finish()
        menu.inProgress = false
    end


-------------------------------------------------------------------------------
-- Add a generic user item to a menu
-- @function item
-- @param args Field arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = device.createMenu { 'MYMENU' }
--                      .item { 'PRESS ME', run=function() print 'hello' end }
    function menu.item(args)
        return add(newItem(args))
    end

    if parent == nil then
-------------------------------------------------------------------------------
-- Return the named field from within the menu heirarchy
-- @function findField
-- @param ref Field reference name
-- @return field table
        menu.findField = function(ref)
            return fields[canonical(ref)]
        end

-------------------------------------------------------------------------------
-- Set a named field to the specified value
-- @function getValue
-- @param ref Name of field
-- @return Value the field is set to
-- @usage
-- local big = menu.getValue('largest')
        function menu.getValue(ref)
            local r = menu.findField(ref)
            return r and r.getValue and r.getValue() or nil
        end

-------------------------------------------------------------------------------
-- Set a named field to the specified value
-- @function setValue
-- @param ref Name of field
-- @param value Value to set field to
-- @usage
-- menu.setValue('largest', 33.4)
        function menu.setValue(ref, value)
            local r = menu.findField(ref)
            if r and r.setValue then r.setValue(value) end
        end

-------------------------------------------------------------------------------
-- Set the list contents of the named field to the specified list
-- @function setList
-- @param ref Name of field
-- @param list Contents of the list field
-- @usage
-- menu.setList('items', { 'apple', 'orange', 'pear' })
        function menu.setList(ref, list)
            local r = menu.findField(ref)
            if r and r.setList then r.setList(list) end
        end

-------------------------------------------------------------------------------
-- Query if a field is currently enabled
-- @function enabled
-- @param ref Name of field
-- @return true iff the field is currently enabled
-- @usage
-- if menu.enabled('name') then print('name is '..menu.getValue('name')) end
        function menu.enabled(ref)
            local r = menu.findField(ref)
            return r and r.enabled()
        end

-------------------------------------------------------------------------------
-- Enable a field
-- @function enable
-- @param ref Name of field
-- @param state Boolean indicating if the field should be enabled (true)
-- or disabled (false)
-- @usage
-- menu.enable('name')
        function menu.enable(ref, state)
            local r = menu.findField(ref)
            if r then
                r.enabled = state and True or False
            end
        end

-------------------------------------------------------------------------------
-- Query if a field is currently read only
-- @function isReadonly
-- @param ref Name of field
-- @return true iff the field is currently read only
-- @usage
-- if not menu.isReadonly('name') then print('name can be changed') end
        function menu.isReadonly(ref)
            local r = menu.findField(ref)
            return r and r.readonly
        end

-------------------------------------------------------------------------------
-- Change the read only setting for a field
-- @function setReadonly
-- @param ref Name of field
-- @param state Boolean indicating if the field should be read only (true)
-- or writable (false)
-- @usage
-- menu.setReadonly('name')
        function menu.setReadonly(ref, state)
            local r = menu.findField(ref)
            if r then
                r.readonly = state and true or false
            end
        end

-------------------------------------------------------------------------------
-- Save menu values into a CSV file table.
-- The CSV table is saved to file if a name exists.
-- @function toCSV
-- @param t Filename for CSV table or CSV table or nil to make a new nameless table.
-- specified the CSV is saved to the file too.
-- @return CSV table
-- @see fromCSV
-- @usage
-- local csvTable = myMenu.toCSV('settings.csv')
        function menu.toCSV(t)
            if t == nil or type(t) == 'string' then
                t = { labels = { 'name', 'value' }, data = {}, fname = t }
            end
            for k, v in pairs(fields) do
                if v.getValue then
                    csv.addLineCSV(t, { k, v.getValue() })
                end
            end
            if t.fname then
                csv.saveCSV(t)
            end
            return t
        end

-------------------------------------------------------------------------------
-- Load values from the specified CSV file which was created by toCSV above.
-- @function fromCSV
-- @param t CSV table filename or CSV table
-- @see toCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvTable = csv.loadCSV { fname = 'settings.csv', labels = { 'name', 'value' } }
--
-- myMenu.fromCSV(csvTable)
        function menu.fromCSV(t)
            if type(t) == 'string' then
                t = csv.loadCSV { labels = { 'name', 'value' }, data = {}, fname = t }
            end
            local names = csv.getColCSV(t, 'name')
            local values = csv.getColCSV(t, 'value')

            for i = 1, #names do
                menu.setValue(names[i], values[i])
            end
        end

-------------------------------------------------------------------------------
-- Save menu values into a table.
-- @function getValues
-- @param doLabels True if the column labels are wanted, default not
-- @return Table containing all the fields from this menu
-- @return Labels for column headings, if doLabels is true
-- @see setValues
-- @see toCSV
-- @usage
-- local values = myMenu.setValues()
        function menu.getValues(doLabels)
            local r, labels = {}, doLabels and {} or nil
            for k, v in pairs(fields) do
                if v.getValue then
                    r[k] = v.getValue()
                    if labels then
                        table.insert(labels, k)
                    end
                end
            end
            return r, labels
        end
    end

-------------------------------------------------------------------------------
-- Load values from the table into this menu
-- @function setValues
-- @param t Table of values
-- @see getValues
-- @see fromCSV
-- @usage
-- local csv = require('rinLibrary.rinCSV')
-- local csvTable = csv.loadCSV { fname = 'settings.csv', labels = { 'name', 'value' } }
--
-- myMenu.fromCSV(csvTable)
        function menu.setValues(t)
            for k, v in pairs(t) do
                if fields[k] and fields[k].setValue then
                    fields[k].setValue(v)
                end
            end
        end

-------------------------------------------------------------------------------
-- Move the current position in the menu inthe direction indicated
-- @param dirn Direction +1 or -1
-- @local
    local function move(dirn)
        local p = posn
        for i = 1, #menu do
            p = private.addModBase1(p, dirn, #menu, menu.loop)
            if menu[p].enabled() then
                hide(menu[posn])
                posn = p
                show(menu[posn])
                break
            end
        end
    end

-------------------------------------------------------------------------------
-- Move the curent position in the menu to an enabled item.  The scanning
-- first looks at nearby elements first and expands outwards until the entire
-- menu is checked.
-- the loop setting.
-- @local
    local function findEnabled()
        for i = 0, 2*#menu do
            local p = posn + math.floor((i+1) * 0.5) * (1 - 2*(i%2))
            if menu[p] and menu[p].enabled() then
                posn = p
                break
            end
        end
        show(menu[posn])
    end

-------------------------------------------------------------------------------
-- Display and execute a menu
-- @return true if exit via EXIT item, false if exit via cancel
-- @local
    local function runMenu()
        local okay = true
        menu.inProgress = true
        if not rememberPosition then posn = 1 end
        findEnabled()
        _M.write('bottomRight', getPrompt(menu))
        while _M.app.isRunning() and menu.inProgress do
            update(menu[posn])
            local key = _M.getKey('arrow')
            if key == 'down' then
                move(1)
            elseif key == 'up' then
                move(-1)
            elseif key == 'ok' then
                local m = menu[posn]
                hide(m)     run(m)      findEnabled()
                _M.write('bottomRight', getPrompt(menu))
                if m.exit == true then menu.finish() end
            end
            if not _M.dialogRunning() or key == 'cancel' then
                menu.finish()
                okay = false
            end
        end
        hide(menu[posn])
        return okay
    end

-------------------------------------------------------------------------------
-- Display and execute a menu
-- @function run
-- @return true if exit via EXIT item, false if exit via cancel
-- @usage
-- local mymenu = device.createMenu {'MENU'}.string { 'NAME', 'Ethyl' }
-- mymenu.run()
    if parent == nil then
        -- For the main root menu, do some extra bring up & pull down
        local leave = cb(args.leave, null)
        menu.run = function()
            local restore = _M.saveDisplay()
            local finished = _M.startDialog()
            local okay = runMenu()
            finished()
            restore()
            leave(okay)
            return okay
        end
    else
        -- for submenus, we just run the menu
        menu.run = runMenu
    end

    return menu
end

-------------------------------------------------------------------------------
-- Create a new empty parent menu
-- @param args Defining menu arguments
-- @return The menu
-- @see FieldDefinition
-- @usage
-- local mymenu = createMenu {'MENU'} . string { 'NAME', 'Bob' }
-- mymenu.run()
function _M.createMenu(args)
    return makeMenu(args, nil, {})
end

end
