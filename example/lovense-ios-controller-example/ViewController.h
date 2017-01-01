#import <UIKit/UIKit.h>
@import CoreBluetooth;
#import "VibratorControlViewController.h"

@interface ViewController : UIViewController <
    UITableViewDelegate,
    UITableViewDataSource,
    CBCentralManagerDelegate>
{
    NSMutableArray* _discoveredPeripherals;

    CBCentralManager* _manager;
    CBPeripheral* _peripheral;
    VibratorControlViewController* _vibratorControlViewController;
}

@property (nonatomic, retain) IBOutlet UITableView* tableView;

@end

