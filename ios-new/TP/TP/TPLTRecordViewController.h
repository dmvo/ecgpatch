//
//  TPLTRecordViewController.h
//  TP
//
//  Created by Dmitri Vorobiev on 23/06/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CorePlot-CocoaTouch.h"

@interface TPLTRecordViewController : UIViewController <CPTPlotDataSource>

@property (nonatomic, strong) NSString *fileName;

@end
