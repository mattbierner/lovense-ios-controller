#import "LovenseController.h"

NSString* const LovenseErrorDomain = @"LovenseError";


@interface QueuedCommand : NSObject
@property (nonatomic) NSString* command;
@property (nonatomic) void(^callback)(NSString*, NSError*);
@end

@implementation QueuedCommand
@end


@implementation LovenseBaseController

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


- (id) initWithPeripheral:(CBPeripheral*)peripheral onReady:(void(^)(LovenseBaseController*))ready {
    _peripheral = peripheral;
    _onReady = ready;
    
    _currentCallback = nil;
    _queue = [[NSMutableArray alloc] init];
    
    peripheral.delegate = self;
    [peripheral discoverServices:@[[LovenseBaseController serviceUUID]]];
    return self;
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering services: %@", error);
        return;
    }
    
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:[LovenseBaseController serviceUUID]]) {
            [peripheral discoverCharacteristics:@[[LovenseBaseController transmitCharacteristicUUID], [LovenseBaseController receiveCharacteristicUUID]] forService:service];
            return;
        }
    }
}


- (void) peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering characteristics for service: %@", error);
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[LovenseBaseController transmitCharacteristicUUID]]) {
            _commandCharacteristic = characteristic;
        } else if ([characteristic.UUID isEqual:[LovenseBaseController receiveCharacteristicUUID]]) {
            _resultCharacteristic = characteristic;
            [_peripheral setNotifyValue:YES forCharacteristic:_resultCharacteristic];
        }
    }
    _onReady(self);
}

- (void) peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    if (![characteristic.UUID isEqual:[LovenseBaseController receiveCharacteristicUUID]]) {
        return;
    }
    
    if (error) {
        NSLog(@"Error updating characteristic value: %@ %@", [error localizedDescription], characteristic);
        if (_currentCallback) {
            _currentCallback(nil, error);
            _currentCallback = nil;
        }
        return;
    }
    
    if (_currentCallback) {
        NSString* result = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        
        // trim trailing `;`
        NSString* body = [result stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@";"]];
        _currentCallback(body, nil);
        _currentCallback = nil;
    }
}


- (void) peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    // TODO: In cases where an invalid command is sent, there does not seem to be any notifcation sent.
    // To workaround this case, I'm assuming that `didWriteValueForCharacteristic` and
    // `didUpdateValueForCharacteristic` will be invoked as a pair and not interleaved
    // with other commands. This may not be a safe assumption.
    if (_currentCallback) {
        _currentCallback(nil, [NSError errorWithDomain:LovenseErrorDomain code:1 userInfo: @{
            NSLocalizedDescriptionKey: @"No response received from previous command"
        }]);
        _currentCallback = nil;
    }
    
    if (_queue.count) {
        _currentCallback = ((QueuedCommand*)[_queue objectAtIndex:0]).callback;
        [_queue removeObjectAtIndex:0];
    }
    
    if (error) {
        NSLog(@"Error writing characteristic value: %@ %@",
              [error localizedDescription],
              characteristic);
    }
}


- (void) sendCommand:(NSString*)command onComplete:(void(^)(NSString*, NSError*))onDone {
    QueuedCommand* item = [[QueuedCommand alloc] init];
    item.command = command;
    item.callback = onDone;
    
    [_queue addObject:item];
    
    [_peripheral writeValue:[NSData dataWithBytes:command.UTF8String length:command.length] forCharacteristic:_commandCharacteristic
                          type:CBCharacteristicWriteWithResponse];
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

@end



@implementation LovenseVibratorController

+ (void) createWithPeripheral:(CBPeripheral*)peripheral onReady:(void(^)(LovenseVibratorController*))ready {
    LovenseVibratorController* hush = [LovenseVibratorController alloc];
    (void)[hush initWithPeripheral:peripheral onReady:^(LovenseBaseController* base){
        ready(hush);
    }];
}

- (void) setVibration:(int)level onComplete:(void(^)(BOOL, NSError*))callback {
    if (level < 0) {
        level = 0;
    }
    if (level > 20) {
        level = 20;
    }
    [self sendAckCommand:[NSString stringWithFormat:@"Vibrate:%i;", level] onComplete:callback];
}


@end
