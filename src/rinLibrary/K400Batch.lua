-------------------------------------------------------------------------------
--- Batching scale functions.
-- Functions to support the K410 Batching and products
-- @module rinLibrary.K400Batch
-- @author Pauli
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)

private.addRegisters{
    product_total_weight            = 0xB102,
    product_total_alt_weight        = 0xB103,
    product_total_count             = 0xB104,
    product_total_number            = 0xB105
}

-------------------------------------------------------------------------------
-- Query the number of materials available in the display.
-- @return Number of material slots in display's database
-- @usage
-- print('We can deal with '..device.getMaterialCount()..' materials.')
function _M.getMaxMaterialCount()
    return 1
end

-------------------------------------------------------------------------------
-- Query the number of batching stages available in the display.
-- @return Number of batching stages in display's database
-- @usage
-- print('We can deal with '..device.getStageCount()..' stages.')
function _M.getMaxStageCount()
    return 0
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

        local numStages = 10
        local numMaterials = private.valueByDevice{ k410=1, k411=6, k412=20, k415=6 }

        _M.getMaxStageCount =       function() return numStages end
        _M.getMaxMaterialCount =    function() return numMaterials end

        for i = 1, numMaterials do          -- Material registers for each material
            private.addRegisters{ ['material_name'..i] = 0xC080 + i }
            local f = (i-1) * 0x10
            for k, v in pairs{
                flt                 = 0xC101,
                medium              = 0xC102,
                fast                = 0xC103,
                total               = 0xC104,
                num                 = 0xC105,
                error               = 0xC106,
                error_pc            = 0xC107,
                error_average       = 0xC108
            } do
                private.addRegisters{ ['material_'..k..i] = v + f }
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

end
