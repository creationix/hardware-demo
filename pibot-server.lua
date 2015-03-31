local pig = require('pig')
local tcp = require('coro-tcp')

tcp.createServer("0.0.0.0", 1337, function (read, write)
  local req, watch, cleanup = pig()
  write("Welcome to remote pigs\n")
  print("New client connected")
  for chunk in read do
    p(chunk)
    write(table.concat({req(chunk)}, " ") .. "\n")
  end
  print("Client disconnected")
  cleanup()
end)
print("TCP server listening at 1337")



