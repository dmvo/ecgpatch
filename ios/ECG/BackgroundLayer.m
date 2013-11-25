//
//  BackgroundLayer.m
//  ECG
//
//  Created by Joni Lampio on 20/11/13.
//  Copyright (c) 2013 Metropolia. All rights reserved.
//

#import "BackgroundLayer.h"

@implementation BackgroundLayer

+ (CAGradientLayer *) blueGradient: (float)first secondstop:(float)second
{
    UIColor *colorOne = [UIColor colorWithRed:(255/255.0)  green:(255/255.0)  blue:(255/255.0)  alpha:1.0];
    UIColor *colorTwo = [UIColor colorWithRed:(138/255.0) green:(211/255.0) blue:(243/255.0) alpha:1.0];
    
    NSArray *colors = [NSArray arrayWithObjects:(id)colorOne.CGColor, colorTwo.CGColor, nil];
    //NSNumber *stopOne = [NSNumber numberWithFloat:0.5];
    //NSNumber *stopTwo = [NSNumber numberWithFloat:1.0];
    
    NSNumber *stopOne = [NSNumber numberWithFloat: first];
    NSNumber *stopTwo = [NSNumber numberWithFloat: second];
    
    NSArray *locations = [NSArray arrayWithObjects:stopOne, stopTwo, nil];
    
    CAGradientLayer *headerLayer = [CAGradientLayer layer];
    headerLayer.colors = colors;
    headerLayer.locations = locations;
    
    return headerLayer;
}

@end
