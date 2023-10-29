#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>

#import "ResetAudio.h"

/// Resets audio interface(s) that macOS disconnected during sleep

/// Filter to iterate only streaming USB audio interfaces
IOUSBFindInterfaceRequest audioStreamingInterfaceRequest = {
    kUSBAudioInterfaceClass, kUSBAudioStreamingSubClass,
    kIOUSBFindInterfaceDontCare, kIOUSBFindInterfaceDontCare};

/// Get the number of endpoints available for the interface.
/// If 0, the interface needs to be reset.
int getNumEndpoints(io_service_t usbInterface) {
    CFMutableDictionaryRef interfaceProperties = NULL;
    IORegistryEntryCreateCFProperties(usbInterface, &interfaceProperties,
                                      kCFAllocatorDefault, kNilOptions);

    int bNumEndpoints = 0;

    if (interfaceProperties) {
        CFNumberRef bNumEndpointsRef =
            CFDictionaryGetValue(interfaceProperties, CFSTR(kUSBNumEndpoints));
        if (bNumEndpointsRef) {
            CFNumberGetValue(bNumEndpointsRef, kCFNumberIntType,
                             &bNumEndpoints);
        }
        CFRelease(interfaceProperties);
    }

    return bNumEndpoints;
}

/// Get the alternate setting of the interface.
/// If 0, the interface may need to be reset.
int getAlternateSetting(io_service_t usbInterface) {
    CFMutableDictionaryRef interfaceProperties = NULL;
    IORegistryEntryCreateCFProperties(usbInterface, &interfaceProperties,
                                      kCFAllocatorDefault, kNilOptions);

    int bAlternateSetting = 0;

    if (interfaceProperties) {
        CFNumberRef bNumEndpointsRef =
            CFDictionaryGetValue(interfaceProperties, CFSTR(kUSBAlternateSetting));
        if (bNumEndpointsRef) {
            CFNumberGetValue(bNumEndpointsRef, kCFNumberIntType,
                             &bAlternateSetting);
        }
        CFRelease(interfaceProperties);
    }

    return bAlternateSetting;
}

/// Reset the interface device descriptor by re-enumerating it.
void resetDeviceInterface(IOUSBDeviceInterface** deviceInterface) {
    (*deviceInterface)->USBDeviceOpen(deviceInterface);
    (*deviceInterface)->USBDeviceReEnumerate(deviceInterface, 0);
    (*deviceInterface)->USBDeviceClose(deviceInterface);
}

/// Check each interface of the device for number of endpoints.
/// If 0, reset it.
void processDeviceInterface(io_service_t usbInterface,
                         IOUSBDeviceInterface** deviceInterface) {
    UInt16 idVendor = 0;
    UInt16 idProduct = 0;
    (*deviceInterface)->GetDeviceVendor(deviceInterface, &idVendor);
    (*deviceInterface)->GetDeviceProduct(deviceInterface, &idProduct);
    NSLog(@"Process interface: Vendor ID = 0x%X, Product ID = 0x%X", idVendor, idProduct);

    int bNumEndpoints = getNumEndpoints(usbInterface);
    int bAlternateSetting = getAlternateSetting(usbInterface);

    if (bNumEndpoints == 0) {
        NSLog(@"Detected disconnection via bNumEndpoints = 0; resetting...");
        resetDeviceInterface(deviceInterface);
    } else if (bAlternateSetting == 0) {
        NSLog(@"Detected disconnection via bAlternateSetting = 0; resetting...");
        resetDeviceInterface(deviceInterface);
    } else {
        NSLog(@"Device operational; skipping.");
    }
}

/// Get the interface of the device.
IOUSBDeviceInterface** getDeviceInterface(io_service_t usbDevice) {
    SInt32 score;
    IOCFPlugInInterface** plugInInterface = NULL;
    kern_return_t kr = IOCreatePlugInInterfaceForService(
        usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
        &plugInInterface, &score);
    if (kr != kIOReturnSuccess || !plugInInterface)
        return NULL;

    IOUSBDeviceInterface** deviceInterface = NULL;
    (*plugInInterface)
        ->QueryInterface(plugInInterface,
                         CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                         (LPVOID*)&deviceInterface);
    (*plugInInterface)->Release(plugInInterface);

    return deviceInterface;
}

/// Get the interface iterator for a device.
io_iterator_t getInterfaceIterator(IOUSBDeviceInterface** deviceInterface) {
    io_iterator_t interfaceIterator;
    (*deviceInterface)
        ->CreateInterfaceIterator(deviceInterface,
                                  &audioStreamingInterfaceRequest,
                                  &interfaceIterator);
    return interfaceIterator;
}

/// Check each USB device by checking each of its interfaces.
void processUSBDevice(io_service_t usbDevice) {
    IOUSBDeviceInterface** deviceInterface = getDeviceInterface(usbDevice);
    if (!deviceInterface) {
        return;
    }

    io_iterator_t interfaceIterator = getInterfaceIterator(deviceInterface);
    if (!interfaceIterator) {
        (*deviceInterface)->Release(deviceInterface);
        return;
    }

    io_service_t usbInterface;
    while ((usbInterface = IOIteratorNext(interfaceIterator))) {
        processDeviceInterface(usbInterface, deviceInterface);
        IOObjectRelease(usbInterface);
    }

    (*deviceInterface)->Release(deviceInterface);
}

/// Get the iterator for a device.
io_iterator_t getDeviceIterator(void) {
    io_iterator_t deviceIterator;
    IOServiceGetMatchingServices(kIOMasterPortDefault,
                                 IOServiceMatching(kIOUSBDeviceClassName),
                                 &deviceIterator);
    return deviceIterator;
}

/// Main function to loop through all the USB devices and
/// their interfaces, and check for device(s) that need re-enumeration.
void findAndResetAudioInterfaces(void) {
    io_iterator_t deviceIterator = getDeviceIterator();

    io_service_t usbDevice;
    while ((usbDevice = IOIteratorNext(deviceIterator))) {
        processUSBDevice(usbDevice);
        IOObjectRelease(usbDevice);
    }

    IOObjectRelease(deviceIterator);
}
