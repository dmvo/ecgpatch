//
//  TPLTFirstViewController.h
//  TP
//
//  Created by Dmitri Vorobiev on 27/05/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TPLTVisibleDevices.h"

@interface TPLTDevicesViewController : UIViewController <UIPickerViewDelegate,
                                                        UIPickerViewDataSource,
                                                        TPLTDeviceSearch>

@end
