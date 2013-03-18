require "rinApp"

while true do
  key = dialog.getKey()
  if key == L401.KEY_F1 then
      dialog.zero()
  elseif key == L401.KEY_F2 then
      dialog.tare()
  elseif key == L401.KEY_F3 then
      dialog.presetTare(1000)
  elseif key == L401.KEY_POWER then
       break  
  end
end

cleanup()  
