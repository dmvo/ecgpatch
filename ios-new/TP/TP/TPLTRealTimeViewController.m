//
//  TPLTSecondViewController.m
//  TP
//
//  Created by Dmitri Vorobiev on 27/05/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import "TPLTRealTimeViewController.h"
#import <math.h>

@interface TPLTRealTimeViewController ()

@property (nonatomic, strong) CPTGraphHostingView *hostView;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) double kFramerate;
@property (weak, nonatomic) IBOutlet UILabel *bpmLabel;
@property (nonatomic, strong) NSMutableArray *ecgData;
@property (nonatomic, strong) NSMutableArray *ecgTime;
@property (nonatomic, strong) CPTScatterPlot *plot;

- (void) initPlot;
- (void) configureHost;
- (void) configureGraph;
- (void) configureScatterPlot;

@end

@implementation TPLTRealTimeViewController

@synthesize hostView;
@synthesize kFramerate;
@synthesize timer;
@synthesize bpmLabel;
@synthesize ecgData;
@synthesize ecgTime;
@synthesize plot;

#define WINDOW  150
#define FRAMERATE 25

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    // maybe later on we'll use some intelligent way to determine
    // suitable framerate, but for now we simply hardcode it
    kFramerate = FRAMERATE;

    NSLog(@"loaded real time view");
    
    // For now we simply hardcode the length of the array
    // also, we hardcode the contents
    ecgData = [[NSMutableArray alloc] initWithCapacity:WINDOW];
    for (int i = 0; i < WINDOW; i++) {
        [ecgData addObject:[NSNumber numberWithInt:i]];
    }

    ecgTime = [[NSMutableArray alloc] initWithCapacity:WINDOW];
    for (int i = 0; i < WINDOW; i++) {
        [ecgTime addObject:[NSNumber numberWithInt:i]];
    }
    
	// Do any additional setup after loading the view, typically from a nib.
}

- (void) viewDidAppear:(BOOL) animated
{
    timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / kFramerate
                                                  target:self
                                                selector:@selector(refreshECGPlot:)
                                                userInfo:nil
                                                 repeats:YES];
    [super viewDidAppear: animated];
    [self initPlot];
}

- (void) viewDidDisappear:(BOOL)animated
{
    [timer invalidate];
    [self.hostView.hostedGraph removePlot:plot];
    plot = nil;
    self.hostView.hostedGraph = nil;
    self.hostView = nil;
}

- (NSUInteger) numberOfRecordsForPlot:(CPTPlot *)plot
{
    return WINDOW;
}

- (NSNumber *) numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)idx
{
   // NSLog(@"field %d index %d", fieldEnum, idx);
    
    switch (fieldEnum) {
        case CPTScatterPlotFieldX:
            return [ecgTime objectAtIndex:idx];
            break;
        case CPTScatterPlotFieldY:
            return [ecgData objectAtIndex:idx];
            break;
        default:
            break;
    }

    /*NOTREACHED*/
    return nil;
}

- (void) initPlot
{
    [self configureHost];
    [self configureGraph];
    [self configureScatterPlot];
}

- (void) configureHost
{
    CGRect bounds = self.view.bounds;
    bounds = CGRectMake(bounds.origin.x,
                        bounds.origin.y,
                        bounds.size.width,
                        bounds.size.height - self.tabBarController.tabBar.frame.size.height);
    self.hostView = [[CPTGraphHostingView alloc] initWithFrame:bounds];
    [self.view addSubview:self.hostView];
}

- (void) configureGraph
{
    CPTGraph *graph = [[CPTXYGraph alloc] initWithFrame:self.hostView.bounds];

    graph.plotAreaFrame.paddingTop    = 15.0;
    graph.plotAreaFrame.paddingRight  = 15.0;
    graph.plotAreaFrame.paddingBottom = 125.0;
    graph.plotAreaFrame.paddingLeft   = 5.0;

    CPTXYAxisSet *as = (CPTXYAxisSet *)graph.axisSet;
    as.xAxis.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    as.yAxis.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    as.yAxis.tickLabelDirection = CPTSignPositive;

    CPTXYPlotSpace *ps = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    [ps setXRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInt(0) length:CPTDecimalFromInt(WINDOW)]];
    [ps setYRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInt(0) length:CPTDecimalFromInt(1024)]];

    self.hostView.hostedGraph = graph;
}

- (void) configureScatterPlot
{
    plot = [[CPTScatterPlot alloc] init];

    plot.dataSource = self;
    plot.delegate = self;

    [self.hostView.hostedGraph addPlot:plot];
}

- (void) refreshECGPlot: (NSTimer *) timer
{
    CPTGraph *p = self.hostView.hostedGraph;
    [p reloadData];
}

- (void) setBPM: (uint16_t) bpm
{
    [bpmLabel setText:[NSString stringWithFormat:@"%hd bpm", bpm]];
}

- (void) gotSample:(NSNumber *)sample
{
    //NSLog(@"in real time view controller received a sample: %@", sample);
    [ecgData removeObjectAtIndex:0];
    [ecgData insertObject:sample atIndex:(WINDOW - 1)];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
