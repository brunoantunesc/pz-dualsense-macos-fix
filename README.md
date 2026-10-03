# Project Zomboid DualSense Bluetooth Fix for macOS

A workaround for a macOS / GLFW issue where a PlayStation 5 DualSense controller connected over Bluetooth is detected by Project Zomboid, but no buttons or analog sticks respond.

## Symptoms

This fix is intended for cases where:

- macOS detects the DualSense normally.
- Steam / Big Picture receives controller input normally.
- Project Zomboid shows `PS5 Controller` or `DualSense Wireless Controller`.
- Project Zomboid's **Test Controller** screen detects the controller but receives no input.
- Raw HID input from the controller still works.
- GLFW detects the controller but joystick axes and buttons remain frozen.

## What was happening

The DualSense continued sending Bluetooth HID report `0x31` correctly.

Raw HID reports were updating normally, but the macOS HID element values used by GLFW were not updating.

As a result:

```text
DualSense Bluetooth
        |
        v
Raw HID reports           OK
        |
        v
IOHID element values      FROZEN
        |
        v
GLFW joystick state       FROZEN
        |
        v
Project Zomboid           NO INPUT
```

This patch registers a raw HID report callback for the DualSense and parses Bluetooth report `0x31` directly.

The decoded controller state is fed into GLFW using:

- `_glfwInputJoystickAxis`
- `_glfwInputJoystickButton`
- `_glfwInputJoystickHat`

For the affected DualSense device, the broken normal macOS joystick polling path is skipped.

## Confirmed diagnosis

During debugging, the following was verified:

| Layer | Result |
| --- | --- |
| DualSense Bluetooth connection | Working |
| macOS HID enumeration | Working |
| Raw HID report `0x31` | Working |
| `hidapitester` | Working |
| IOHID raw report callback | Working |
| IOHID element value callbacks | Frozen |
| Stock GLFW joystick polling | Frozen |
| Homebrew GLFW joystick polling | Frozen |
| Patched GLFW using raw HID reports | Working |
| Project Zomboid with patched GLFW | Working |

The issue was reproduced outside Project Zomboid with a minimal GLFW joystick test.

## Tested environment

Confirmed working with:

- Apple Silicon Mac
- DualSense connected over Bluetooth
- Project Zomboid for macOS
- LWJGL / GLFW bundled with Project Zomboid

Currently, the installer targets **macOS arm64 / Apple Silicon**.

## Requirements

You need:

- Git
- CMake
- Clang
- Python 3

If CMake is missing and you use Homebrew:

```bash
brew install cmake
```

## Installation

Clone this repository:

```bash
git clone https://github.com/brunoantunesc/pz-dualsense-macos-fix.git
cd pz-dualsense-macos-fix
```

Build the patched GLFW:

```bash
./scripts/build-glfw.sh
```

Install the fix into Project Zomboid:

```bash
./scripts/install.sh
```

Then start Project Zomboid normally through Steam.

Open:

```text
Options -> Controller -> Test Controller
```

The DualSense should now respond normally.

## Uninstall

Run:

```bash
./scripts/uninstall.sh
```

The installer creates a backup of the original `projectzomboid.jar`, and the uninstall script restores it.

## Steam updates and file verification

Steam updates or **Verify integrity of game files** may restore Project Zomboid's original `projectzomboid.jar`.

If the controller stops working after an update, run:

```bash
./scripts/build-glfw.sh
./scripts/install.sh
```

again.

## Saves

This fix does **not** modify:

```text
~/Zomboid/Saves
```

It does not modify save games, worlds, characters, Workshop mods, or normal Project Zomboid configuration files.

The installer only patches the GLFW native library embedded inside Project Zomboid's `projectzomboid.jar`.

## How the fix works

Before the patch:

```text
DualSense Bluetooth
        |
        v
Bluetooth report 0x31
        |
        v
macOS IOHID element polling
        |
        X
        |
        v
GLFW sees frozen axes/buttons
        |
        v
Project Zomboid gets no controller input
```

After the patch:

```text
DualSense Bluetooth
        |
        v
Bluetooth report 0x31
        |
        v
Raw IOHID report callback
        |
        v
DualSense report parser
        |
        +---- sticks
        +---- triggers
        +---- face buttons
        +---- shoulder buttons
        +---- D-pad
        |
        v
_glfwInputJoystick*
        |
        v
Project Zomboid receives normal gamepad input
```

## GLFW base

The current patch is based on GLFW commit:

```text
92dcf4ce74f2e2554a98fea09be7c705c17daa5a
```

The patch itself is located at:

```text
patches/glfw-dualsense-bluetooth-macos.patch
```

The build script checks out this exact commit before applying the patch so that future GLFW changes do not silently break the build.

## Supported controller

The current implementation targets:

- Sony Vendor ID: `0x054c`
- DualSense Product ID: `0x0ce6`
- Bluetooth enhanced input report: `0x31`

## Current limitations

This is currently a targeted workaround, not a complete generic GLFW controller backend replacement.

Current limitations include:

- Apple Silicon only.
- DualSense only.
- Bluetooth report `0x31` only.
- Multiple simultaneous DualSense controllers have not yet been tested.
- Hot-plug / reconnect behavior needs more testing.
- Advanced DualSense functionality is not implemented.

The patch is intended to restore normal gamepad input:

- Left stick
- Right stick
- Face buttons
- D-pad
- L1 / R1
- L2 / R2
- L3 / R3
- Create
- Options
- PS / touchpad / mute state where exposed

It does not attempt to implement:

- Adaptive triggers
- Haptic feedback
- Gyroscope
- Accelerometer
- Touchpad gestures
- Speaker / microphone functionality

## Why this is not a normal Project Zomboid mod

The problem occurs inside GLFW before Project Zomboid's Lua mod system receives controller input.

A normal Workshop Lua mod cannot fix this because the controller state is already broken before Lua sees it.

This project patches the native GLFW library used by Project Zomboid instead.

## Safety and reversibility

The installer:

1. Locates Project Zomboid's `projectzomboid.jar`.
2. Creates a backup.
3. Replaces only the arm64 GLFW native entry.
4. Updates the corresponding SHA-1 metadata.
5. Clears the LWJGL temporary native cache.

The uninstall script restores the original JAR.

No save data is touched.

## Development

Build the patched GLFW:

```bash
./scripts/build-glfw.sh
```

The resulting library is written to:

```text
build/libglfw-dualsense-fix.dylib
```

Do not commit generated `.dylib`, `.jar`, backup, or build files.

## Upstream potential

The underlying issue is not specific to Project Zomboid.

It can be reproduced directly through GLFW:

- GLFW enumerates the DualSense successfully.
- Raw Bluetooth HID reports continue updating.
- GLFW joystick axis/button state remains frozen.

The Project Zomboid patch serves as a practical workaround and a reproducible test case for investigating a proper upstream GLFW/macOS fix.

## License

Repository-specific scripts and code are licensed under the MIT License.

GLFW is licensed under the zlib/libpng license. See `LICENSE-GLFW`.

Project Zomboid is property of The Indie Stone.

This repository does not distribute Project Zomboid game files.
