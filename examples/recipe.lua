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

-- Our recipe has its own menu for creation and editing.  This defined the
-- fields and registers in the recipe.
recipeMenu = device.createMenu { 'RECIPES' }
            .string   { 'recipe', '', prompt='NAME' }
            .register { 'fill_delay', 'stage_pulse_time1', prompt='FIL.DLY' }
            .register { 'chk_delay', 'stage_fill_jog_set2', prompt='DMP.TIM' }
            .integer  { 'clamp_release', 0, prompt='BAG.DLY' }


-- Load the recipe database
local _, menuColumns = recipeMenu.getValues(true)
local recipeDatabase = csv.loadCSV{
    fname = 'recipes.csv',
    labels = menuColumns
}
-- Utility function to commit changes to flash
local function commit()
    csv.saveCSV(recipeDatabase)
end
commit()

local recipeCol = csv.labelCol(recipeDatabase, 'RECIPE')
local currentRecipe = 1

-- Get the name of the nth recipe or null if the index isn't valid
local function getRecipeName(n)
    if n and n > 0 and n <= csv.numRowsCSV(recipeDatabase) then
        return recipeDatabase.data[n][recipeCol]
    end
    return ''
end

-- Populate the recipe list field in the management menu
local function populateRecipes()
    local r = csv.getColCSV(recipeDatabase, 'recipe')
    managementMenu.setList('RECIPE', r or {})
end

-- Pick a recipe from the pick list of recipe names
local function pickByName()
    local r = managementMenu.getValue'RECIPE'
    local rec = csv.getRecordCSV(recipeDatabase, r, 'RECIPE')
    if rec ~= nil then
        recipeMenu.setValues(rec)
        currentRecipe = csv.getLineCSV(recipeDatabase, r, 'RECIPE')
    end
end

-- Delete the current recipe from the database
local function deleteRecipe()
    local recipe = managementMenu.getValue'RECIPE'
    local n = csv.getLineCSV(recipeDatabase, recipe, 'RECIPE')
    if n ~= nil then
        csv.remLineCSV(recipeDatabase, n)
        commit()
        currentRecipe = n > 1 and (n-1) or 1
        managementMenu.setValue('RECIPE', getRecipeName(currentRecipe))
    end
end

-- Copy the current settings into a new recipe
local function addRecipe()
    local row = recipeMenu.getValues()

    local ids = csv.getColCSV(recipeDatabase, 'RECIPE')

    -- The search for a missing slot can be done a lot more efficiently
    for id = 1, csv.numRowsCSV(recipeDatabase) + 1 do
        local new, again = 'R'..id, false
        if ids then
            for i = 1,  #ids do
                if ids[i] == new then
                    again = true
                    break
                end
            end
        end
        if not again then
            row.recipe = new
            csv.addLineCSV(recipeDatabase, row)
            currentRecipe = csv.numRowsCSV(recipeDatabase)
            commit()
            populateRecipes()
            managementMenu.setValue('RECIPE', new)
            return
        end
    end
end

-- The recipe management menu
managementMenu = device.createMenu{ 'RECIPES' }
            .list { 'RECIPE', {}, onShow=populateRecipes, onHide=pickByName }
            .item { 'ADD', run=addRecipe }
            .item { 'DELETE', run=deleteRecipe }
            .item { 'QUIT', exit=true }

-- Provide a default recipe (the first one if any are present)
managementMenu.setValue('RECIPE', getRecipeName(currentRecipe))

-- local function edit recipe
local function editRecipe()
    if csv.numRowsCSV(recipeDatabase) == 0 then
        addRecipe()
    end
    recipeMenu.run()
    csv.replaceLineCSV(recipeDatabase, currentRecipe, recipeMenu.getValues())
    commit()
    populateRecipes()
    managementMenu.setValue('RECIPE', getRecipeName(currentRecipe))
end

-- Hook up the user interface menus to the keys
device.setKeyCallback('f1', editRecipe, 'short')
device.setKeyCallback('f2', managementMenu.run, 'short')

-- Produce some welcome text
device.write('topleft', 'RECIPE DATA BASE')
device.write('bottomleft', 'PRESS F1 FOR EDIT OR F2 TO PICK')

-- And go
rinApp.run()
