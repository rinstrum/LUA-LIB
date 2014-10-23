-------------------------------------------------------------------------------
-- usbMenu
--
-- Application to demonstrate how to use the basic features of the USB
-- storage subsystem with a custom menu interface.
-------------------------------------------------------------------------------
local dbg = require 'rinLibrary.rinDebug'
local rinApp = require "rinApp"                 --  load in the application framework
local usb = require "rinLibrary.rinUSB"
local csv = require 'rinLibrary.rinCSV'

--=============================================================================
-- Connect to the instruments you want to control
-- Define any Application variables you wish to use
--=============================================================================
local device = rinApp.addK400("K401")           --  make a connection to the instrument

local productFile, materialFile
local usbPresent = false
local productDB, materialDB

--=============================================================================
-- Product database.
-- A function to load the database from storage and another to update it
-- from the USB device.
local function loadProducts()
    productDB = csv.loadCSV {
        fname = 'products.csv'
    }
end
loadProducts()

local function updateProduct()
    usb.copyFile(productFile, productDB.fname)
    loadProducts()
    device.write('topLeft', 'LOADED')
    device.write('bottomLeft', csv.numRowsCSV(productDB) .. ' PRODCT', 'wait, align=right')
end


--=============================================================================
-- Material database.
-- A function to load the database from storage and another to update it
-- from the USB device.
local function loadMaterials()
    materialDB = csv.loadCSV {
        fname = 'materials.csv'
    }
end
loadMaterials()

local function updateMaterial()
    usb.copyFile(materialFile, materialDB.fname)
    loadMaterials()
    device.write('topLeft', 'LOADED')
    device.write('bottomLeft', csv.numRowsCSV(materialDB) .. ' MATERL', 'wait, align=right')
end


--=============================================================================
-- This function is called when the user chooses to write to the USB device
local function myBackup(path)
    dbg.info('Saving state to the USB device at '..path)
    usb.copyFiles(".", path .. '/lua', '.lua')  -- back up .lua files
    usb.copyFiles(".", path, '.ris')            -- back up .ris files
    usb.copyFiles(".", path, '.csv')            -- back up .csv files
end


--=============================================================================
-- When a new USB device is detected, this one gets called.
-- It brings up a simple menu
local function myNew(path)
    productFile = path .. '/' .. productDB.fname
    materialFile = path .. '/' .. materialDB.fname
    usbPresent = true
    local restore = device.saveDisplay()

    device.createMenu { 'USB MENU', loop=true }
        .item { 'BACKUP', exit=true, run=device.usbBackup }
        .item { 'PRODCT', secondary='UPDATE', run=updateProduct,
                          enabled=function() return usb.fileExists(productFile) end }
        .item { 'MATERL', secondary='UPDATE', run=updateMaterial,
                          enabled=function() return usb.fileExists(materialFile) end }
        .item { 'DONE',   exit=true }
        .run()
    device.usbUnmount()
    rinApp.delayUntil(function() return not usbPresent end)
    restore()
end

--=============================================================================
-- Set up the USB storage handling subsystem but with manual prompting
device.usbActivateStorage {
    when = 'manual',
    new = function(path) rinApp.addIdleEvent(myNew, path) end,
    removed = function() usbPresent = false end,
    backup = myBackup
}

--=============================================================================
-- run the application
device.write('topLeft', 'uMENU')
device.write('topRight', '')
device.write('bottomLeft', 'WAITING FOR STORAGE DEVICE')
device.write('bottomRight', '')
rinApp.run()
--=============================================================================
