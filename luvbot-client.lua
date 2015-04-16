local jit = require('jit')
jit.off()
local G = require('gamepad')

local tcp = require('coro-tcp')
local uv = require('uv')

local bots = {
  "192.168.1.145",
  "192.168.1.105",
}

local function makeBot(host)

  local ox, oy, read, write
  local bot = {
    host = host,
    x = 0,
    y = 0,
  }

  coroutine.wrap(function ()
    read, write = assert(tcp.connect(host, 1337))
    write("m 27 w m 22 w m 23 2 m 24 w p 27 0 p 22 0 p 23 0 p 24 0")
    print("Connected to remote " .. host)
  end)()

  function bot.tick()
    if not write then return end
    if bot.x == ox and bot.y == oy then return end
    ox, oy = bot.x, bot.y
    local left, right = bot.y / 128 - bot.x / 128, bot.y / 128 + bot.x / 128
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

  return bot
end

local players = {}
local numPlayers = 0

G.Gamepad_init()
G.Gamepad_axisMoveFunc(function (struct, axis, value)
  struct = tostring(struct)
  local bot = players[struct]
  if not bot then
    numPlayers = numPlayers + 1
    local host = bots[numPlayers]
    if not host then
      error("Too many gamepads")
    end
    bot = makeBot(host)
    players[struct] = bot
  end
  if axis == 3 then -- x axis
    bot.x = -value * 256 * 128
  elseif axis == 1 then -- y axis
    bot.y = value * 256 * 128
  end
end, nil)

uv.new_timer():start(100, 100, function ()
  coroutine.wrap(function ()
    G.Gamepad_processEvents()
    for _, bot in pairs(players) do
      bot.tick()
    end
  end)()
end)
