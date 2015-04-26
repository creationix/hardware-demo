local jit = require('jit')
jit.off()
local G = require('gamepad')

local tcp = require('coro-tcp')
local uv = require('uv')

local bots = {
  {"192.168.254.15", 48879},
}

local function makeBot(host, port)
  local ox, oy, read, write
  local bot = {
    buzz = 0,
    host = host,
    x = 0,
    y = 0,
  }

  coroutine.wrap(function ()
    print("Connecting", host, port)
    read, write = assert(tcp.connect(host, port))
    print("Connected!" )
    local line = "\0\14\1\0\15\1\0\16\1\0\17\1"
              .. "\2\14\0\2\15\0\2\16\0\2\17\0"
              .. "\0\7\1\1\7\0"

    p(line)
    write(line)
  end)()

  function bot.tick()
    if not write then return end
    if bot.x ~= ox or bot.y ~= oy then
      ox, oy = bot.x, bot.y
      local left, right = bot.y / 128 + bot.x / 128, bot.y / 128 - bot.x / 128
      -- left, right = 0, 0
      local l1, l2, r1, r2
      if left < -20 then
        l1, l2 = 0, math.min(math.floor(-left), 255)
      elseif left > 20 then
        l1, l2 = math.min(math.floor(left), 255), 0
      else
        l1, l2 = 0, 0
      end
      if right < -20 then
        r1, r2 = math.min(math.floor(-right), 255), 0
      elseif right > 20 then
        r1, r2 = 0, math.min(math.floor(right), 255)
      else
        r1, r2 = 0, 0
      end
      local line = "\2\14" .. string.char(l1)
                .. "\2\15" .. string.char(l2)
                .. "\2\16" .. string.char(r1)
                .. "\2\17" .. string.char(r2)
      p(line)
      write(line)
    end

    if bot.color ~= bot.ocolor then
      bot.ocolor = bot.color
      local line
      if bot.color then
        line = "\7" .. bot.color
      else
        line = "\7\0\0\0"
      end
      p(line)
      write(line)
    end

    if bot.buzz ~= bot.obuzz then
      bot.obuzz = bot.buzz
      local line
      line = "\1\7" .. string.char(bot.buzz > 0 and 1 or 0)
      p(line)
      write(line)
    end

  end



  return bot
end

local players = {}
local numPlayers = 0

local function getBot(struct)
  struct = tostring(struct)
  local bot = players[struct]
  if not bot then
    numPlayers = numPlayers + 1
    local host, port = unpack(bots[numPlayers])
    if not host then
      error("Too many gamepads")
    end
    bot = makeBot(host, port)
    players[struct] = bot
  end
  return bot
end

G.Gamepad_init()
G.Gamepad_axisMoveFunc(function (struct, axis, value)
  local bot = getBot(struct)
  if axis == 2 then -- x axis
    bot.x = -value * 256 * 128
  elseif axis == 1 then -- y axis
    bot.y = value * 256 * 128
  end
end, nil)
G.Gamepad_buttonDownFunc(function (struct, num)
  local bot = getBot(struct)
  bot.color = (num == 0 and "\0\0\255")
           or (num == 1 and "\0\255\0")
           or (num == 2 and "\255\0\0")
           or (num == 3 and "\200\180\0")
  if num == 10 or num == 11 then
    bot.buzz = bot.buzz + 1
  end
end, nil)

G.Gamepad_buttonUpFunc(function (struct, num)
  local bot = getBot(struct)
  if num == 10 or num == 11 then
    bot.buzz = bot.buzz - 1
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
