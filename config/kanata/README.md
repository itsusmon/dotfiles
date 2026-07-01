# kanata

## What it is

kanata is a cross-platform keyboard remapper.
It sits between the physical keyboard and the OS, intercepting key events and emitting remapped ones based on `kanata.kbd`.

## Why I use it

macOS has no built-in way to make a key do one thing on tap and another on hold, nor a real Hyper key.
kanata turns the otherwise-wasted Caps Lock into two keys: Escape on tap, Hyper on hold.
Hyper then drives app launchers, so common apps open from the home row without reaching for the mouse or Spotlight.

## What's here

- `kanata.kbd` - the only config file.
  Caps Lock: tap -> Escape, hold -> Hyper (Ctrl+Alt+Shift+Cmd).
  While Hyper is held, keys in the `launch` layer run app-launch commands; every other key emits a raw Hyper+`<key>` chord.

## How it runs on macOS

kanata itself is not installed by this repo; only the config is tracked here.
The runtime pieces live outside the repo:

- Binary: `/usr/local/bin/kanata` (the `cmd_allowed` build, required for the `cmd` app-launch action).
- Driver: Karabiner-DriverKit-VirtualHIDDevice v6.2.0 (kanata's virtual keyboard on macOS).
- Two LaunchDaemons in `/Library/LaunchDaemons/` start it at boot:
  - `com.local.karabiner-vhid-daemon` - the Karabiner virtual-HID daemon.
  - `com.local.kanata` - kanata itself, pointed at `~/.config/kanata/kanata.kbd` (this file, symlinked).
- Requires Input Monitoring permission for `/usr/local/bin/kanata` (System Settings -> Privacy & Security).

## Working with it

- Edit `kanata.kbd`, then reload: `sudo launchctl kickstart -k system/com.local.kanata`.
- Validate before reloading: `kanata --cfg ~/.config/kanata/kanata.kbd --check`.
- Logs: `/var/log/kanata.log` and `/var/log/kanata.err.log`.
- Emergency quit: `lctl + spc + esc` (refers to physical keys, before remapping).
- Adding an app launcher: follow the step-by-step comment block at the top of `kanata.kbd`.
