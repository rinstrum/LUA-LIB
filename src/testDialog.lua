require "rinApp"

L401.writeBotLeft("Hello")
L401.writeBotRight("There")
val = dialog.edit('VAL',5)
dialog.askOK('OK?',val)
dialog.delay(1000)
L401.buzz(val)
sel = dialog.selectOption('Select',{'small','medium','large'},'small')
L401.writeBotLeft(sel)
dialog.delay(5000)
cleanup()