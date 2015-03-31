local tcp = require('coro-tcp')
local uv = require('uv')
local makeJoy = require('joy')

local function main()
  local read, write = assert(tcp.connect("cherry", 1337))
  p(read, write)
  write("m 27 w m 22 w m 23 2 m 24 w p 27 0 p 22 0 p 23 0 p 24 0")
  local get, close = makeJoy(0)
  print("Connected to remote")
  for event in get do
    p(event)
    -- write(table.concat({req(chunk)}, " ") .. "\n")
  end
  close()
end

assert(xpcall(function ()
  coroutine.wrap(main)()
  uv.run()
end, debug.traceback))
