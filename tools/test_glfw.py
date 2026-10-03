import ctypes
import sys
import time

if len(sys.argv) != 2:
    print("Usage: python3 tools/test_glfw.py /path/to/libglfw.dylib")
    sys.exit(1)

libpath = sys.argv[1]
glfw = ctypes.CDLL(libpath)

glfw.glfwInit.restype = ctypes.c_int
glfw.glfwTerminate.restype = None
glfw.glfwPollEvents.restype = None

glfw.glfwJoystickPresent.argtypes = [ctypes.c_int]
glfw.glfwJoystickPresent.restype = ctypes.c_int

glfw.glfwGetJoystickName.argtypes = [ctypes.c_int]
glfw.glfwGetJoystickName.restype = ctypes.c_char_p

glfw.glfwGetJoystickAxes.argtypes = [
    ctypes.c_int,
    ctypes.POINTER(ctypes.c_int),
]
glfw.glfwGetJoystickAxes.restype = ctypes.POINTER(ctypes.c_float)

glfw.glfwGetJoystickButtons.argtypes = [
    ctypes.c_int,
    ctypes.POINTER(ctypes.c_int),
]
glfw.glfwGetJoystickButtons.restype = ctypes.POINTER(ctypes.c_ubyte)

if not glfw.glfwInit():
    print("glfwInit() failed")
    sys.exit(1)

print("GLFW initialized.")
print("Searching for controllers...")

jid = None

for i in range(16):
    if glfw.glfwJoystickPresent(i):
        name = glfw.glfwGetJoystickName(i)
        name = name.decode(errors="replace") if name else "Unknown"
        print(f"Joystick {i}: {name}")

        if jid is None:
            jid = i

if jid is None:
    print("No joystick detected by GLFW.")
    glfw.glfwTerminate()
    sys.exit(2)

print()
print(f"Testing joystick {jid}.")
print("Press buttons and move analog sticks.")
print("Ctrl+C to stop.")
print()

last = None

try:
    while True:
        glfw.glfwPollEvents()

        naxes = ctypes.c_int()
        axes_ptr = glfw.glfwGetJoystickAxes(
            jid,
            ctypes.byref(naxes),
        )

        axes = (
            tuple(
                round(axes_ptr[i], 3)
                for i in range(naxes.value)
            )
            if axes_ptr
            else ()
        )

        nbuttons = ctypes.c_int()
        buttons_ptr = glfw.glfwGetJoystickButtons(
            jid,
            ctypes.byref(nbuttons),
        )

        buttons = (
            tuple(
                int(buttons_ptr[i])
                for i in range(nbuttons.value)
            )
            if buttons_ptr
            else ()
        )

        state = (axes, buttons)

        if state != last:
            print("axes:", axes)
            print("buttons:", buttons)
            print("---")
            last = state

        time.sleep(0.03)

except KeyboardInterrupt:
    pass
finally:
    glfw.glfwTerminate()
