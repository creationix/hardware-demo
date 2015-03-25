local uv = require('uv')
local pig = require('pig')

local function main()

  local req, watch, cleanup = pig()

  local inputs = {4,5,17,27}
  local outputs = {6, 13, 19, 26}
  -- Set pins 4, 5, 17, and 27 as input (buttons)
  req("m " .. table.concat(inputs, " r m ") .. " r")
  -- Enable internal pull-down resistors on buttons
  req("pud " .. table.concat(inputs, " d pud ") .. " d")
  -- Set mode for 6, 13, 19, and 26 for output (LEDs)
  req("m " .. table.concat(outputs, " w m ") .. " w")
  -- Turn all LEDs off
  req("w " .. table.concat(outputs, " 0 w ") .. " 0") 
  
  local old = 0
  local read = watch(unpack(inputs))
  for n = 1, 100 do
    local event = read()
    for i = 1, #inputs do
      local pin = inputs[i]
      local level = bit.band(bit.rshift(event.level, pin), 1) == 1
      local oldLevel = bit.band(bit.rshift(old, pin), 1) == 1
      if level ~= oldLevel then
        p(pin, level)
        req("w " .. outputs[i] .. " " .. (level and 1 or 0))
      end
    end
    old = event.level
  end
  cleanup()
end

assert(xpcall(function ()
  coroutine.wrap(main)()
  uv.run()
end, debug.traceback))


