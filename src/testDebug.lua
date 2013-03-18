dbg = require "rinLibrary.rinDebug"

dbg.printVar("Hello\n")
dbg.printVar("Test\r\n")
dbg.printVar("\01Hello\04")
dbg.printVar("\129Hello\245")

t = {}
t['test'] = 1
t[1] = 2
t.fred = 'friend'

dbg.printVar(t)

