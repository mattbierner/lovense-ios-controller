#import <Foundation/Foundation.h>
@import CoreBluetooth;

extern NSString* const LovenseErrorDomain;

/**
    Callback invoked when a command is completed.
*/
typedef void(^LovenseCallback)(NSString*, NSError*);

/**
    Base class for interfacing with Lovense devices.
*/
@interface LovenseBaseController : NSObject <CBPeripheralDelegate>
{
    CBPeripheral* _peripheral;
    CBCharacteristic* _commandCharacteristic;
    CBCharacteristic* _resultCharacteristic;
    void(^_onReady)(LovenseBaseController*);
    
    LovenseCallback _currentCallback;
    NSMutableArray* _queue;
}

+ (CBUUID*) serviceUUID;
+ (CBUUID*) transmitCharacteristicUUID;
+ (CBUUID*) receiveCharacteristicUUID;

+ (NSString*) lushPeripheralName;
+ (NSString*) hushPeripheralName;

- (id) initWithPeripheral:(CBPeripheral*)peripheral
    onReady:(void(^)(LovenseBaseController*))ready;

/**
    Send a raw command to the device.
    
    Invokes the callback with the result of the command. If the command is invalid,
    the callback will not be invoked until the next command is executed.
*/
- (void) sendCommand:(NSString*)command
    onComplete:(LovenseCallback)callback;

/**
    Send a command to the device for a command with a result that indicates success or failure.
*/
- (void) sendAckCommand:(NSString*)command
    onComplete:(void(^)(BOOL, NSError*))callback;

/**
    Get information about the toy.
    
    Returns a number between 0 and 100 on success.
*/
- (void) getDeviceType:(void(^)(NSString*, NSError*))callback;

/**
    Get the current battery level of the toy.
    
    Returns a number between 0 and 100 on success.
*/
- (void) getBattery:(void(^)(NSNumber*, NSError*))callback;

/**
    Power off the device
 
    Returns boolean indicating success
*/
- (void) powerOff:(void(^)(BOOL, NSError*))callback;

@end


/**
    Interfaces with Lovense Lush/Hush devices.
*/
@interface LovenseVibratorController : LovenseBaseController

/**
    Create a new vibrator controller.
    
    Invokes `ready` with the resulting controller once everything is initialized.
*/
+ (void) createWithPeripheral:(CBPeripheral*)peripheral
    onReady:(void(^)(LovenseVibratorController*))ready;

/**
    Set the vibration strength.
    
    Returns boolean indicating success
*/
- (void) setVibration:(int)level
    onComplete:(void(^)(BOOL, NSError*))callback;

@end
