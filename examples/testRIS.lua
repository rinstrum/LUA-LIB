-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local ris = require "rinLibrary.rinRIS"

ris.load("settings.RIS" )