//
//  TPLTSecondViewController.m
//  TP
//
//  Created by Dmitri Vorobiev on 27/05/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import "TPLTRealTimeViewController.h"
#import "TPLTDevicesViewController.h"
#import <math.h>
#import <time.h>

@interface TPLTRealTimeViewController ()

@property (nonatomic, strong) CPTGraphHostingView *hostView;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *recordingTimer;
@property (nonatomic) double kFramerate;
@property (weak, nonatomic) IBOutlet UILabel *bpmLabel;
@property (nonatomic, strong) NSMutableArray *ecgData;
@property (nonatomic, strong) NSMutableArray *ecgTime;
@property (nonatomic, strong) CPTScatterPlot *plot;
@property (weak, nonatomic) IBOutlet UIProgressView *recordProgressView;
@property (strong, nonatomic) NSURL *recordFileURL;
@property (strong, nonatomic) NSString *recordFilePath;
@property (nonatomic) NSUInteger recordedSeconds;
@property (weak, nonatomic) IBOutlet UIButton *recordBTN;
@property (nonatomic, strong) NSMutableArray *ecgRecord;
@property (weak, nonatomic) IBOutlet UILabel *recordedLabel;

@property (nonatomic) BOOL recordingInProgress;

// FIXME maybe we will factor this out to another class
@property (nonatomic, strong) NSString *ecgRecordsPath;

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
@synthesize recordingTimer;
@synthesize recordProgressView;
@synthesize recordedSeconds;
@synthesize recordBTN;
@synthesize recordFilePath;
@synthesize recordFileURL;
@synthesize ecgRecord;
@synthesize recordingInProgress;
@synthesize recordedLabel;

// FIXME maybe we will factor this out to another class
@synthesize ecgRecordsPath;

#define WINDOW  150
#define FRAMERATE 20
#define RECORDING_INTERVAL (60*60*2) // seconds

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
        [ecgData addObject:[NSNumber numberWithInt:0]];
    }

    ecgTime = [[NSMutableArray alloc] initWithCapacity:WINDOW];
    for (int i = 0; i < WINDOW; i++) {
        [ecgTime addObject:[NSNumber numberWithInt:i]];
    }
    
    recordProgressView.hidden = YES;
    recordProgressView.progress = 0.0;
    
    [self checkECGRecordsPath];
    
    recordingInProgress = NO;
	// Do any additional setup after loading the view, typically from a nib.
}

// FIXME
// Maybe we will need to factor this out to a new class

- (void) checkECGRecordsPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    ecgRecordsPath = [documentsPath stringByAppendingPathComponent:@"ecg"];
    NSLog(@"ecg path %@", ecgRecordsPath);
    
    // check that the directiry exists and create it if it doesn't
    if (![fileManager fileExistsAtPath:ecgRecordsPath]) {
        NSLog(@"ecg dir doesn't exist, creating it");
        [fileManager createDirectoryAtPath:ecgRecordsPath
               withIntermediateDirectories:NO
                                attributes:nil
                                     error:nil];
    }
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

- (IBAction)startRecordBtnPressed:(id)sender
{
    NSArray *viewContollers = [self.tabBarController viewControllers];
    TPLTDevicesViewController *dvc = [viewContollers objectAtIndex:0];

    if (!dvc.connectedDevice) {
        [[[UIAlertView alloc] initWithTitle:@"No connected sensors"
                                    message:nil
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    } else {
        if (recordingInProgress)
            [self stopRecord];
        else
            [self startRecord];
    }
}

- (void) startRecord
{
    NSLog(@"starting recording");
    
    // progress meter
    recordingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(recordingProgress:)
                                                    userInfo:nil repeats:YES];
    recordedSeconds = 0;
    [recordProgressView setProgress:0.0];
    recordProgressView.hidden = NO;
    
    // label
    recordedLabel.hidden = NO;
    
    // btn
    [recordBTN setTitle:@"Stop" forState:UIControlStateNormal];
    [recordBTN setBackgroundColor:[UIColor redColor]];
    
    // FIXME maybe this will be factored out to a new class
    
    time_t currentTime = time(NULL);
    NSString *recordFileName = [NSString stringWithFormat:@"%ld.log", currentTime];
    recordFilePath = [ecgRecordsPath stringByAppendingPathComponent:recordFileName];
    recordFileURL = [NSURL URLWithString:recordFilePath];
    ecgRecord = [[NSMutableArray alloc] init];
    NSLog(@"current record file path is %@", recordFilePath);
    
    recordingInProgress = YES;
}

- (NSString *)timeFormatted:(int)totalSeconds
{    
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    
    return [NSString stringWithFormat:@"recorded %02d:%02d:%02d", hours, minutes, seconds];
}

- (void) recordingProgress: (NSTimer *) theTimer
{
    recordedSeconds++;

    [recordProgressView setProgress:(float)recordedSeconds / (float)RECORDING_INTERVAL];
    [recordedLabel setText:[self timeFormatted:recordedSeconds]];
    
    if (recordedSeconds == RECORDING_INTERVAL)
        [self stopRecord];
}

- (void) stopRecord
{
    recordingInProgress = NO;
    
    // btn
    [recordBTN setTitle:@"Record" forState:UIControlStateNormal];
    [recordBTN setBackgroundColor:[UIColor greenColor]];
    
    // progress meter
    recordProgressView.hidden = YES;
    [recordingTimer invalidate];
    recordedSeconds = 0;
    
    // label
    recordedLabel.hidden = YES;
    
    NSString *ecgDataToDump = [ecgRecord componentsJoinedByString:@"\n"];
    NSError *error;
    [ecgDataToDump writeToFile:recordFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error)
        NSLog(@"error writing string: %@", error);
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
                        bounds.size.height - self.tabBarController.tabBar.frame.size.height - 100);
    self.hostView = [[CPTGraphHostingView alloc] initWithFrame:bounds];
    [self.view addSubview:self.hostView];
}

- (void) configureGraph
{
    CPTGraph *graph = [[CPTXYGraph alloc] initWithFrame:self.hostView.bounds];

    graph.plotAreaFrame.paddingTop    = 5.0;
    graph.plotAreaFrame.paddingRight  = 10.0;
    graph.plotAreaFrame.paddingBottom = 22.0;
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
    // TEST THE MAX AND MIN
    //NSNumber *max = [ecgData valueForKeyPath:@"@max.intValue"];
    //NSNumber *min = [ecgData valueForKeyPath:@"@min.intValue"];
    //NSLog(@"min is %@ max is %@", min, max);
    // END OF TESTING THE MAX AND MIN
    
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

    if (recordingInProgress) {
        NSString *sampleString = [NSString stringWithFormat:@"%@", sample];
        [ecgRecord addObject:sampleString];
    }
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
