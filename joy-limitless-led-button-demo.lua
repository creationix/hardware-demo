local makeJoy = require('joy')
local pig = require('pig')
local uv = require('uv')

local read, close, req, watch, cleanup, wait

local udp = uv.new_udp()
local bridgeHost = "192.168.1.110"
local bridgePort = 8899

local colors = {
  0x15, -- blue
  0xb0, -- red
  0xd0, -- red + blue
  0x60, -- green
  0x40, -- green + blue
  0x90, -- green + red
  0xe0, -- green + red + blue
  0x80, -- yellow
  0x50, -- yellow + blue
  0xa0, -- yellow + red
  0xc0, -- yellow + red + blue
  0x70, -- yellow + green
  0x30, -- yellow + green + blue
  0x90, -- yellow + green + red
  0xf0, -- yellow + green + red + blue
}

local function joyLoop()
  local buttons = {}
  for struct in read do
    local event = {
      struct = struct,
      time = struct.time,
      number = struct.number,
      value = struct.value
    }
    if bit.band(struct.type, 0x80) > 0 then event.init = true end
    if bit.band(struct.type, 0x01) > 0 then event.type = "button" end
    if bit.band(struct.type, 0x02) > 0 then event.type = "axis" end

    p(event)
    if event.type == "button" then
      buttons[event.number] = event.value == 1 or nil
      local target = event.number == 0 and 6 
        or event.number == 1 and 13
        or event.number == 2 and 19
        or event.number == 3 and 26 or nil
      if target then
        req("w " .. target .. " " .. event.value)
        local code = bit.bor(
          buttons[0] and 4 or 0,
          buttons[1] and 2 or 0,
          buttons[2] and 1 or 0,
          buttons[3] and 8 or 0
        )
        if code > 0 then
          udp:send("\x42\x00\x55", bridgeHost, bridgePort)
          local color = colors[code]
          udp:send("\x40" .. string.char(color) .. "\x55", bridgeHost, bridgePort)
        else
          udp:send("\x41\x00\x55", bridgeHost, bridgePort)
        end
      end
    end

  end
  close()
end

local function delay(ms)
  local thread = coroutine.running()
  local timer = uv.new_timer()
  timer:start(ms, 0, function ()
    timer:close()
    coroutine.resume(thread)
  end)
  coroutine.yield()
end



local function buttonLoop()
  for struct in wait do
    local buttons = {
      bit.band(bit.rshift(struct.level, 4), 1) == 1,
      bit.band(bit.rshift(struct.level, 5), 1) == 1,
      bit.band(bit.rshift(struct.level, 17), 1) == 1,
      bit.band(bit.rshift(struct.level, 27), 1) == 1,
    }
    local code = bit.bor(
      buttons[1] and 1 or 0,
      buttons[2] and 2 or 0,
      buttons[3] and 4 or 0,
      buttons[4] and 8 or 0
    )
    if code > 0 then
      udp:send("\x42\x00\x55", bridgeHost, bridgePort)
      local color = colors[code]
      udp:send("\x40" .. string.char(color) .. "\x55", bridgeHost, bridgePort)
    else
      udp:send("\x41\x00\x55", bridgeHost, bridgePort)
    end
    local event = {
      struct = struct,
      seqno = struct.seqno,
      flags = struct.flags,
      tick = struct.tick,
      buttons = buttons
    }
    p(event)
  end
end

local function main()
  read, close = makeJoy(0)
  req, watch, cleanup = pig()
 
  print "Setting pins 6, 13, 19, and 26 as output"
  req "m 6 w m 13 w m 19 w m 26 w"
 
  print "Setting pins 4, 5, 17, and 27 as input"
  req "m 4 r m 5 r m 17 r m 27 r"
      
  print "Enabling internal pull-down resistors on inputs"
  req "pud 4 d pud 5 d pud 17 d pud 27 d"

  print "Monitoring input pins for changes"
  wait = watch(4, 5, 17, 27)

  coroutine.wrap(joyLoop)()
  coroutine.wrap(buttonLoop)()

end

assert(xpcall(function ()
  coroutine.wrap(main)()
  uv.run()
end, debug.traceback))


