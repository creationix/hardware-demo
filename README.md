# hardware-demo

This is meant to run on a raspberry pi that has pigpio and luvit installed.

This assumes 4 tactile buttons are wired to GPIO pins 4, 5, 17, and 27.  I'm using internal pulldowns so wire the buttons between the input pins and 3v power.

This also assumes 4 LEDs are wired to GPIO pins 6, 13, 19, and 26. Make sure to use appropriate resistors for the LEDs and wire then between the outputs and ground.

Make sure to start the pigpido daemon by running:

```sh
sudo pigpiod
```

Then you can run the sample:

```sh
cd hardware-demo
luvit demo.lua
```

Press the buttons and see the lights light up.  After 100 state changes it will exit gracefully.

This uses pigpio's notification system with a little basic logic to debounce a little (combining events that come in at once).  The libuv event loop is running optimally and gets push events from pigpio via a named fifo pipe.

