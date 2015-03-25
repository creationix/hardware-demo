local uv = require('uv')
local ffi = require('ffi')

ffi.cdef[[
// https://www.kernel.org/doc/Documentation/input/joystick-api.txt
struct __attribute__ ((__packed__)) js_event {
  uint32_t time;  /* event timestamp in milliseconds */
  int16_t value;  /* value */
  uint8_t type;   /* event type */
  uint8_t number; /* axis/button number */
};
]]

return function (id)
  local fd = uv.fs_open("/dev/input/js" .. id, "r", 420)
  local function close()
    uv.fs_close(fd)
  end
  local waiting
  local function onRead(err, data)
    assert(not err, err)
    assert(waiting, "response without request")
    local event
    if data then
      event = ffi.cast("struct js_event*", data)
    end
    local thread
    thread, waiting = waiting, nil
    assert(coroutine.resume(thread, event))
  end
  local function read()
    assert(not waiting, "already reading")
    waiting = coroutine.running()
    assert(uv.fs_read(fd, 8, -1, onRead))
    return assert(coroutine.yield())
  end

  return read, close
end

