-------------------------------------------------------------------------------
--- Multiple selection list handling functions.
-- @module rinLibrary.multiselect
-- @author Pauli
-- @copyright 2014 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

return function()
    local _M = {}
    local optionList = {}

-------------------------------------------------------------------------------
-- Build a list of names that are positively filtered by the specified function
-- @param f Filter function.
-- @return List of matching options
-- @local
    local function filter(f)
        local r = {}
        for n, v in pairs(optionList) do
            if f(v) then
                table.insert(r, n)
            end
        end
        return r
    end

-------------------------------------------------------------------------------
-- Apply the given function to each option named in the list
-- @param l List of options
-- @param f Function to apply to each option.
-- @local
    local function map(l, f)
        for _, v in pairs(l) do
            if optionList[v] ~= nil then f(optionList[v]) end
        end
    end

-------------------------------------------------------------------------------
-- Apply the given function to all options
-- @param f Function to apply to each option.
-- @local
    local function mapAll(f)
        for _, v in pairs(optionList) do f(v) end
    end

-------------------------------------------------------------------------------
-- Return a list of all the options currently in the table
-- @return List of option names
-- @usage
-- local t = options.get()
    function _M.get()
        local r = filter(function() return true end)
        table.sort(r)
        return r
    end

-------------------------------------------------------------------------------
-- Set the options, without removing any existing options
-- @param ... Option names
-- @usage
-- options.set('hello', 'good bye', 'meow')
    function _M.set(...)
        for _, opt in pairs{...} do
            if optionList[opt] == nil then
                optionList[opt] = { selected=false }
            end
        end
    end

-------------------------------------------------------------------------------
-- Clear the specified options
-- @param ... Option names
-- @usage
-- options.clear('hello')
    function _M.clear(...)
        for _, opt in pairs{...} do
            optionList[opt] = nil
        end
    end

-------------------------------------------------------------------------------
-- Clear all options
-- @usage
-- options.clearAll()
    function _M.clearAll()
        optionList = {}
    end

-------------------------------------------------------------------------------
-- Set the specified options, all existing options are removed
-- @param ... Option names
-- @usage
-- options.setAll('hello', 'good bye', 'meow')
    function _M.setAll(...)
        _M.clearAll()
        _M.set(...)
    end

-------------------------------------------------------------------------------
-- Return a list of all the selected options currently in the table
-- @return List of selected option names
-- @usage
-- local t = options.getSelected()
    function _M.getSelected()
        return filter(function(v) return v.selected end)
    end

-------------------------------------------------------------------------------
-- Return true if the option is selected
-- @param opt Option name
-- @return True iff the option is selected
-- @usage
-- if options.isSelected('hello') then ... end
    function _M.isSelected(opt)
        return optionList[opt] ~= nil and optionList[opt].selected
    end

-------------------------------------------------------------------------------\
-- Select all options in the table
-- @usage
-- options.selectAll()
    function _M.selectAll()
        mapAll(function(v) v.selected = true end)
    end

-------------------------------------------------------------------------------
-- Deselect all options in the table
-- @usage
-- options.deselectAll()
    function _M.deselectAll()
        mapAll(function(v) v.selected = false end)
    end

-------------------------------------------------------------------------------
-- Select sepcifiec options in the table
-- @param ... Names of options to select
-- @usage
-- options.select('hello', 'meow')
    function _M.select(...)
        map({...}, function(v) v.selected = true end)
    end

-------------------------------------------------------------------------------
-- Select sepcifiec options in the table, deselecting all others
-- @param ... Names of options to select
-- @usage
-- options.selectOnly('meow')
    function _M.selectOnly(...)
        _M.deselectAll()
        _M.select(...)
    end

-------------------------------------------------------------------------------
-- Deselect sepcifiec options in the table
-- @param ... Names of options to deselect
-- @usage
-- options.deselect('hello')
    function _M.deselect(...)
        map({...}, function(v) v.selected = false end)
    end

-------------------------------------------------------------------------------
-- Flip the selected state of the given options
-- @param ... Names of options to deselect
-- @usage
-- options.toggle('good bye')
    function _M.toggle(...)
        map({...}, function(v) v.selected = not v.selected end)
    end

-------------------------------------------------------------------------------
    function _M.load(filename)
    end

    function _M.save(filename)
    end

    return _M
end

