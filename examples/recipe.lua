#!/usr/local/bin/lua
-------------------------------------------------------------------------------
-- recipe
--
-- Sample recipe application showing the manipulation of registers and other
-- values and the saving and restoring of these from a database.
-------------------------------------------------------------------------------

-- Require the rinApp module
local rinApp = require "rinApp"
local system = require 'rinSystem'
local dbg = require "rinLibrary.rinDebug"
local csv = require 'rinLibrary.rinCSV'

-- Add control of an device at the given IP and port
local device = rinApp.addK400('k410')


local recipeMenu, managementMenu

recipeMenu = device.createMenu { 'RECIPES' }
        .menu { 'TIMERS' }
            .string   { 'recipe', '', prompt='NAME' }
            .register { 'fill_delay', 'stage_pulse_time1', prompt='FIL.DLY' }
            .register { 'chk_delay', 'stage_fill_jog_set2', prompt='DMP.TIM' }
            .integer  { 'clamp_release', 0, prompt='BAG.DLY' }
            .fin()


local _, menuColumns = recipeMenu.getValues(true)
local recipeDatabase = csv.loadCSV{
    fname = 'recipes.csv',
    labels = menuColumns
}


local function commit()
    csv.saveCSV(recipeDatabase)
end

local function populateRecipes()
    local r = csv.getColCSV(recipeDatabase, 'recipe')
    managementMenu.setList('RECIPE', r or {})
end

local function pickByName()
    local r = managementMenu.getValue'RECIPE'
    local rec = csv.getRecordCSV(recipeDatabase, r, 'RECIPE')
    if rec ~= nil then
        managementMenu.setValues(rec)
    end
end

local function deleteRecipe()
    local recipe = managementMenu.getValue'RECIPE'
    local n = csv.getLineCSV(recipeDatabase, recipe, 'RECIPE')
    if n ~= nil then
        csv.remLineCSV(recipeDatabase, n)
        commit()
    end
end

local function addRecipe()
    local row = paramsToRow()
    local ids = csv.getColCSV(recipeDatabase, 'RECIPE')

    -- The search for a missing slot can be done a lot more efficiently
    for id = 1, csv.numRowsCSV(recipeDatabase) + 1 do
        local new, again = 'R'..id, false
        for i = 1, #ids do
            if ids[i] == new then
                again = true
                break
            end
        end
        if not again then
            row[csv.labelCol(recipeDatabase, 'RECIPE')] = new
            csv.addLineCSV(recipeDatabase, row)
            commit()
            return
        end
    end
end

managementMenu = device.createMenu{ 'RECIPES' }
            .list { 'RECIPE', {}, onShow=populateRecipes, onHide=pickByName }
            .item { 'ADD', run=addRecipe }
            .item { 'DELETE', run=deleteRecipe }
            .item { 'QUIT', exit=true }


device.setKeyCallback('f1', recipeMenu.run, 'short')
device.setKeyCallback('f2', managementMenu.run, 'short')


device.write('topleft', 'RECIPE DATA BASE')
device.write('bottomleft', 'PRESS F1 FOR EDIT OR F2 TO PICK')

rinApp.run()
