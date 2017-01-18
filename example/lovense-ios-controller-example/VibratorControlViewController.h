#import <UIKit/UIKit.h>
#import "LovenseController.h"

@interface VibratorControlViewController : UIViewController
{
    BOOL _isUpdatingVibration;
}

@property (nonatomic, retain) IBOutlet UISlider* slider;
@property (nonatomic, retain) LovenseBaseController* vibrator;
@property (nonatomic) int vibrationStrength;

- (IBAction) sliderValueChange:(id)sender;

@end
