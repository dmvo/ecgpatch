//
//  TPLTRecordViewController.m
//  TP
//
//  Created by Dmitri Vorobiev on 23/06/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import "TPLTRecordViewController.h"

@interface TPLTRecordViewController ()

@property (weak, nonatomic) IBOutlet UILabel *recordName;
@property (nonatomic, strong) CPTGraphHostingView *hostView;
@property (nonatomic, strong) CPTScatterPlot *plot;
@property (nonatomic, strong) NSMutableArray *ecgDataNumbers;

@property (nonatomic) double max;
@property (nonatomic) double min;

@end

@implementation TPLTRecordViewController

@synthesize fileName;
@synthesize hostView;
@synthesize plot;
@synthesize ecgDataNumbers;
@synthesize max, min;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSLog(@"loaded playback view with file name %@", fileName);

    // set up label below the graph
    NSString *s = [fileName stringByDeletingPathExtension];
    NSTimeInterval i = [s doubleValue];
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:i];

    self.recordName.text = [NSDateFormatter localizedStringFromDate:d
                                                          dateStyle:NSDateFormatterLongStyle
                                                          timeStyle:NSDateFormatterMediumStyle];
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                target:self
                                                                                action:@selector(resetAction)];
    self.navigationItem.rightBarButtonItem = editButton;

    // get the data from the file and transform it to the type we need for plotting
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *ecgRecordsPath = [documentsPath stringByAppendingPathComponent:@"ecg"];

    fileName = [ecgRecordsPath stringByAppendingPathComponent:fileName];

    NSString *ecgData = [NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:nil];
    NSArray *ecgDataArray = [ecgData componentsSeparatedByString:@"\n"];

    ecgDataNumbers = [[NSMutableArray alloc] init]; // FIXME maybe we know capacity already now?

    for (NSString *s in ecgDataArray) {
        [ecgDataNumbers addObject:[NSNumber numberWithInteger:[s integerValue]]];
    }

    // calculate default ranges
    max = [[ecgDataNumbers valueForKeyPath:@"@max.intValue"] doubleValue];
    min = [[ecgDataNumbers valueForKeyPath:@"@min.intValue"] doubleValue];

    NSLog(@"max = %f, min = %f", max, min);

    [self initPlot];
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
                        bounds.origin.y + self.navigationController.navigationBar.frame.size.height,
                        bounds.size.width,
                        bounds.size.height - self.tabBarController.tabBar.frame.size.height - 100);
    self.hostView = [[CPTGraphHostingView alloc] initWithFrame:bounds];
    [self.view addSubview:self.hostView];

}

- (void) configureGraph
{
    CPTGraph *graph = [[CPTXYGraph alloc] initWithFrame:self.hostView.bounds];
    
    graph.plotAreaFrame.paddingTop    = 15.0;
    graph.plotAreaFrame.paddingRight  = 10.0;
    graph.plotAreaFrame.paddingBottom = 22.0;
    graph.plotAreaFrame.paddingLeft   = 5.0;
    
    CPTXYAxisSet *as = (CPTXYAxisSet *)graph.axisSet;
    
    as.xAxis.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    as.xAxis.axisConstraints = [CPTConstraints constraintWithLowerOffset:0.0];
    
    as.yAxis.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    as.yAxis.tickLabelDirection = CPTSignPositive;
    as.yAxis.axisConstraints = [CPTConstraints constraintWithLowerOffset:0.0];
    
    CPTXYPlotSpace *ps = (CPTXYPlotSpace *)graph.defaultPlotSpace;

    [ps setXRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInt(0) length:CPTDecimalFromInt(300)]];
    [ps setYRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(min - 0.1 * (max - min)) length:CPTDecimalFromDouble(1.2 * (max - min))]];

    [ps setGlobalXRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0) length:CPTDecimalFromUnsignedInteger([ecgDataNumbers count])]];
    [ps setGlobalYRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0) length:CPTDecimalFromInt(1024)]];
    
    ps.allowsUserInteraction = YES;
    
    self.hostView.hostedGraph = graph;
}

- (void) resetAction
{
    CPTXYPlotSpace *ps = (CPTXYPlotSpace *)self.hostView.hostedGraph.defaultPlotSpace;
    [ps setXRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInt(0) length:CPTDecimalFromInt(300)]];
    [ps setYRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(min - 0.1 * (max - min)) length:CPTDecimalFromDouble(1.2 * (max - min))]];
}

- (void) configureScatterPlot
{
    plot = [[CPTScatterPlot alloc] init];
    
    plot.dataSource = self;
    plot.delegate = self;
    
    [self.hostView.hostedGraph addPlot:plot];
}

- (NSUInteger) numberOfRecordsForPlot:(CPTPlot *)plot
{
    return [ecgDataNumbers count];
}

- (NSNumber *) numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)idx
{
    switch (fieldEnum) {
        case CPTScatterPlotFieldX:
            return [NSNumber numberWithUnsignedInteger:idx]; // milliseconds
        case CPTScatterPlotFieldY:
            return [ecgDataNumbers objectAtIndex:idx];
        default:
            break;
    }
    
    return nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
