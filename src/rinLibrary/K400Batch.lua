-------------------------------------------------------------------------------
--- Batching scale functions.
-- Functions to support the K410 Batching and products
-- @module rinLibrary.Device.Batch
-- @author Pauli
-- @copyright 2015 Rinstrum Pty Ltd
-------------------------------------------------------------------------------

local csv       = require 'rinLibrary.rinCSV'
local naming    = require 'rinLibrary.namings'
local dbg       = require "rinLibrary.rinDebug"
local utils     = require 'rinSystem.utilities'
local timers    = require 'rinSystem.rinTimers'

local canonical = naming.canonicalisation
local deepcopy = utils.deepcopy
local null, cb = utils.null, utils.cb

local pcall = pcall
local loadfile = loadfile
local os = os
local io = io
local pairs = pairs
local type = type

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule function begins here
return function (_M, private, deprecated)
local REG_REC_NAME_EX		= 0xB012	--	Recipe Name (used to rename K410 active recipe)

local numStages, numMaterials = 0, 0

-------------------------------------------------------------------------------
-- Query the number of materials available in the display.
-- @treturn int Number of material slots in display's database
-- @usage
-- print('We can deal with '..device.getNativeMaterialCount()..' materials.')
function _M.getNativeMaterialCount()
    return numMaterials
end

-------------------------------------------------------------------------------
-- Query the number of batching stages available in the display.
-- @treturn int Number of batching stages in display's database
-- @usage
-- print('We can deal with '..device.getNativeStageCount()..' stages.')
function _M.getNativeStageCount()
    return numStages
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -
-- Submodule register definitions hinge on the model type
private.registerDeviceInitialiser(function()
    local batching = private.batching(true)
    local recipes, materials = {}, {}
    local materialRegs, batchRegs = {}, {}
    local stageRegisters, extraStageRegisters = {}, {}
    local stageDevice = _M
    local materialRegisterInfo, stageRegisterInfo = {}, {}

    local REG_BATCH_STAGE_NUMBER    = 0xC005
    local REG_BATCH_START           = 0x0361
    local REG_BATCH_PAUSE           = 0x0362
    local REG_BATCH_ABORT           = 0x0363

    local stageTypes = {
        none = 0,   fill = 1,   dump = 2,   pulse = 3,  --start = 4
    }

    local enumMaps = {
        fill_start_action   = { none = 0, tare = 1, gross = 2 },
        fill_correction     = { flight = 0, jog = 1, auto_flight = 2, auto_jog = 3 },
        fill_direction      = { ['in'] = 0, out = 1 },
        fill_feeder         = { multiple = 0, single = 1 },
        dump_correction     = { none = 0, jog = 1 },
        dump_type           = { weight = 0, time = 1 },
        dump_on_tol         = { both = 0, ['in'] = 1, out = 2 },
        pulse_start_action  = { none = 0, tare = 1, gross = 2 },
        pulse_link          = { none = 0, prev = 1, next = 2 },
        pulse_timer         = { use = 0, ignore = 1 },
    }

    if batching then
        numStages = 10
        numMaterials = 1

-------------------------------------------------------------------------------
-- Add a block of registers to the register file
-- Update the definition table so the value is the register name
-- @param regs Table of register and base step pairs.
-- @param qty Number of times to step for these registers
-- @local
        local function blockRegs(regs, qty)
            local r, x = {}, {}
            for name, v in pairs(regs) do
                r[name] = v[1]
                for i = 1, qty do
                    x[name .. '_' .. i] = v[1] + (i-1) * v[2]
                end
            end
            return r, x
        end

        -- Load material register names into the register database
        materialRegisterInfo = {
            name                = { 0xC081, 0x01 },
            flight              = { 0xC101, 0x10 },
            medium              = { 0xC102, 0x10 },
            fast                = { 0xC103, 0x10 },
            total               = { 0xC104, 0x10, accumulator=true },-- MORE:change these to print tokens
            num                 = { 0xC105, 0x10, accumulator=true },
            error               = { 0xC106, 0x10, accumulator=true },
            error_pc            = { 0xC107, 0x10, accumulator=true },
            error_average       = { 0xC108, 0x10, accumulator=true }
        }
        materialRegs = blockRegs(materialRegisterInfo, numMaterials)

        -- Load stage register names into the register database
        stageRegisterInfo = {
            type                = { 0xC400, 0x0100, default='none' },
            fill_slow           = { 0xC401, 0x0100, default=0 },
            fill_medium         = { 0xC402, 0x0100, default=0 },
            fill_fast           = { 0xC403, 0x0100, default=0 },
            fill_ilock          = { 0xC404, 0x0100, default=0 },
            fill_output         = { 0xC405, 0x0100, default=0 },
            fill_feeder         = { 0xC406, 0x0100, default='multiple' },
            fill_material       = { 0xC407, 0x0100, default=0 },
            fill_start_action   = { 0xC408, 0x0100, default='none' },
            fill_correction     = { 0xC409, 0x0100, default='flight' },
            fill_jog_on_time    = { 0xC40A, 0x0100, default=0,      ms=true },
            fill_jog_off_time   = { 0xC40B, 0x0100, default=0,      ms=true },
            fill_jog_set        = { 0xC40C, 0x0100, default=0 },
            fill_delay_start    = { 0xC40D, 0x0100, default=0,      ms=true },
            fill_delay_check    = { 0xC40E, 0x0100, default=0,      ms=true },
            fill_delay_end      = { 0xC40F, 0x0100, default=0,      ms=true },
            fill_max_set        = { 0xC412, 0x0100, default=0 },
            fill_input          = { 0xC413, 0x0100, default=0 },
            fill_direction      = { 0xC414, 0x0100, default='in' },
            fill_input_wait     = { 0xC415, 0x0100, default=0 },
            fill_tol_lo         = { 0xC420, 0x0100, default=0 },
            fill_tol_high       = { 0xC421, 0x0100, default=0 },
            fill_target         = { 0xC422, 0x0100, default=0 },
            dump_dump           = { 0xC440, 0x0100, default=0 },
            dump_output         = { 0xC441, 0x0100, default=0 },
            dump_enable         = { 0xC442, 0x0100, default=0 },
            dump_ilock          = { 0xC443, 0x0100, default=0 },
            dump_type           = { 0xC444, 0x0100, default='weight' },
            dump_correction     = { 0xC445, 0x0100, default='none' },
            dump_delay_start    = { 0xC446, 0x0100, default=0,      ms=true },
            dump_delay_check    = { 0xC447, 0x0100, default=0,      ms=true },
            dump_delay_end      = { 0xC448, 0x0100, default=0,      ms=true },
            dump_jog_on_time    = { 0xC449, 0x0100, default=0,      ms=true },
            dump_jog_off_time   = { 0xC44A, 0x0100, default=0,      ms=true },
            dump_jog_set        = { 0xC44B, 0x0100, default=0 },
            dump_target         = { 0xC44C, 0x0100, default=0 },
            dump_pulse_time     = { 0xC44D, 0x0100, default=0,      ms=true },
            dump_on_tol         = { 0xC44E, 0x0100, default='both' },
            dump_off_tol        = { 0xC44F, 0x0100, default=0 },
            pulse_output        = { 0xC460, 0x0100, default=0 },
            pulse_pulse         = { 0xC461, 0x0100, default=0 },
            pulse_delay_start   = { 0xC462, 0x0100, default=0,      ms=true },
            pulse_delay_end     = { 0xC463, 0x0100, default=0,      ms=true },
            pulse_start_action  = { 0xC464, 0x0100, default='none' },
            pulse_link          = { 0xC466, 0x0100, default='none', ignore=true },
            pulse_time          = { 0xC467, 0x0100, default=0,      ms=true },
            pulse_name          = { 0xC468, 0x0100, default='' },
            pulse_prompt        = { 0xC469, 0x0100, default='' },
            pulse_input         = { 0xC46A, 0x0100, default=0 },
            pulse_timer         = { 0xC46B, 0x0100, default='use' }
        }
        stageRegisters, extraStageRegisters = blockRegs(stageRegisterInfo, numStages)

--      if private.a418(true) then
--          local analogueRegisterInfo = {
--              analog_slow_fill_percent    = { 0xA80E, 0x0010 },
--              analog_medium_fill_percent  = { 0xA80F, 0x0010 },
--              analog_fast_fill_percent    = { 0xA810, 0x0010 }
--          }
--          local _, analogueRegisters = blockRegs(analogueRegisterInfo, _M.getAnalogModuleMaximum())
--          private.addRegisters(analogueRegisters)
--      end

        private.addRegisters{
            batch_start_ilock   = 0xC021,
            batch_zero_ilock    = 0xC029,
            batch_ilock         = 0xC031
        }
    end

-------------------------------------------------------------------------------
-- Applies default values to the stage specified.
-- The defaults come from the material if a fill stage, from the defaults recipe
-- and finally a zero value.
-- @param stage Stage to change
-- @return The modified stage
-- @local
    local function applyDefaultsToStage(stage)
        local material = {}
        local type, tlen = stage.type, stage.type:len()

        if type == 'fill' and stage.fill_material then
            material = _M.getMaterial(stage.fill_material) or material
        end

        for setting, _ in pairs(stageRegisters) do
            if setting:sub(1, tlen) == type then
                stage[setting] = stage[setting] or material[setting] or recipes[setting] or
                                    stageRegisterInfo[setting].default
            end
        end
        return stage
    end

-- Join table t2 into table t1. Priority will be given to t2.
local function recursiveTableJoin(t1, t2)
  for k,v in pairs(t2) do
    if type(t1[k]) == 'table' and type(v) == 'table' then
      t1[k] = recursiveTableJoin(t1[k], v)
    else
      t1[k] = v
    end
  end
  return t1
end

-------------------------------------------------------------------------------
-- Load the material and stage data into memory.
-- This is done automatically on start up and you should only need to call this
-- function when the files have been modified (e.g. via a load from USB).
-- @function loadBatchingDetails
-- @param recipeFile Recipe file to load data from. This will be updated with 
-- the material data (and cause reordering) if a materialLog is not specified.
-- @param materialLog File to store material data in. This will be re-loaded 
-- into the application if specified, but priority will be given to fields in 
-- the recipeFile.
-- @usage
-- device.loadBatchingDetails()  -- reload the batching databases
    private.exposeFunction('loadBatchingDetails', batching, function(recipeFile, materialLog)
      materials, recipes = {}, {}
      local materialsStatic = {}
      
      -- Maintain backwards compatibility by preserving previous operation
      -- if the materials file isn't specified.
      if materialLog == nil then
        -- Load the materials and recipes tables from file
        pcall(function()
            materials, recipes = loadfile(recipeFile)()
        end)
      
        os.execute("cp '" .. recipeFile .. "' '" .. recipeFile .. ".old'")
  
        --dbg.info('recipes', recipes)
        --dbg.info('materials', materials)
        _M.saveBatchingChanges = function()
            local savname = recipeFile .. '.new'
            local savf, err = io.open(savname, 'w')
            if err == nil then
                utils.saveTableToFile(savf, materials, recipes)
                savf:close()
                os.rename(savname, recipeFile)
                utils.sync(true)
            end
            return err
        end
      -- New function with materialsLog file.
      else
      
        -- Load the data materials file
        pcall(function()
          materials = loadfile(materialLog)()
        end)
        
        pcall(function() 
          materialsStatic, recipes = loadfile(recipeFile)()
        end)
        
        -- Join the table 
        recursiveTableJoin(materials, materialsStatic)
        
        -- Save the batching changes
        _M.saveBatchingChanges = function()
          local savf, err = io.open(materialLog, 'w')
          utils.saveTableToFile(savf, materials)
          savf:close()
          utils.sync(true)
          return nil
        end
        
     end
  end)

-------------------------------------------------------------------------------
-- Save the batching information back to the bacthing state files
-- @treturn string Error string on error, nil otherwise
-- @usage
-- device.saveBatchingChanges()
    private.exposeFunction('saveBatchingChanges', batching, function()
        return 'No batching details loaded'
    end)

-------------------------------------------------------------------------------
-- Function that is called after all the stages in a batch are finished
-- @local
    local function finishedBatch()
        _M.saveBatchingChanges()
        _M.lcdControl 'lua'
    end

-- -----------------------------------------------------------------------------
-- Save the current batching details to a Lua script file
-- @function saveBatchingDetails
-- @param fname Name of the file to save to
-- @usage
-- device.saveBatchingDetails 'myBatches.lua'
--    private.exposeFunction('saveBatchingDetails', batching, function(fname)
--        local f = io.open(fname, 'w')
--        if f then
--            f:write '-- Generated batching details file\n'
--            utils.saveTableToFile(f, materials, recipes)
--            f:close()
--        end
--    end)

-------------------------------------------------------------------------------
-- Return a material record
-- @function getMaterial
-- @string m Material name
-- @treturn tab Record for the given material or nil on error
-- @treturn string Error message or nil for no error
-- @usage
-- local sand = device.getMaterial('sand')
    private.exposeFunction('getMaterial', batching, function(m)
        local r = materials[canonical(m)]
        if r == nil then
            return nil, 'material does not exist'
        end
        return r
    end)

-------------------------------------------------------------------------------
-- Set the current material in the indicator
-- @function setMaterialRegisters
-- @string m Material name to set to
-- @treturn string nil if success, error message if failure
-- @usage
-- device.setCurrentMaterial 'sand'
-- @local
    local function setMaterialRegisters(m)
        local rec, err = _M.getMaterial(m)
        if err == nil then
            for name, reg in pairs(materialRegs) do
                local v = rec[name]
                if v == nil or v == '' then v = 0 end
                private.writeRegAsync(reg, v)
            end
        end
    end

-------------------------------------------------------------------------------
-- Load the current material accumulations back from the device
-- @tab s Stage to load back data for
-- @local
    local function loadMaterialAccumulations(s)
        if s.type == 'fill' and s.fill_material then
            local rec, err = _M.getMaterial(s.fill_material)
            if err == nil then
                for name, reg in pairs(materialRegs) do
                    if materialRegisterInfo[name].accumulator then  -- Modify this to use print tokens
                        rec[name] = _M.getRegister(reg)
                    end
                end
            end
        end
    end

-------------------------------------------------------------------------------
-- Set the current stage in the indicator
-- @function setStageRegisters
-- @tab S Stage record to set to
-- @usage
-- device.setStageRegisters { type='', fill_slow=1 }
-- @local
    local function setStageRegisters(s)
        local type = s.type or 'none'
        local tlen = type:len()

        if type == 'fill' and s.fill_material then
            setMaterialRegisters(s.fill_material)
        end

        private.writeReg(REG_BATCH_STAGE_NUMBER, 0)
        private.writeReg(stageRegisters.type, naming.convertNameToValue(type, stageTypes, 0))

        for name, reg in pairs(stageRegisters) do
            if name:sub(1, tlen) == type and not stageRegisterInfo[name].ignore then
                local v = s[name]
                if v and v ~= '' then
                    if name == 'fill_material' then
                        v = 0
                    end
                    local map = naming.convertNameToValue(name, enumMaps)
                    if map ~= nil then
                        v = naming.convertNameToValue(v, map, 0)
                    end
                    if stageRegisterInfo[name].ms then
                        v = math.floor(v * 1000 + 0.5)
                    end
                    private.writeRegAsync(reg, v)
                end
            end
        end

        stageDevice = s.device or _M
    end

-------------------------------------------------------------------------------
-- Return a table that contains the stages in a specified recipe.
-- @function getRecipe
-- @string r Names of recipe
-- @treturn tab Recipe table or nil on error
-- @treturn string Error indicator or nil for no error
-- @usage
-- local cement = device.getRecipe 'cement'
    private.exposeFunction('getRecipe', batching, function(r)
        local rec = recipes[canonical(r)]
        if rec == nil then
            return nil, 'recipe does not exist'
        end
        return rec
    end)

-------------------------------------------------------------------------------
-- Return a table that contains the stages in a user selected recipe.
-- @function selectRecipe
-- @string prompt User prompt
-- @string[opt] default Default selection, nil for none
-- @treturn tab Recipe table or nil on error
-- @treturn string Error indicator or nil for no error
-- @usage
-- local cement = device.selectRecipe('BATCH?', 'cement')
    private.exposeFunction('selectRecipe', batching, function(prompt, default)
        local names = {}
        for _, v in pairs(recipes) do
            table.insert(names, v.recipe)
        end
        table.sort(names)

        local q = _M.selectOption(prompt or 'RECIPE', names, default)
        if q ~= nil then
            return _M.getRecipe(q)
        end
        return nil, 'cancelled'
    end)

-------------------------------------------------------------------------------
-- Run a stage.  Wait until it begins before returning.
-- @function runStage
-- @tparam tab stage Stage record to run
-- @usage
-- local function stageState(stage)
--     device.runStage(stage)
-- end
--
-- local f, err = device.recipeFSM { name, start=stageStart }
-- f.trans { 'start', 'begin' }
-- f.trans { 'finish', 'start' }
-- app.setMainLoop(f.run)
    private.exposeFunction('runStage', batching, function(stage)
        setStageRegisters(stage)
        _M.reinitialise 'io'
        _M.runBatch()
    end)

-------------------------------------------------------------------------------
-- Terminate the current batch
-- @function abortBatch
-- @usage
-- device.abortBatch()
    private.exposeFunction('abortBatch', batching, function()
        private.exRegAsync(REG_BATCH_ABORT, 0)
    end)

-------------------------------------------------------------------------------
-- Pause the current batch
-- @function pauseBatch
-- @usage
-- device.pauseBatch()
    private.exposeFunction('pauseBatch', batching, function()
        private.exRegAsync(REG_BATCH_PAUSE, 0)
    end)

-------------------------------------------------------------------------------
-- Continue the current batch
-- @function runBatch
-- @usage
-- device.runBatch()
    private.exposeFunction('runBatch', batching, function()
        private.exRegAsync(REG_BATCH_START, 0)
    end)

-------------------------------------------------------------------------------
-- Return the start delay associated with the specified stage or 0 if not defined
-- @param stage Stage record to query
-- @treturn number stage delay
-- @local
    local function stageDelay(stage)
        local start = stage[(stage.type or '')..'_delay_start'] or 0
        local finish = stage[(stage.type or '')..'_delay_end'] or 0
        return start + finish
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
-- Optionally, you can specify a <i>done</i> function that is passed a stage table after
-- the stage has finished.  By default, this does nothing.
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
                d.runStage(stage)
            end
        end)
        local deviceFinished = deepcopy(args.finished or function(stage)
            local d = deviceFinder(stage.device)
            return d.allStatusSet('idle')
        end)
        local deviceDone = deepcopy(args.done or function() end)
        local minimumTime = deepcopy(args.minimumTime or function() return 0 end)

        -- Extract the stages from the recipe in a useable manner
        if #recipe < 1 then return nil, 'no stages' end

        local stageCanFinish, stageTimer
        local function stageReset(finish)
            private.setStatusMainCallback('run', nil)
            timers.removeTimer(stageTimer)
            stageCanFinish = finish
            stageTimer = nil
        end

        local stages = {}
        for _, r in ipairs(recipe) do
            table.insert(stages, applyDefaultsToStage(deepcopy(r)))
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
        local fsm = _M.stateMachine { rname, trace=true }
                        .state { 'start' }
                        .state { 'begin' }
                        .state { 'finish', enter=finishedBatch }
        for bi = 1, #blocks-1 do
            local b1, b2 = blocks[bi], blocks[bi+1]
            local function startStage()
                for i = b1.idx, b2.idx-1 do
                    deviceStart(stages[i])
                end

                stageReset(false)
                private.setStatusMainCallback('run', function(s, v)
                    if v then stageReset(true) end
                end)
                stageTimer = timers.addTimer(0, 5, stageReset, true)
            end
            local function leaveStage()
                stageReset(true)
                for i = b1.idx, b2.idx-1 do
                    loadMaterialAccumulations(stages[i])
                    deviceDone(stages[i])
                end
            end
            fsm.state { b1.name, enter=startStage, leave=leaveStage }
        end

        -- Add transitions to the FSM
        fsm.trans { 'begin', blocks[1].name, activate=function()
            _M.lcdControl 'default'
            private.exReg(REG_REC_NAME_EX, rname)
        end}

        for bi = 1, #blocks-1 do
            local b1, b2 = blocks[bi], blocks[bi+1]
            local mt = 0
            for i = b1.idx, b2.idx-1 do
                mt = math.max(mt, minimumTime(stages[i]), stageDelay(stages[i]))
            end

            local function testStage()
                if not stageCanFinish then return false end
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
--@table MaterialFields
-- @field name Material name, this is the key field to specify a material by
-- @field flight weight after switching off slow fill
-- @field medium point at which turn off medium (weight before target)
-- @field fast  point at which turn off fast (weight before target)
-- @field total total weight filled
-- @field num number of batches
-- @field error total error from target in weight units over all batches
-- @field error_pc percentage error from target
-- @field error_average average error in weight units

--- Batching recipe definition fields
--
-- These are the fields in the recipes.csv file and they link to individual
-- CSV files for each different recipe.
--@table RecipeFields
-- @field recipe is the name of the recipe
-- @field datafile is the name of the CSV file containing the actual recipe stages.

--- Stages fields
--
-- These define a stage.  The individual recipe CSV files should
-- contain some, but by no means all, of these fields for each stage.
-- The CSV file for each recipe is defined in the RecipeFields CSV
-- file.
--
-- A stage which does not specify a field, leaves that field at its
-- default setting.
--
-- You can add custom fields here and they will be preserved but not acted
-- on by the batch subsystem.
--@table BatchingFields
-- @field name of the stage.
-- @field type for the stage (mandatory).  Can be <i>fill</i>, <i>dump</i> or <i>pulse</i>.
-- @field device the indicator to execute this stage on (default: this indicator)
-- @field order this defines the sequence the stages are executed in, smallest is
-- first.  This field can be a real value and fractional parts do matter.  Moreover,
-- multiple stages can have the same order value and they will execute simultaneously.
-- However, a single indicator cannot run more than one stage at a time.
-- @field fill_slow IO output for slow fill
-- @field fill_medium IO output for medium fill
-- @field fill_fast IO output for fast fill
-- @field fill_ilock IO input low means stop, high is run
-- @field fill_output IO output on during in fill stage
-- @field fill_feeder enable parallel filling (multiple or single)
-- @field fill_material material number
-- @field fill_start_action function at start (none, tare or gross)
-- @field fill_correction turn on jogging to get closer to target (flight, jog, auto\_flight or auto\_jog)
-- @field fill_jog_on_time time on during jog
-- @field fill_jog_off_time time output off for
-- @field fill_jog_set number of times to jog before looking at weight
-- @field fill_delay_start delay before start
-- @field fill_delay_check delay before checking weight -- to ignore spike at start
-- @field fill_delay_end after finish, pause for this long
-- @field fill_max_set maximum number of jogs
-- @field fill_input IO input, ends fill stage (for manual fills)
-- @field fill_direction weight increase or decrease (in or out)
-- @field fill_input_wait always wait for fill input high to exit
-- @field fill_tol_lo range band low value for being in tolerance
-- @field fill_tol_high range band high value for being in tolerance
-- @field fill_target weight to aim for
-- @field dump_dump IO to dump
-- @field dump_output IO output, on while stage active
-- @field dump_enable IO input -- okay to dump
-- @field dump_ilock IO low means stop, high is run
-- @field dump_type by weight or by time option (weight or time)
-- @field dump_correction turn on jogging to get closer to target (none or jog)
-- @field dump_delay_start delay before start
-- @field dump_delay_check delay before checking weight -- ignore spike at start
-- @field dump_delay_end after finish, pause for this long
-- @field dump_jog_on_time time on during jog
-- @field dump_jog_off_time time output off for
-- @field dump_jog_set number of times to jog before looking at weight
-- @field dump_target target weight at end of dump -- close enough to zero
-- @field dump_pulse_time time to dump for if set to time for time
-- @field dump_on_tol commnand to execute on tolerance
-- @field dump_off_tol commnand to execute for out of not tolerance
-- @field pulse_output IO to pulse, on while stage active
-- @field pulse_pulse IO to pulse
-- @field pulse_delay_start delay before start
-- @field pulse_delay_end after finish, pause for this long
-- @field pulse_start_action function at start (tare, switch gross, none)...
-- @field pulse_link only do if other stage ran / will run, not currently implemented
-- (none, prev or next).
-- @field pulse_time time to pulse for
-- @field pulse_name name of stage
-- @field pulse_prompt what is shown on display during stage
-- @field pulse_input IO input to end pulse stage
-- @field pulse_timer set to <i>use</i> or <i>ignore</i>.
-- @see RecipeFields

-- @field product_time total time spent filling per product
-- @field product_time_average average time spent filling per product
-- @field product_error total error per product
-- @field product_error_pc percentage error per product
-- @field product_error_average average error per product

end)
end
