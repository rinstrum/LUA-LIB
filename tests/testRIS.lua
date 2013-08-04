-- Include the src directory
package.path = package.path .. ";../src/?.lua"

local ris = require "rinLibrary.rinRIS"

ris.load("tests/settings.RIS", "172.17.1.95", 2222)