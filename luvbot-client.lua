local tcp = require('coro-tcp')
local uv = require('uv')
local makeJoy = require('joy')
local bit = require('bit')

local ox, oy, x, y, read, write

local function tick()
  if x == ox and y == oy then return end
  ox, oy = x, y
  local left, right = -y / 128 - x / 128, -y / 128 + x / 128
  -- left, right = 0, 0
  local command
  if left < -20 then
    command = "p 27 " .. math.min(math.floor(-left), 255) .. " p 22 0"
  elseif left > 20 then
    command = "p 27 0 p 22 " .. math.min(math.floor(left), 255)
  else
    command = "p 27 0 p 22 0"
  end
  if right < -20 then
    command = command .. " p 24 " .. math.min(math.floor(-right), 255) .. " p 23 0"
  elseif right > 20 then
    command = command .. " p 24 0 p 23 " .. math.min(math.floor(right), 255)
  else
    command = command .. " p 24 0 p 23 0"
  end
  write(command)

end
local function main()
  read, write = assert(tcp.connect("cherry", 1337))
  p(read, write)
  write("m 27 w m 22 w m 23 2 m 24 w p 27 0 p 22 0 p 23 0 p 24 0")
  local get, close = makeJoy(0)
  print("Connected to remote")
  for struct in get do
    if bit.band(struct.type, 0x02) > 0 then -- axis event
      if struct.number == 3 then -- x axis
        x = struct.value
      elseif struct.number == 1 then -- y axi
        y = struct.value
      end
    end
  end
  close()
end

assert(xpcall(function ()
  coroutine.wrap(main)()
  uv.new_timer():start(100, 100, tick)
  uv.run()
end, debug.traceback))
