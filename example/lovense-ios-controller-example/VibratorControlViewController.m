
#import "VibratorControlViewController.h"

@interface VibratorControlViewController ()
- (void) setVibration:(int)strength;
@end


@implementation VibratorControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.vibrationStrength = 0;
    _isUpdatingVibration = NO;
}

- (IBAction) sliderValueChange:(id)sender {    
    int value = floor(self.slider.value);
    [self setVibration:value];
}


- (void) setVibration:(int)strength {
    self.vibrationStrength = strength;

    // shitty debounce
    if (_isUpdatingVibration)
        return;
    
    __weak typeof(self) weakSelf = self;
    _isUpdatingVibration = YES;
    [self.vibrator setVibration:strength onComplete:^(BOOL ok, NSError* error) {
        _isUpdatingVibration = NO;
        if (strength != weakSelf.vibrationStrength) {
            [weakSelf setVibration:weakSelf.vibrationStrength];
        }
    }];
}


@end
