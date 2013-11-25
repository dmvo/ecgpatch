//
//  BackgroundLayer.h
//  ECG
//
//  Created by Joni Lampio on 20/11/13.
//  Copyright (c) 2013 Metropolia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

@interface BackgroundLayer : NSObject
+(CAGradientLayer *) blueGradient:(float)first secondstop:(float) second;
@end
