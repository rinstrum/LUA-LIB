-------------------------------------------------------------------------------
--- Menuing Functions.
-- An easy to use menuing subsystem
-- @module rinLibrary.K400Menu
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------
local dbg = require "rinLibrary.rinDebug"
local canonical = require('rinLibrary.namings').canonicalisation

return function (_M, private, deprecated)

-------------------------------------------------------------------------------
-- Create a new empty menu
-- @param name Display name of the menu
-- @param parent Menu's parent menu
-- @fields Table of all fields defined
-- @return The menu
-- @local
local function makeMenu(name, parent, fields)
    local menu
    local posn = 1

    local function newItem(args)
        local name = args[1]
        local prompt = args.prompt or name
        if type(prompt) == 'string' then
            prompt = string.upper(prompt)
        end

        r = {
            name = name,
            ref = canonical(args.ref or name),
            prompt = prompt,
            units = args.units or 'none',
            unitsOther = args.unitsOther or 'none',

            run = args.run or function() print(name .. ' has no run function') end,
            show = args.show or function()
                _M.write('bottomRight', prompt)
                _M.writeUnits('bottomLeft', units, unitsOther)
            end,
            hide = args.hide or function() end,
            update = args.update or function()
                _M.write('bottomLeft', string.upper(menu[posn].name))
            end,
            getValue = args.getValue or function(v) return nil end,
            setValue = args.setValue or function(v) end
        }
        return r
    end
    menu = newItem {name}

    local function add(item)
        table.insert(menu, item)
        fields[item.ref] = item
        return menu
    end

    local function numericEdit(args, type)
        local item = newItem(args)
        local value = args[2] or 0
        local min, max = args.min, args.max

        item.run = function()
            local v, ok = _M.edit(item.prompt, value, type, item.units, item.unitsOther)
            if ok then
                if min then v = math.max(min, v) end
                if max then v = math.min(max, v) end
                value = v
            end
        end
        item.getValue = function() return value end
        item.setValue = function(v) value = v end
        return add(item)
    end

    function menu.integer(args)
        return numericEdit(args, 'integer')
    end

    function menu.number(args)
        return numericEdit(args, 'number')
    end

    function menu.passcode(args)
        return numericEdit(args, 'passcode')
    end

    function menu.string(args)
        local item = newItem(args)
        local value = args[2] or 0
        local len = args[3]

        item.run = function()
            local v, ok = _M.sEdit(item.prompt, value, len, item.units, item.unitsOther)
            if ok then
                value = v
            end
        end
        item.getValue = function() return value end
        item.setValue = function(v) value = v end
        return add(item)
    end

    function menu.register(args)
        local item = newItem(args)

        item.run = function()
            _M.editReg(args[2], item.prompt)
        end
        return add(item)
    end

    function menu.auto(args)
        local item = newItem(args)
        item.run = function()
            _M.saveBot()
            _M.write('bottomRight', item.name)
            _M.writeAuto('bottomLeft', args[2])
            _M.getKey()
            _M.restoreBot()
            _M.writeAuto('bottomLeft', 'none')
        end
        return add(item)
    end

    function menu.list(args)
        local value = args.default or args[2][1]
        local loop = args.loop

        local item = makeMenu(args[1], menu)
        item.run = function()
            local v = _M.selectOption(item.prompt, args[2], value, loop, item.units, item.unitsOther)
            if v then
                value = v
            end
        end
        item.getValue = function() return value end
        item.setValue = function(v) value = v end
        return add(item)
    end

    function menu.menu(args)
        local item = makeMenu(args[1], menu, fields)
        add(item)
        return item
    end

    function menu.fin(args)
        if parent then
            return parent
        else
            dbg.error('menu:', 'Too many fin elements')
        end
        return menu
    end

    function menu.exit(args)
        local item = newItem(args)
        item.run = function() menu.inProgress = false end
        return add(item)
    end

    function menu.item(args)
        return add(newItem(args))
    end

    function menu.run()
        menu.inProgress = true
        while _M.app.isRunning() and menu.inProgress do
            menu.update()
            local key = _M.getKey('arrow')
            if not _M.dialogRunning() or key == 'cancel' then
                menu.inProgress = false
            elseif key == 'down' then
                posn = private.addModBase1(posn, 1, #menu, false)
            elseif key == 'up' then
                posn = private.addModBase1(posn, -1, #menu, false)
            elseif key == 'ok' then
                menu.hide()
                menu[posn].show()
                menu[posn].run()
                menu[posn].hide()
                menu.show()
            end
        end
    end

    return menu
end

-------------------------------------------------------------------------------
-- Create a new empty parent menu
-- @param name Display name of the menu
-- @return The menu
function _M.createMenu(name)
    local fields = {}
    local menu = makeMenu(name, nil, fields)
    local r = menu.run

-------------------------------------------------------------------------------
    menu.run = function()
        _M.saveBot()
        _M.startDialog()
        menu.show()
        r()
        menu.hide()
        _M.abortDialog()
        _M.restoreBot()
        _M.write('bottomleft', '')
        _M.write('bottomright', '')
    end

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
        return r and r.getValue() or nil
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
        if r then r.setValue(value) end
    end

    return menu
end

end
