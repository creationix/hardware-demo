-- Tweak this to the host of ip of your robot
local luvbot = "192.168.1.105"

local jit = require('jit')
jit.off()
local G = require('gamepad')

local tcp = require('coro-tcp')
local uv = require('uv')

local ox, oy, x, y, read, write
x = 0
y = 0

G.Gamepad_init()

local function tick()
  G.Gamepad_processEvents()
  if x == ox and y == oy then return end
  ox, oy = x, y
  local left, right = y / 128 - x / 128, y / 128 + x / 128
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

local function onAxis(_, axis, value)
  if axis == 2 then -- x axis
    x = -value * 256 * 128
  elseif axis == 1 then -- y axis
    y = value * 256 * 128
  end
end

local function main()
  read, write = assert(tcp.connect(luvbot, 1337))
  p(read, write)
  write("m 27 w m 22 w m 23 2 m 24 w p 27 0 p 22 0 p 23 0 p 24 0")
  G.Gamepad_axisMoveFunc(onAxis, nil)
  print("Connected to remote")
end

assert(xpcall(function ()
  coroutine.wrap(main)()
  uv.new_timer():start(100, 100, tick)
  uv.run()
end, debug.traceback))
