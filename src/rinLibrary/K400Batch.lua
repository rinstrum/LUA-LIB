-------------------------------------------------------------------------------
--- Batching scale functions.
-- Functions to support the K410 Batching and products
-- @module rinLibrary.K400Batch
-- @author Pauli
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local csv       = require 'rinLibrary.rinCSV'
local canonical = require('rinLibrary.namings').canonicalisation

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)
local numStages, numMaterials = 0, 1

-------------------------------------------------------------------------------
-- Query the number of materials available in the display.
-- @return Number of material slots in display's database
-- @usage
-- print('We can deal with '..device.getMaterialCount()..' materials.')
function _M.getMaxMaterialCount()
    return numMaterials
end

-------------------------------------------------------------------------------
-- Query the number of batching stages available in the display.
-- @return Number of batching stages in display's database
-- @usage
-- print('We can deal with '..device.getStageCount()..' stages.')
function _M.getMaxStageCount()
    return numStages
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule register definitions hinge on the model type
private.registerDeviceInitialiser(function()
    if private.batching(true) then
        private.addRegisters{
            product_time            = 0xB106,
            product_time_average    = 0xB107,
            product_error           = 0xB108,
            product_error_pc        = 0xB109,
            product_error_average   = 0xB10A,
            product_menu_op_stages  = 0xB10B,
            material_spec           = 0xC100,
        }

        numStages = 10
        numMaterials = private.valueByDevice{ k410=1, k411=6, k412=20, k415=6 }

        private.addRegisters{ material_name = 0xC081 }
        for i = 1, numMaterials do          -- Material registers for each material
            private.addRegisters{ ['material_name'..i] = 0xC080 + i }
            local f = (i-1) * 0x10
            for k, v in pairs{
                flight              = 0xC101,
                medium              = 0xC102,
                fast                = 0xC103,
                total               = 0xC104,
                num                 = 0xC105,
                error               = 0xC106,
                error_pc            = 0xC107,
                error_average       = 0xC108
            } do
                private.addRegisters{ ['material_'..k..i] = v + f }
                if i == 1 then
                    private.addRegisters{ ['material_'..k] = v + f }
                end
            end
        end

        for k, v in pairs{                  -- Base registers for each batching stage
            type                = 0xC400,
            fill_slow           = 0xC401,
            fill_medium         = 0xC402,
            fill_fast           = 0xC403,
            fill_ilock          = 0xC404,
            fill_output         = 0xC405,
            fill_feeder         = 0xC406,
            fill_material       = 0xC407,
            fill_start_action   = 0xC408,
            fill_correction     = 0xC409,
            fill_jog_on         = 0xC40A,
            fill_jog_off        = 0xC40B,
            fill_jog_set        = 0xC40C,
            fill_delay_start    = 0xC40D,
            fill_delay_check    = 0xC40E,
            fill_delay_end      = 0xC40F,
            fill_max_set        = 0xC412,
            fill_input          = 0xC413,
            fill_direction      = 0xC414,
            fill_input_wait     = 0xC415,
            fill_source         = 0xC416,
            fill_pulse_scale    = 0xC417,
            fill_tol_lo         = 0xC420,
            fill_tol_high       = 0xC421,
            fill_tol_target     = 0xC422,
            dump_dump           = 0xC440,
            dump_output         = 0xC441,
            dump_enable         = 0xC442,
            dump_ilock          = 0xC443,
            dump_type           = 0xC444,
            dump_correction     = 0xC445,
            dump_delay_start    = 0xC446,
            dump_delay_check    = 0xC447,
            dump_delay_end      = 0xC448,
            dump_jog_on_time    = 0xC449,
            dump_jog_off_time   = 0xC44A,
            dump_jog_set        = 0xC44B,
            dump_target         = 0xC44C,
            dump_pulse_time     = 0xC44D,
            dump_on_tol         = 0xC44E,
            dump_off_tol        = 0xC44F,
            pulse_output        = 0xC460,
            pulse_pulse         = 0xC461,
            pulse_delay_start   = 0xC462,
            pulse_delay_end     = 0xC463,
            pulse_start_action  = 0xC464,
            pulse_link          = 0xC466,
            pulse_time          = 0xC467,
            pulse_name          = 0xC468,
            pulse_prompt        = 0xC469,
            pulse_input         = 0xC46A,
            pulse_timer         = 0xC46B
        } do
            for i = 1, numStages do
                private.addRegisters{ ['stage_'..k..i] = v + (i - 1) * 0x0100 }
            end
        end
    end
end)

--- Batching Registers
--
-- These registers define the extra information about materials and the batch stages.
-- In all cases below, replace the <i>X</i> by an integer 1 .. ? that represents the
-- material or stage of interest.
--@table batchingRegisters
-- @field material_spec ?
-- @field material_nameX name of the Xth material
-- @field material_flightX flight for the Xth material
-- @field material_mediumX medium for the Xth material
-- @field material_fastX fast for the Xth material
-- @field material_totalX total for the Xth material
-- @field material_numX num for the Xth material
-- @field material_errorX error for the Xth material
-- @field material_error_pcX error_pc for the Xth material
-- @field material_error_averageX error_average for the Xth material
-- @field product_time ?
-- @field product_time_average ?
-- @field product_error ?
-- @field product_error_pc ?
-- @field product_error_average ?
-- @field product_menu_op_stages ?
-- @field stage_typeX for the Xth stage
-- @field stage_fill_slowX for the Xth stage
-- @field stage_fill_mediumX for the Xth stage
-- @field stage_fill_fastX for the Xth stage
-- @field stage_fill_ilockX for the Xth stage
-- @field stage_fill_outputX for the Xth stage
-- @field stage_fill_feederX for the Xth stage
-- @field stage_fill_materialX for the Xth stage
-- @field stage_fill_start_actionX for the Xth stage
-- @field stage_fill_correctionX for the Xth stage
-- @field stage_fill_jog_onX for the Xth stage
-- @field stage_fill_jog_offX for the Xth stage
-- @field stage_fill_jog_setX for the Xth stage
-- @field stage_fill_delay_startX for the Xth stage
-- @field stage_fill_delay_checkX for the Xth stage
-- @field stage_fill_delay_endX for the Xth stage
-- @field stage_fill_max_setX for the Xth stage
-- @field stage_fill_inputX for the Xth stage
-- @field stage_fill_directionX for the Xth stage
-- @field stage_fill_input_waitX for the Xth stage
-- @field stage_fill_sourceX for the Xth stage
-- @field stage_fill_pulse_scaleX for the Xth stage
-- @field stage_fill_tol_loX for the Xth stage
-- @field stage_fill_tol_highX for the Xth stage
-- @field stage_fill_tol_targetX for the Xth stage
-- @field stage_dump_dumpX for the Xth stage
-- @field stage_dump_outputX for the Xth stage
-- @field stage_dump_enableX for the Xth stage
-- @field stage_dump_ilockX for the Xth stage
-- @field stage_dump_typeX for the Xth stage
-- @field stage_dump_correctionX for the Xth stage
-- @field stage_dump_delay_startX for the Xth stage
-- @field stage_dump_delay_checkX for the Xth stage
-- @field stage_dump_delay_endX for the Xth stage
-- @field stage_dump_jog_on_timeX for the Xth stage
-- @field stage_dump_jog_off_timeX for the Xth stage
-- @field stage_dump_jog_setX for the Xth stage
-- @field stage_dump_targetX for the Xth stage
-- @field stage_dump_pulse_timeX for the Xth stage
-- @field stage_dump_on_tolX for the Xth stage
-- @field stage_dump_off_tolX for the Xth stage
-- @field stage_pulse_outputX for the Xth stage
-- @field stage_pulse_pulseX for the Xth stage
-- @field stage_pulse_delay_startX for the Xth stage
-- @field stage_pulse_delay_endX for the Xth stage
-- @field stage_pulse_start_actionX for the Xth stage
-- @field stage_pulse_linkX for the Xth stage
-- @field stage_pulse_timeX for the Xth stage
-- @field stage_pulse_nameX for the Xth stage
-- @field stage_pulse_promptX for the Xth stage
-- @field stage_pulse_inputX for the Xth stage
-- @field stage_pulse_timerX for the Xth stage


-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Material database management.
-- We only use the first material but implement a full database of materials
-- as a CSV file.  This allows maximum compatibility with devices without
-- limiting anything

--- Material definition fields
--
-- These are the fields in the materials.csv material definition file.
-- They are loaded into and retrieved from the first material registers and
-- are intended to be used to allow an unlimited number of materials regardless
-- of the number of built in materials supported.
--@table MaterialFields
-- @field name Material name, this is the key field to specify a material by
-- @field flight flight
-- @field medium medium
-- @field fast fast
-- @field total total
-- @field num num
-- @field error error
-- @field error_pc error_pc
-- @field error_average error_average

private.registerDeviceInitialiser(function()
    local materialCSV
    local fields = {
                    'name', 'flight', 'medium', 'fast',
                    'total', 'num',
                    'error', 'error_pc', 'error_average'
                }
    local registers = {}
    for i = 1, #fields do
        --table.insert(registers, 'material_' .. fields[i] .. '1')
        table.insert(registers, 'material_' .. fields[i])
        private.addRegisters{ ['stage_'..k..i] = v + (i - 1) * 0x0100 }
        if i == 1 then
            private.addRegisters{ ['stage_'..k] = v }
        end
    end

-------------------------------------------------------------------------------
-- Open the material CSV file, if it isn't already opened.
-- @local
    local function openMaterialCSV()
        if materialCSV ~= nil then
            materialCSV = csv.openCSV{
                fname = 'materials.csv',
                labels = fields
            }
        end
    end

-------------------------------------------------------------------------------
-- Get the name of the curent material
-- @function getCurrentMaterial
-- @return Material name or nil on error
-- @return Error message
-- @usage
-- print('Current material is ' .. device.getCurrentMaterial())
    private.exposeFunction('getCurrentMaterial', private.batching(true), function()
        return _M.getRegister(registers[1])
    end)

-------------------------------------------------------------------------------
-- Save the current material settings from the display to the specified material
-- name.
-- @param m Material name
-- @local
    local function saveCurrent(m)
        if m then
            -- Save current settings
            local row = {}
            for i = 1, #registers do
                row[i] = _M.getRegister(registers[i])
            end
            openMaterialCSV()
            local n = csv.getLineCSV(materialCSV, m, fields[1])
            if n ~= nil then
                csv.replaceLineCSV(materialCSV, n, row)
            else
                csv.addLineCSV(materialCSV, row)
            end
            csv.saveCSV(materialCSV)
        end
    end

-------------------------------------------------------------------------------
-- Save the current material to the CSV file.
-- Use this function to synchronise the settings.
-- @usage
-- device.saveCurrentMaterial()
    private.exposeFunction('saveCurrentMaterial', private.batching(true), function()
        saveCurrent(_M.getCurrentMaterial())
    end)

-------------------------------------------------------------------------------
-- Set the current material by name
-- @function setCurrentMaterial
-- @param m Material name to set as current
-- @return Nil if success, error message if failure
-- @usage
-- device.setCurrentMaterial 'sand'
    private.exposeFunction('setCurrentMaterial', private.batching(true), function(m)
        local current = _M.getCurrentMaterial()
        saveCurrent(current)
        if m ~= current then
            openMaterialCSV()
            local n, row = csv.getLineCSV(materialCSV, m, fields[1])
            if row == nil then
                return 'Material does not exist'
            end
            for i = 1, #registers do
                _M.setRegister(registers[i], row[i])
            end
        end
    end)

-------------------------------------------------------------------------------
-- Delete a material by name from the database.
--
-- This does not change the current material in the display and this will be
-- resaved if it is the deleted material and the material is subsequently
-- changed.
-- @function deleteMaterial
-- @param m Material name to delete
-- @usage
-- device.deleteMaterial 'sand'
    private.exposeFunction('deleteMaterial', private.batching(true), function(m)
        local n = csv.getLineCSV(materialCSV, m, fields[1])
        if n ~= nil then
            csv.remLineCSV(materialCSV, n)
        end
    end)

-------------------------------------------------------------------------------
-- Edit the current material
-- @function editMaterial
-- @usage
-- device.editMaterial()
    private.exposeFunction('editMaterial', private.batching(true), function()
        local menu = makeMenu{ 'MATERIAL' }
        for i = 1, #registers do
            menu.register { fields[i], registers[i] }
        end
        menu.run()
        _M.saveCurrentMaterial()
    end)

-------------------------------------------------------------------------------
-- Choose a material from the list of materials
-- @function selectMaterial
-- @usage
-- device.selectMaterial()
    private.exposeFunction('selectMaterial', private.batching(true), function()
        openMaterialCSV()
        _M.saveCurrentMaterial()
        local names = csv.getColCSV(materialCSV, fields[1])
        for i = 1, #names do
            names[i] = string.upper(canonical(names[i]))
        end
        local new = selectOption('CHOOSE', names, _M.getCurrentMaterial(), true)
        if new then
            _M.setCurrentMaterial(new)
        end
        return new
    end)
end)

end
