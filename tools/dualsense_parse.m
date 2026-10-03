#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>

static uint8_t reportBuffer[512];

static const char *dpadName(uint8_t d)
{
    switch (d & 0x0F)
    {
        case 0: return "UP";
        case 1: return "UP+RIGHT";
        case 2: return "RIGHT";
        case 3: return "DOWN+RIGHT";
        case 4: return "DOWN";
        case 5: return "DOWN+LEFT";
        case 6: return "LEFT";
        case 7: return "UP+LEFT";
        default: return "CENTER";
    }
}

static float axis(uint8_t value)
{
    return ((float)value - 128.0f) / 127.0f;
}

static void rawReportCallback(
    void *context,
    IOReturn result,
    void *sender,
    IOHIDReportType type,
    uint32_t reportID,
    uint8_t *report,
    CFIndex length
) {
    if (length < 12 || report[0] != 0x31) {
        return;
    }

    // Bluetooth enhanced input report.
    // Byte 0 = report ID 0x31
    // Byte 1 = Bluetooth sequence/header
    // Byte 2+ = DualSense state payload
    const uint8_t *state = &report[2];

    uint8_t lx = state[0];
    uint8_t ly = state[1];
    uint8_t rx = state[2];
    uint8_t ry = state[3];

    uint8_t l2 = state[4];
    uint8_t r2 = state[5];

    uint8_t b0 = state[7];
    uint8_t b1 = state[8];
    uint8_t b2 = state[9];

    uint8_t dpad = b0 & 0x0F;

    BOOL square =
        b0 & 0x10;

    BOOL cross =
        b0 & 0x20;

    BOOL circle =
        b0 & 0x40;

    BOOL triangle =
        b0 & 0x80;

    BOOL L1 =
        b1 & 0x01;

    BOOL R1 =
        b1 & 0x02;

    BOOL L2button =
        b1 & 0x04;

    BOOL R2button =
        b1 & 0x08;

    BOOL create =
        b1 & 0x10;

    BOOL options =
        b1 & 0x20;

    BOOL L3 =
        b1 & 0x40;

    BOOL R3 =
        b1 & 0x80;

    BOOL ps =
        b2 & 0x01;

    BOOL touch =
        b2 & 0x02;

    BOOL mute =
        b2 & 0x04;

    printf(
        "\r"
        "LS(%+.2f,%+.2f) "
        "RS(%+.2f,%+.2f) "
        "L2=%3u R2=%3u "
        "DPAD=%-10s "
        "%s%s%s%s "
        "%s%s %s%s "
        "%s%s %s%s "
        "%s%s%s      ",
        axis(lx),
        axis(ly),
        axis(rx),
        axis(ry),
        l2,
        r2,
        dpadName(dpad),

        square ? "SQ " : "",
        cross ? "X " : "",
        circle ? "O " : "",
        triangle ? "TRI " : "",

        L1 ? "L1 " : "",
        R1 ? "R1 " : "",

        L2button ? "L2B " : "",
        R2button ? "R2B " : "",

        create ? "CREATE " : "",
        options ? "OPTIONS " : "",

        L3 ? "L3 " : "",
        R3 ? "R3 " : "",

        ps ? "PS " : "",
        touch ? "PAD " : "",
        mute ? "MUTE " : ""
    );

    fflush(stdout);
}

static void deviceMatched(
    void *context,
    IOReturn result,
    void *sender,
    IOHIDDeviceRef device
) {
    printf(
        "DualSense detected.\n"
        "Press buttons and move sticks.\n"
        "Ctrl+C to stop.\n\n"
    );

    IOHIDDeviceRegisterInputReportCallback(
        device,
        reportBuffer,
        sizeof(reportBuffer),
        rawReportCallback,
        NULL
    );
}

int main(void)
{
    @autoreleasepool {
        IOHIDManagerRef manager =
            IOHIDManagerCreate(
                kCFAllocatorDefault,
                kIOHIDOptionsTypeNone
            );

        NSDictionary *match = @{
            @kIOHIDVendorIDKey: @0x054C,
            @kIOHIDProductIDKey: @0x0CE6
        };

        IOHIDManagerSetDeviceMatching(
            manager,
            (__bridge CFDictionaryRef)match
        );

        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            deviceMatched,
            NULL
        );

        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetCurrent(),
            kCFRunLoopDefaultMode
        );

        IOReturn ret =
            IOHIDManagerOpen(
                manager,
                kIOHIDOptionsTypeNone
            );

        if (ret != kIOReturnSuccess) {
            fprintf(
                stderr,
                "IOHIDManagerOpen failed: 0x%x\n",
                ret
            );

            return 1;
        }

        CFRunLoopRun();
    }

    return 0;
}
