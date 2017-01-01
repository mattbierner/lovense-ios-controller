# Lovense iOS Controller

Small Objective-C library for controlling Lovense sex toys (*Lush*, *Hush*, *Nora*, *Max*) over Bluetooth LE from an iOS device.

## Usage
To get started, simply include `LovenseController.h` and `LovenseController.m` in your project.

The library use [Core Bluetooth](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/AboutCoreBluetooth/Introduction.html) for communicating with the toys. To connect a toy, start by scanning for devices:

```obj-c
#import "LovenseController.h"

...

CBCentralManager* blueToothManager = ...;

[blueToothManager scanForPeripheralsWithServices:@[[LovenseVibratorController serviceUUID]] options:nil];
```

After connecting to the discovered toy using Core Bluetooth, create a `LovenseVibratorController` from the `CBPeripheral` to start using it:

```obj-c
- (void) centralManager:(CBCentralManager *)central
    didConnectPeripheral:(CBPeripheral *)peripheral
{
    // Create a controller for a lush or hush device
    [LovenseVibratorController createWithPeripheral:peripheral onReady:^(LovenseVibratorController* toy) {

        // Get the battery level
        [toy getBattery:^(NSNumber* result, NSError* err) {
            NSLog(@"Battery: %@", result);
        }];
    
        // Start vibrations
        [toy setVibration:5 onComplete:^(BOOL ok, NSError* error) {
            NSLog(@"Started vibration");
        }];
    }];
}

```

# Example App
A very basic example iOS application is included in `example/`. This app shows how to use basic Core Bluetooth to connect to a *Lush* or *Hush* toy and control its vibration.


## Limitations
This library is a prototype and not production ready. 

* Currently only supports the *Lush* and *Hush* toys. The *Max* and *Nora* toys should work, but this library does not define a nice API for them. If you have either and can help test, please let me know.
* Unsupported/invalid commands are not handled very well.
* Needs more testing around error cases.
* Needs more testing for threading and potential communication interleaving issues.
* The example app is super basic and buggy.

PRs are welcome.


## Credits

* [Inspiration and basic protocol documentation](https://github.com/metafetish/lovesense-py)
* [Information about the bluetooth chip used in the toys](https://www.nordicsemi.com/eng/Products/Bluetooth-low-energy/nRF8001)
* [Information about serial communication over BLE](https://devzone.nordicsemi.com/documentation/nrf51/6.0.0/s110/html/a00066.html)


----

*Disclaimer:* I'm not affiliated with Lovense in any way. This project is for noncommercial, personal use. For commercial applications, try contacting Lovense.
