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
    CBCharacteristic* _commandCharacteristic;
    CBCharacteristic* _resultCharacteristic;
    void(^_onReady)(LovenseBaseController*, NSError*);
    
    NSMutableArray* _queue;
    BOOL _busy;
}
@property (nonatomic, readonly) CBPeripheral* peripheral;
@property (nonatomic, readonly) CBUUID* serviceUUID;
@property (nonatomic, readonly) CBUUID* transmitCharacteristicUUID;
@property (nonatomic, readonly) CBUUID* receiveCharacteristicUUID;

- (LovenseBaseController*) initWithPeripheral:(CBPeripheral*) peripheral
    service:(CBUUID*)serviceUUID
    transmitCharacteristic:(CBUUID*)transmitCharacteristicUUID
    receiveCharacteristic:(CBUUID*)receiveCharacteristicUUID
    onReady:(void(^)(LovenseBaseController*, NSError*))ready;

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

/**
    Set the vibration strength.
    
    Returns boolean indicating success
*/
- (void) setVibration:(unsigned)level
    onComplete:(void(^)(BOOL, NSError*))callback;

@end


/**
    Interfaces with Lovense Lush/Hush toys.
*/
@interface LovenseVibratorController : LovenseBaseController

+ (CBUUID*) serviceUUID;
+ (CBUUID*) transmitCharacteristicUUID;
+ (CBUUID*) receiveCharacteristicUUID;

+ (NSString*) lushPeripheralName;
+ (NSString*) hushPeripheralName;

/**
    Create a new vibrator controller.
    
    Invokes `ready` with the resulting controller once everything is initialized.
*/
+ (void) createWithPeripheral:(CBPeripheral*)peripheral
    onReady:(void(^)(LovenseVibratorController*, NSError*))ready;

@end


/**
    Interfaces with Lovense Max toys.
*/
@interface LovenseMaxController : LovenseBaseController

+ (CBUUID*) serviceUUID;
+ (CBUUID*) transmitCharacteristicUUID;
+ (CBUUID*) receiveCharacteristicUUID;

+ (NSString*) maxPeripheralName;

/**
    Create a new Max controller.
    
    Invokes `ready` with the resulting controller once everything is initialized.
*/
+ (void) createWithPeripheral:(CBPeripheral*)peripheral
    onReady:(void(^)(LovenseMaxController*, NSError*))ready;

/**
    Set the absolute air level.
    
    Returns boolean indicating success
*/
- (void) setAirLevel:(unsigned)level
    onComplete:(void(^)(BOOL, NSError*))callback;

/**
    Increases air from the current level.
    
    Returns boolean indicating success
*/
- (void) airIn:(unsigned)change
    onComplete:(void(^)(BOOL, NSError*))callback;


/**
    Decreases air from the current level.
 
    Returns boolean indicating success
*/
- (void) airOut:(unsigned)change
    onComplete:(void(^)(BOOL, NSError*))callback;

@end


/**
    Interfaces with Lovense Nora toys.
    
    TODO: Unverified. Implementation is best guess based on the max
*/
@interface LovenseNoraController : LovenseBaseController

+ (CBUUID*) serviceUUID;
+ (CBUUID*) transmitCharacteristicUUID;
+ (CBUUID*) receiveCharacteristicUUID;

/**
    Create a new Nora controller.
    
    Invokes `ready` with the resulting controller once everything is initialized.
*/
+ (void) createWithPeripheral:(CBPeripheral*)peripheral
    onReady:(void(^)(LovenseNoraController*, NSError*))ready;

/**
    Set the rotation speed.
    
    Returns boolean indicating success
*/
- (void) setRotation:(unsigned)level
    onComplete:(void(^)(BOOL, NSError*))callback;

@end
