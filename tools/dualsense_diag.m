#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>

static uint8_t reportBuffer[512];

static unsigned long rawCount = 0;
static unsigned long valueCount = 0;

static void rawReportCallback(
    void *context,
    IOReturn result,
    void *sender,
    IOHIDReportType type,
    uint32_t reportID,
    uint8_t *report,
    CFIndex reportLength
) {
    rawCount++;

    printf(
        "RAW #%lu id=0x%02X len=%ld ",
        rawCount,
        reportID,
        (long)reportLength
    );

    int count = reportLength < 16
        ? (int)reportLength
        : 16;

    for (int i = 0; i < count; i++) {
        printf("%02X ", report[i]);
    }

    printf("\n");
    fflush(stdout);
}

static void valueCallback(
    void *context,
    IOReturn result,
    void *sender,
    IOHIDValueRef value
) {
    valueCount++;

    IOHIDElementRef element =
        IOHIDValueGetElement(value);

    uint32_t page =
        IOHIDElementGetUsagePage(element);

    uint32_t usage =
        IOHIDElementGetUsage(element);

    CFIndex integerValue =
        IOHIDValueGetIntegerValue(value);

    printf(
        "VALUE #%lu page=0x%02X usage=0x%02X value=%ld\n",
        valueCount,
        page,
        usage,
        (long)integerValue
    );

    fflush(stdout);
}

static void deviceMatched(
    void *context,
    IOReturn result,
    void *sender,
    IOHIDDeviceRef device
) {
    CFTypeRef product =
        IOHIDDeviceGetProperty(
            device,
            CFSTR(kIOHIDProductKey)
        );

    printf("=== DualSense detected ===\n");

    if (product) {
        char name[256] = {0};

        CFStringGetCString(
            (CFStringRef)product,
            name,
            sizeof(name),
            kCFStringEncodingUTF8
        );

        printf("Product: %s\n", name);
    }

    CFArrayRef elements =
        IOHIDDeviceCopyMatchingElements(
            device,
            NULL,
            0
        );

    if (elements) {
        CFIndex count =
            CFArrayGetCount(elements);

        printf(
            "HID elements discovered: %ld\n",
            (long)count
        );

        CFRelease(elements);
    }

    IOHIDDeviceRegisterInputValueCallback(
        device,
        valueCallback,
        NULL
    );

    IOHIDDeviceRegisterInputReportCallback(
        device,
        reportBuffer,
        sizeof(reportBuffer),
        rawReportCallback,
        NULL
    );

    printf(
        "Callbacks registered.\n"
        "Press buttons and move sticks.\n"
        "Ctrl+C to stop.\n\n"
    );
}

int main(void) {
    @autoreleasepool {
        IOHIDManagerRef manager =
            IOHIDManagerCreate(
                kCFAllocatorDefault,
                kIOHIDOptionsTypeNone
            );

        if (!manager) {
            fprintf(
                stderr,
                "Failed to create IOHIDManager\n"
            );

            return 1;
        }

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

            return 2;
        }

        printf(
            "Waiting for Sony DualSense 054c:0ce6...\n"
        );

        CFRunLoopRun();

        IOHIDManagerClose(
            manager,
            kIOHIDOptionsTypeNone
        );

        CFRelease(manager);
    }

    return 0;
}
