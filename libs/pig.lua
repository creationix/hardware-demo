local uv = require('uv')
local ffi = require('ffi')

ffi.cdef[[
int open(const char *pathname, int flags);
struct __attribute__ ((__packed__)) gpioReport {
  uint16_t seqno;
  uint16_t flags;
  uint32_t tick;
  uint32_t level;
};
]]
local C = ffi.C
local O_WRONLY = uv.constants.O_WRONLY
local O_RDONLY = uv.constants.O_RDONLY

local function openPipe(path, read)
  local fd = C.open(path, read and O_RDONLY or O_WRONLY)
  assert(uv.guess_handle(fd) == 'pipe', 'problem opening pipe ' .. path)
  local handle = uv.new_pipe(false)
  assert(handle:open(fd))
  return handle
end

return function ()
  local pigpio = openPipe("/dev/pigpio", false)
  local pigout = openPipe("/dev/pigout", true)
  local waiting
  local notifiers = {}

  local function req(data)
    assert(not waiting, "request already waiting")
    waiting = coroutine.running()
    data = data .. "\n"
--    p("->", data)
    pigpio:write(data)
    return assert(coroutine.yield())
  end

  pigout:read_start(function (err, data)
    assert(not err, err)
--    p("<-", data)
    if not data then 
      if waiting then error("pigout closed") end
      return
    end
    assert("waiting", "response without request")
    local parts = {}
    for part in data:gmatch("[^\n]+") do
      parts[#parts + 1] = tonumber(part)
    end
    local thread
    thread, waiting = waiting, nil
    assert(coroutine.resume(thread, unpack(parts)))
  end)

  local function cleanup()
    for index, pipe in pairs(notifiers) do
      pipe:close()
      req("nc " .. index)
    end
    pigpio:close()
    pigout:close()
  end

  local function watch(...)
    local pins = {...}
    local bitfield = 0
    for i = 1, #pins do
      bitfield = bit.bor(bitfield, bit.lshift(1, pins[i]))
    end
    local index = req("no")
    assert(index >= 0)
    local pipe = openPipe("/dev/pigpio" .. index, true)
    notifiers[index] = pipe
    local waiting
    local extra

    pipe:read_start(function (err, data)
      assert(not err, err)
--      p("<*" .. index, data)
      if #data < 12 then return end 
      local events = ffi.cast("struct gpioReport*", data)
      local event = events + (#data / 12 - 1)
      if waiting then
        local thread
        thread, waiting = waiting, nil
        assert(coroutine.resume(thread, event))
      else
        extra = event
      end
    end)

    assert(req("nb " .. index .. " " .. bitfield) == 0)
    
    return function ()
      if extra then
        local event
        event, extra = extra, nil
        return event
      end
      assert(not waiting, "Request already in progress")
      waiting = coroutine.running()
      return assert(coroutine.yield())
    end
  end

  return req, watch, cleanup

end


