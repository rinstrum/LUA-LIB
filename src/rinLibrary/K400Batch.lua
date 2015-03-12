-------------------------------------------------------------------------------
--- Batching scale functions.
-- Functions to support the K410 Batching and products
-- @module rinLibrary.K400Batch
-- @author Pauli
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local csv       = require 'rinLibrary.rinCSV'
local canonical = require('rinLibrary.namings').canonicalisation
local dbg       = require "rinLibrary.rinDebug"
local utils     = require 'rinSystem.utilities'
local naming    = require 'rinLibrary.namings'

local deepcopy = utils.deepcopy
local null, cb = utils.null, utils.cb

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)
local numStages, numMaterials = 0, 0

-------------------------------------------------------------------------------
-- Query the number of materials available in the display.
-- @return Number of material slots in display's database
-- @usage
-- print('We can deal with '..device.getNativeMaterialCount()..' materials.')
function _M.getNativeMaterialCount()
    return numMaterials
end

-------------------------------------------------------------------------------
-- Query the number of batching stages available in the display.
-- @return Number of batching stages in display's database
-- @usage
-- print('We can deal with '..device.getNativeStageCount()..' stages.')
function _M.getNativeStageCount()
    return numStages
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule register definitions hinge on the model type
private.registerDeviceInitialiser(function()
    local batching = private.batching(true)
    local recipes, materialCSV, recipesCSV = {}
    local materialRegs, stageRegisters = {}, {}
    local stageDevice = _M

    local stageTypes = {
        none = 0,   fill = 1,   dump = 2,   pulse = 3,
        --start = 4
    }

    if batching then
        numStages = 10
        numMaterials = private.valueByDevice{ default=1, k411=6, k412=20, k415=6 }

        private.addRegisters{
            product_time            = 0xB106,
            product_time_average    = 0xB107,
            product_error           = 0xB108,
            product_error_pc        = 0xB109,
            product_error_average   = 0xB10A,
            product_menu_op_stages  = 0xB10B,
            material_spec           = 0xC100,
        }

-------------------------------------------------------------------------------
-- Add a block of registers to the register file
-- Update the definition table so the value is the register name
-- @param prefix Prefix to be applied to the register name
-- @param regs Table of register and base step pairs.
-- @param qty Number of times to step for these registers
-- @local
        local function blockRegs(prefix, regs, qty)
            local adds = {}
            for name, v in pairs(regs) do
                local n = prefix..name
                adds[n] = v[1]
                if qty > 1 then
                    for i = 1, qty do
                        adds[n..i] = v[1] + (i-1) * v[2]
                    end
                end
                regs[name] = n
            end
            dbg.info('registers:', adds)
            private.addRegisters(adds)
        end

        -- Load material register names into the register database
        materialRegs = {
            name                = { 0xC081, 0x01 },
            flight              = { 0xC101, 0x10 },
            medium              = { 0xC102, 0x10 },
            fast                = { 0xC103, 0x10 },
            total               = { 0xC104, 0x10 },
            num                 = { 0xC105, 0x10 },
            error               = { 0xC106, 0x10 },
            error_pc            = { 0xC107, 0x10 },
            error_average       = { 0xC108, 0x10 }
        }
        blockRegs('material_', materialRegs, numMaterials)

        -- Load stage register names into the register database
        stageRegisters = {
            type                = { 0xC400, 0x0100 },
            fill_slow           = { 0xC401, 0x0100 },
            fill_medium         = { 0xC402, 0x0100 },
            fill_fast           = { 0xC403, 0x0100 },
            fill_ilock          = { 0xC404, 0x0100 },
            fill_output         = { 0xC405, 0x0100 },
            fill_feeder         = { 0xC406, 0x0100 },
            fill_material       = { 0xC407, 0x0100 },
            fill_start_action   = { 0xC408, 0x0100 },
            fill_correction     = { 0xC409, 0x0100 },
            fill_jog_on         = { 0xC40A, 0x0100 },
            fill_jog_off        = { 0xC40B, 0x0100 },
            fill_jog_set        = { 0xC40C, 0x0100 },
            fill_delay_start    = { 0xC40D, 0x0100 },
            fill_delay_check    = { 0xC40E, 0x0100 },
            fill_delay_end      = { 0xC40F, 0x0100 },
            fill_max_set        = { 0xC412, 0x0100 },
            fill_input          = { 0xC413, 0x0100 },
            fill_direction      = { 0xC414, 0x0100 },
            fill_input_wait     = { 0xC415, 0x0100 },
            fill_source         = { 0xC416, 0x0100 },
            fill_pulse_scale    = { 0xC417, 0x0100 },
            fill_tol_lo         = { 0xC420, 0x0100 },
            fill_tol_high       = { 0xC421, 0x0100 },
            fill_tol_target     = { 0xC422, 0x0100 },
            dump_dump           = { 0xC440, 0x0100 },
            dump_output         = { 0xC441, 0x0100 },
            dump_enable         = { 0xC442, 0x0100 },
            dump_ilock          = { 0xC443, 0x0100 },
            dump_type           = { 0xC444, 0x0100 },
            dump_correction     = { 0xC445, 0x0100 },
            dump_delay_start    = { 0xC446, 0x0100 },
            dump_delay_check    = { 0xC447, 0x0100 },
            dump_delay_end      = { 0xC448, 0x0100 },
            dump_jog_on_time    = { 0xC449, 0x0100 },
            dump_jog_off_time   = { 0xC44A, 0x0100 },
            dump_jog_set        = { 0xC44B, 0x0100 },
            dump_target         = { 0xC44C, 0x0100 },
            dump_pulse_time     = { 0xC44D, 0x0100 },
            dump_on_tol         = { 0xC44E, 0x0100 },
            dump_off_tol        = { 0xC44F, 0x0100 },
            pulse_output        = { 0xC460, 0x0100 },
            pulse_pulse         = { 0xC461, 0x0100 },
            pulse_delay_start   = { 0xC462, 0x0100 },
            pulse_delay_end     = { 0xC463, 0x0100 },
            pulse_start_action  = { 0xC464, 0x0100 },
            pulse_link          = { 0xC466, 0x0100 },
            pulse_time          = { 0xC467, 0x0100 },
            pulse_name          = { 0xC468, 0x0100 },
            pulse_prompt        = { 0xC469, 0x0100 },
            pulse_input         = { 0xC46A, 0x0100 },
            pulse_timer         = { 0xC46B, 0x0100 }
        }
        blockRegs('stage_', stageRegisters, numStages)
    end

-------------------------------------------------------------------------------
-- Load the material and stage CSV files into memory.
-- This is done automatically on start up and you should only need to call this
-- function when the files have been modified (e.g. via a load from USB).
-- @function loadBatchingDetails
-- @usage
-- device.loadBatchingDetails()  -- reload the batching databases
    private.exposeFunction('loadBatchingDetails', batching, function()
        materialCSV = csv.loadCSV{ fname = 'materials.csv' }

        recipesCSV = csv.loadCSV{
            fname = 'recipes.csv',
            labels = { 'recipe', 'datafile' }
        }

        recipes = {}
        for _, r in csv.records(recipesCSV) do
            recipes[canonical(r.recipe)] = csv.loadCSV {
                fname = r.datafile
            }
        end
    end)
    if batching then
        _M.loadBatchingDetails()
    end

-------------------------------------------------------------------------------
-- Return a material CSV record
-- @function getMaterial
-- @param m Material name
-- @return CSV record for the given material or nil on error
-- @return Error message or nil for no error
-- @usage
-- local sand = device.getMaterial('sand')
    private.exposeFunction('getMaterial', batching, function(m)
        local _, r = csv.getRecordCSV(materialCSV, m, 'name')
        if r == nil then
            return nil, 'Material does not exist'
        end
        return r
    end)

-------------------------------------------------------------------------------
-- Set the current material in the indicator
-- @function setMaterialRegisters
-- @param m Material name to set to
-- @return nil if success, error message if failure
-- @usage
-- device.setCurrentMaterial 'sand'
    private.exposeFunction('setMaterialRegisters', batching, function(m)
        local rec, err = _M.getMaterial(m)
        if err == nil then
            for name, reg in pairs(materialRegs) do
                local v = rec[name]
                if v and v ~= '' then
                    _M.setRegister(reg, v)
                end
            end
        end
    end)

-------------------------------------------------------------------------------
-- Set the current stage in the indicator
-- @function setStageRegisters
-- @param S Stage record to set to
-- @usage
-- device.setStageRegisters { type='', fill_slow=1 }
    private.exposeFunction('setStageRegisters', batching, function(s)
        local type = s.type or 'none'
        local tlen = type:len()

        _M.setRegister('stage_type', naming.convertNameToValue(type, stageTypes, 0))

        for name, reg in pairs(stageRegisters) do
            if name:sub(1, tlen) == type then
                local v = s[name]
                if v and v ~= '' then
                    if name == 'fill_material' then
                        _M.setMaterialRegisters(v)
                        v = 0
                    end
                    _M.setRegister(reg, v)
                end
            end
        end

        stageDevice = s.device or _M
    end)

-------------------------------------------------------------------------------
-- Return a CSV file that contains the stages in a specified recipe.
-- @param r Names of recipe
-- @return Recipe CSV table or nil on error
-- @return Error indicator or nil for no error
-- @usage
-- local cementCSV = device.getRecipe 'cement'
    private.exposeFunction('getRecipe', batching, function(r)
        local rec = csv.getRecordCSV(recipesCSV, r, 'recipe')
        if rec == nil then
            return nil, 'recipe does not exist'
        end
        local z = recipes[canonical(rec.recipe)]
        return z, nil
    end)

-------------------------------------------------------------------------------
-- Return a CSV file that contains the stages in a user selected recipe.
-- @param prompt User prompt
-- @param default Default selection, nil for none
-- @return Recipe CSV table or nil on error
-- @return Error indicator or nil for no error
-- @usage
-- local cementCSV = device.getRecipe 'cement'
    private.exposeFunction('selectRecipe', batching, function(prompt, default)
        local recipes = csv.getColCSV(recipesCSV, 'recipe')
        local q = _M.selectOption(prompt or 'RECIPE', recipes, default)
        if q ~= nil then
            return _M.getRecipe(q)
        end
        return nil, 'cancelled'
    end)

-------------------------------------------------------------------------------
-- Run a stage.  Wait until it begins before returning.
-- @param stage Stage record to run
-- @usage
--
    private.exposeFunction('runStage', batching, function(stage)
        
    end)

-------------------------------------------------------------------------------
-- Return the start delay associated with the specified stage or 0 if not defined
-- @param stage Stage record to query
-- @return stage delay
-- @local
    local function startDelay(stage)
        return stage[(stage.type or '')..'_delay_start'] or 0
    end

-------------------------------------------------------------------------------
-- Run a batching process, controlled by a FSM.
--
-- The machine has a <i>start</i> state, a <i>begin</i> state from which the batching
-- will begin and progress until it reaches a <i>finish</i> state.  You need to define
-- the transitions from start to begin and from finish back to start or begin.  You are
-- also free to add you own states before or after these three.
-- @function recipeFSM
-- @param args Batching recipe arguments
-- The arguments consist of the first positional parameter, <i>name</i> which defines
-- the recipe to use.
--
-- Optionally, you can specify a <i>minimumTime</i> that must elapse before a batch stage
-- can be considered complete.  This is a function that is passed a stage record and
-- it should return the minimum number of seconds that this stage must remain active.
-- This function is called before any of the batching takes place so the time returned
-- is immutable.  By default, there is no minimum time.
--
-- Optionally, you can specify a <i>start</i> function that is passed a stage table and it
-- must initiate this stage.  By default, the usual batching process will be used.
--
-- Optionally, you can specify a <i>finished</i> function that is also passed a stage
-- table and must return true if that stage has finished.
--
-- Finally, you can optionally pass a <i>device</i> function that returns the display
-- device this stage runs on.  It is passed a device name from the stage CSV file.  By
-- default, it returns this device.
-- @return Finite state machine or nil on error
-- @return Error code or nil on success
-- @usage
-- local fsm = device.recipeFSM 'cement'
-- fsm.trans { 'start', 'begin', event='begin' }
-- fsm.trans { 'finish', 'start', event='restart' }
-- rinApp.setMainLoop(fsm.run)
    private.exposeFunction('recipeFSM', batching, function(args)
        local rname = args[1] or args.name
        local recipe, err = _M.getRecipe(rname)
        if err then return nil, err end

        local deviceFinder = cb(args.device, function() return _M end)
        local deviceStart = deepcopy(args.start or function()
            return function(stage)
                local d = deviceFinder(stage.device)
                d.setStageRegisters(stage)
                d.runStage(stage)
            end
        end)
        local deviceFinished = deepcopy(args.finished or function()
            return function(stage)
                local d = deviceFinder(stages[i].device)
                return d.allStatusSet('idle')
            end
        end)
        local minimumTime = deepcopy(args.minimumTime or function() return 0 end)

        -- Extract the stages from the recipe CSV in a useable manner
        if csv.numRowsCSV(recipe) < 1 then return nil, 'no stages' end

        local stages = {}
        for i = 1, csv.numRowsCSV(recipe) do
            table.insert(stages, csv.getRowRecord(recipe, i))
        end
        table.sort(stages, function(a, b) return a.order < b.order end)

        -- Execute the stages sequentially in a FSM
        local pos, prev = 1, nil
        local blocks = { }
        while pos <= #stages do
            local e = pos+1
            table.insert(blocks, { idx=pos, name='ST'..(stages[pos].order or pos)})
            if stages[pos].order then
                while e <= #stages and stages[pos].order == stages[e].order do
                    e = e + 1
                end
            end
            pos = e
        end
        table.insert(blocks, { idx=1+#stages, name='finish' })

        -- Sanity check to prevent using the same device twice
        for bi = 1, #blocks-1 do
            local b1, b2 = blocks[bi], blocks[bi+1]
            local used = {}
            for i = b1.idx, b2.idx-1 do
                local d = stages[i].device or _M
                if used[d] then
                    return nil, 'duplicate device in stage '..stages[b1.idx].order
                end
                used[d] = true
            end
        end

        -- Build the FSM states
        local fsm = _M.stateMachine { rname }
                        .state { 'start' }
                        .state { 'begin' }
                        .state { 'finish' }
        for bi = 1, #blocks-1 do
            local b1, b2 = blocks[bi], blocks[bi+1]
            local function startStage()
                for i = b1.idx, b2.idx-1 do
                    deviceStart(stages[i])
                end
            end
            fsm.state { b1.name, enter=startStage }
        end

        -- Add transitions to the FSM
        fsm.trans { 'begin', blocks[1].name }
        for bi = 1, #blocks-1 do
            local b1, b2 = blocks[bi], blocks[bi+1]
            local mt = 0
            for i = b1.idx, b2.idx-1 do
                mt = math.max(mt, minimumTime(stages[i]), startDelay(stages[i]))
            end

            local function testStage()
                for i = b1.idx, b2.idx-1 do
                    if not deviceFinished(stages[i]) then
                        return false
                    end
                end
                return true
            end
            fsm.trans { b1.name, b2.name, cond=testStage, time=mt }
        end

        return fsm, nil
    end)

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

--- Batching Registers
--
-- These registers define the extra information about materials and the batch stages.
-- In all cases below, replace the <i>X</i> by an integer 1 .. ? that represents the
-- material or stage of interest.  Additionally, all are available without the X and,
-- in this case, the 1 is implied.
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

end)
end
