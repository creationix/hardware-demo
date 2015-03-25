local uv = require('uv')
local pig = require('pig')

local function main()

  local req, watch, cleanup = pig()

  local inputs = {4,5,17,27}
  local outputs = {6, 13, 19, 26}
  
  print "Setting pins 4, 5, 17, and 27 as input"
  req("m " .. table.concat(inputs, " r m ") .. " r")
  
  print "Enabling internal pull-down resistors on inputs"
  req("pud " .. table.concat(inputs, " d pud ") .. " d")
  
  print "Setting pins 6, 13, 19, and 26 as output"
  req("m " .. table.concat(outputs, " w m ") .. " w")
  
  print "Reseting outputs to low"
  req("w " .. table.concat(outputs, " 0 w ") .. " 0") 
 
  uv.new_signal():start("sigint", function ()
    coroutine.wrap(function ()
      print "Reseting outputs to low"
      req("w " .. table.concat(outputs, " 0 w ") .. " 0") 
      print "Cleaning pig library resources"
      cleanup()
      print "Closing all libuv handles"
      uv.walk(function (handle)
        if not handle:is_closing() then
          handle:close()
        end
      end)
      uv.stop()
    end)()
    
  end)

  print "Waiting for changes to inputs and writing state to outputs"
  print "Press Control+C to exit"
  local old = 0
  local read = watch(unpack(inputs))
  while true do
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

end

assert(xpcall(function ()
  coroutine.wrap(main)()
  uv.run()
end, debug.traceback))


