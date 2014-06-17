//
//  TPLTSecondViewController.h
//  TP
//
//  Created by Dmitri Vorobiev on 27/05/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CorePlot-CocoaTouch.h"

@interface TPLTRealTimeViewController : UIViewController <CPTPlotDataSource>

- (void) setBPM: (uint16_t) bpm;
- (void) gotSample: (NSNumber *) sample;

@end
