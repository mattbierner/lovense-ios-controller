#import "LovenseController.h"

NSString* const LovenseErrorDomain = @"LovenseError";


@interface QueuedCommand : NSObject
@property (nonatomic) NSString* command;
@property (nonatomic) void(^callback)(NSString*, NSError*);
@end

@implementation QueuedCommand
@end


@implementation LovenseBaseController

- (LovenseBaseController*) initWithPeripheral:(CBPeripheral*) peripheral
    service:(CBUUID*)serviceUUID
    transmitCharacteristic:(CBUUID*)transmitCharacteristicUUID
    receiveCharacteristic:(CBUUID*)receiveCharacteristicUUID
    onReady:(void(^)(LovenseBaseController*, NSError*))ready
{
    self = [super init];
    _peripheral = peripheral;
    _serviceUUID = serviceUUID;
    _transmitCharacteristicUUID = transmitCharacteristicUUID;
    _receiveCharacteristicUUID = receiveCharacteristicUUID;
    
    _onReady = ready;
    _queue = [[NSMutableArray alloc] init];
    _busy = NO;
    
    peripheral.delegate = self;
    [peripheral discoverServices:@[serviceUUID]];
    return self;
}

- (void) peripheral:(CBPeripheral *)peripheral
    didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", error);
        if (_onReady) {
            _onReady(nil, [NSError errorWithDomain:LovenseErrorDomain code:1 userInfo: @{
                NSLocalizedDescriptionKey: @"Error discovering services"
            }]);
            _onReady = nil;
        }
        return;
    }
    
    for (CBService* service in peripheral.services) {
        if ([service.UUID isEqual:self.serviceUUID]) {
            [peripheral discoverCharacteristics:@[self.transmitCharacteristicUUID, self.receiveCharacteristicUUID] forService:service];
            return;
        }
    }
    
    if (_onReady) {
        NSLog(@"Could not find correct service");
        _onReady(nil, [NSError errorWithDomain:LovenseErrorDomain code:2 userInfo: @{
            NSLocalizedDescriptionKey: @"Could not find correct service"
        }]);
        _onReady = nil;
    }
}


- (void) peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristics for service: %@", error);
        if (_onReady) {
            _onReady(nil, [NSError errorWithDomain:LovenseErrorDomain code:3 userInfo: @{
                NSLocalizedDescriptionKey: @"Error discovering characteristics"
            }]);
            _onReady = nil;
        }
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:self.transmitCharacteristicUUID]) {
            _commandCharacteristic = characteristic;
        } else if ([characteristic.UUID isEqual:self.receiveCharacteristicUUID]) {
            _resultCharacteristic = characteristic;
            [_peripheral setNotifyValue:YES forCharacteristic:_resultCharacteristic];
        }
    }
    
    if (_commandCharacteristic && _resultCharacteristic) {
        if (_onReady) {
            _onReady(self, nil);
            _onReady = nil;
        }
    } else {
        NSLog(@"Could not find correct characteristics: %@", error);
        if (_onReady) {
            _onReady(nil, [NSError errorWithDomain:LovenseErrorDomain code:3 userInfo: @{
                NSLocalizedDescriptionKey: @"Could not find correct characteristics"
            }]);
            _onReady = nil;
        }
    }
}

- (void) peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (![characteristic.UUID isEqual:self.receiveCharacteristicUUID]) {
        return;
    }
    
    NSString* response = nil;
    void(^callback)(NSString*, NSError*) = nil;
    @synchronized (_queue) {
        _busy = NO;
        
        if (_queue.count > 0) {
            QueuedCommand* command = (QueuedCommand*)[_queue objectAtIndex:0];
            [_queue removeObjectAtIndex:0];
            callback = command.callback;

            if (!error) {
                response = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
            }
            
            [self _tryPump];
        } else {
            NSLog(@"Queue in bad state");
        }
    }
    
    if (callback) {
        if (response) {
            // trim trailing `;`
            NSString* body = [response stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@";"]];
            callback(body, nil);
        } else if (error) {
            NSLog(@"Error updating value %@", error);
            callback(nil, error);
        }
    }
}


- (void) peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {

    if (error) {
        NSLog(@"Error writing characteristic value: %@ %@",
              [error localizedDescription],
              characteristic);
    }
}

- (void) _tryPump {
    if (_queue.count == 0)
        return;

    if (!_busy) {
        _busy = YES;
        
        QueuedCommand* command = (QueuedCommand*)[_queue objectAtIndex:0];
        [_peripheral writeValue:[NSData dataWithBytes:command.command.UTF8String length:command.command.length]
            forCharacteristic:_commandCharacteristic
            type:CBCharacteristicWriteWithResponse];
    }
}

- (void) sendCommand:(NSString*)command onComplete:(void(^)(NSString*, NSError*))onDone
{
    QueuedCommand* item = [[QueuedCommand alloc] init];
    item.command = command;
    item.callback = onDone;
    
    @synchronized (_queue) {
        [_queue addObject:item];
        [self _tryPump];
    }
}


- (void) sendAckCommand:(NSString*)command onComplete:(void(^)(BOOL, NSError*))callback {
    [self sendCommand:command onComplete:^(NSString* response, NSError* err) {
        if (!callback)
            return;
        
        if (err) {
            callback(NO, err);
        } else {
            callback([response isEqualToString:@"OK"], nil);
        }
    }];
}

- (void) getDeviceType:(void(^)(NSString*, NSError*))callback {
    [self sendCommand:@"DeviceType;" onComplete:callback];
}

- (void) getBattery:(void(^)(NSNumber*, NSError*))callback {
    [self sendCommand:@"Battery;" onComplete:^(NSString* result, NSError* err) {
        if (err) {
            callback(nil, err);
        } else {
            NSNumberFormatter* f = [[NSNumberFormatter alloc] init];
            f.numberStyle = NSNumberFormatterDecimalStyle;
            NSNumber* level = [f numberFromString:result];
            callback(level, nil);
        }
    }];
}

- (void) powerOff:(void(^)(BOOL, NSError*))callback {
    [self sendAckCommand:@"PowerOff;" onComplete: callback];
}


- (void) setVibration:(unsigned)level onComplete:(void(^)(BOOL, NSError*))callback {
    [self sendAckCommand:[NSString stringWithFormat:@"Vibrate:%i;", MIN(level, 20)] onComplete:callback];
}

@end



@implementation LovenseVibratorController

+ (CBUUID*) serviceUUID {
    return [CBUUID UUIDWithString:@"6E400001-B5A3-F393-E0A9-E50E24DCCA9E"];
}

+ (CBUUID*) transmitCharacteristicUUID {
    return [CBUUID UUIDWithString:@"6E400002-B5A3-F393-E0A9-E50E24DCCA9E"];
}

+ (CBUUID*) receiveCharacteristicUUID {
    return [CBUUID UUIDWithString:@"6E400003-B5A3-F393-E0A9-E50E24DCCA9E"];
}

+ (NSString*) lushPeripheralName {
    return @"LVS-S001";
}

+ (NSString*) hushPeripheralName {
    return @"LVS-Z001";
}

+ (void) createWithPeripheral:(CBPeripheral*)peripheral onReady:(void(^)(LovenseVibratorController*, NSError*))ready {
    LovenseVibratorController* vibe = [LovenseVibratorController alloc];
    (void)[vibe initWithPeripheral:peripheral
        service:LovenseVibratorController.serviceUUID
        transmitCharacteristic:LovenseVibratorController.transmitCharacteristicUUID
        receiveCharacteristic:LovenseVibratorController.receiveCharacteristicUUID
        onReady:^(LovenseBaseController* _, NSError *err) {
            ready(err ? nil : vibe, err);
        }];
}

@end



@implementation LovenseMaxController

+ (CBUUID*) serviceUUID {
    return [CBUUID UUIDWithString:@"FFF0"];
}

+ (CBUUID*) transmitCharacteristicUUID {
    return [CBUUID UUIDWithString:@"FFF2"];
}

+ (CBUUID*) receiveCharacteristicUUID {
    return [CBUUID UUIDWithString:@"FFF1"];
}

+ (NSString*) maxPeripheralName {
    return @"LVS-B011";
}


+ (void) createWithPeripheral:(CBPeripheral*)peripheral onReady:(void(^)(LovenseMaxController*, NSError*))ready {
    LovenseMaxController* max = [LovenseMaxController alloc];
    (void)[max initWithPeripheral:peripheral
        service:LovenseMaxController.serviceUUID
        transmitCharacteristic:LovenseMaxController.transmitCharacteristicUUID
        receiveCharacteristic:LovenseMaxController.receiveCharacteristicUUID
        onReady:^(LovenseBaseController* _, NSError *err) {
            ready(err ? nil : max, err);
        }];
}


- (void) setAirLevel:(unsigned)level
    onComplete:(void(^)(BOOL, NSError*))callback
{
    [self sendAckCommand:[NSString stringWithFormat:@"Air:Level:%i;", MIN(level, 5)] onComplete:callback];
}


- (void) airIn:(unsigned)change
    onComplete:(void(^)(BOOL, NSError*))callback
{
    [self sendAckCommand:[NSString stringWithFormat:@"Air:In:%i;", MIN(change, 5)] onComplete:callback];
}


- (void) airOut:(unsigned)change
    onComplete:(void(^)(BOOL, NSError*))callback
{
    [self sendAckCommand:[NSString stringWithFormat:@"Air:Out:%i;", MIN(change, 5)] onComplete:callback];
}

@end


@implementation LovenseNoraController

+ (CBUUID*) serviceUUID {
    return [CBUUID UUIDWithString:@"FFF0"];
}

+ (CBUUID*) transmitCharacteristicUUID {
    return [CBUUID UUIDWithString:@"FFF2"];
}

+ (CBUUID*) receiveCharacteristicUUID {
    return [CBUUID UUIDWithString:@"FFF1"];
}


+ (void) createWithPeripheral:(CBPeripheral*)peripheral onReady:(void(^)(LovenseNoraController*, NSError*))ready {
    LovenseNoraController* nora = [LovenseNoraController alloc];
    (void)[nora initWithPeripheral:peripheral
        service:LovenseNoraController.serviceUUID
        transmitCharacteristic:LovenseNoraController.transmitCharacteristicUUID
        receiveCharacteristic:LovenseNoraController.receiveCharacteristicUUID
        onReady:^(LovenseBaseController* _, NSError *err) {
            ready(err ? nil : nora, err);
        }];
}


- (void) setRotation:(unsigned)level
    onComplete:(void(^)(BOOL, NSError*))callback
{
    [self sendAckCommand:[NSString stringWithFormat:@"Rotate:%i;", MIN(level, 20)] onComplete:callback];
}

@end

