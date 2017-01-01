#import "ViewController.h"

@interface ViewController()

- (BOOL) isSupportedPeripheral:(CBPeripheral*)peripheral;

- (NSString*) displayNameForPeripheral:(CBPeripheral*)peripheral;

- (void) startScanningForPeripherals;

@end


@implementation ViewController

- (void) viewDidLoad
{
    [super viewDidLoad];
    _discoveredPeripherals = [[NSMutableArray alloc] init];
   _manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
   
   _vibratorControlViewController = [[VibratorControlViewController alloc] initWithNibName:@"VibratorControlViewController" bundle:nil];
}


- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_discoveredPeripherals count];
}


- (void) viewDidAppear:(BOOL)animated {

    if (_peripheral) {
        [_manager cancelPeripheralConnection:_peripheral];
        _peripheral = nil;
    }
    [self startScanningForPeripherals];
}


- (void) viewWillDisappear:(BOOL)animated {
    [_manager stopScan];
}

 
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"RecipeCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    cell.textLabel.text = [self displayNameForPeripheral:[_discoveredPeripherals objectAtIndex:indexPath.row]];
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CBPeripheral* peripheral = [_discoveredPeripherals objectAtIndex:indexPath.row];
    if (!peripheral)
        return;
    
    [_manager stopScan];
    _peripheral = peripheral;
    [_manager connectPeripheral:peripheral options:nil];
    [self.navigationController pushViewController:_vibratorControlViewController animated:YES];
}


- (BOOL) isSupportedPeripheral:(CBPeripheral*)peripheral
{
    if (!peripheral.name)
        return NO;
    
    return [peripheral.name isEqualToString:[LovenseBaseController lushPeripheralName]]
        || [peripheral.name isEqualToString:[LovenseBaseController hushPeripheralName]];
}


- (NSString*) displayNameForPeripheral:(CBPeripheral*)peripheral {
    if ([[LovenseBaseController lushPeripheralName] isEqualToString:peripheral.name]) {
        return @"Lush";
    } else if ([[LovenseBaseController hushPeripheralName] isEqualToString:peripheral.name]) {
        return @"Hush";
    }
    return @"Unknown";
}


- (void) startScanningForPeripherals {
    _discoveredPeripherals = [[NSMutableArray alloc] init];
    [self.tableView reloadData];

    [_manager scanForPeripheralsWithServices:@[[LovenseVibratorController serviceUUID]] options:nil];
}


- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBManagerStatePoweredOff:
            NSLog(@"CoreBluetooth BLE hardware is powered off");
            break;
        case CBManagerStatePoweredOn:
            [self startScanningForPeripherals];
            break;
        default:
            break;
    }
}

- (void) centralManager:(CBCentralManager *)central
  didDiscoverPeripheral:(CBPeripheral *)peripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered %@", peripheral.name);
  
    if ([self isSupportedPeripheral: peripheral]) {
        [_discoveredPeripherals addObject:peripheral];
    }
    
    [self.tableView reloadData];
}

- (void)centralManager:(CBCentralManager *)central
    didConnectPeripheral:(CBPeripheral *)peripheral
{
    [LovenseVibratorController createWithPeripheral:peripheral onReady:^(LovenseVibratorController* device) {
        _vibratorControlViewController.vibrator = device;

        [device getBattery:^(NSNumber* result, NSError* err) {
            NSLog(@"Battery: %@", result);
        }];
    
        [device getDeviceType:^(NSString* result, NSError* err) {
            NSLog(@"Type: %@", result);
        }];
    }];
}


@end
