//
//  ViewController.m
//  ECG
//
//  Created by Joni Lampio on 11/11/13.
//  Copyright (c) 2013 Metropolia. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "BackgroundLayer.h"
#include "time.h"

static const double kFrameRate = 25.0;  // frames per second

static const NSUInteger kMaxDataPoints = 200;
static NSString *const kPlotIdentifier = @"Data Source Plot";

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate, CPTPlotDataSource>
@property (retain, nonatomic) IBOutlet UILabel *statusLabel;
@property (retain, nonatomic) IBOutlet CPTGraphHostingView *graphView;
@property (retain, nonatomic) IBOutlet UILabel *bpmLabel;
@property (retain, nonatomic) IBOutlet UILabel *batLabel;
@property (retain, nonatomic) IBOutlet UIButton *startButton;
@property (retain, nonatomic) IBOutlet UIImageView *metropoliaLogo;
@property (retain, nonatomic) IBOutlet UIImageView *tutLogo;
@property (retain, nonatomic) CPTGraph *graph;
@property (retain, nonatomic) CPTScatterPlot *lineplot;
@property (retain, nonatomic) NSMutableArray *hrmPlotData;
@property NSUInteger currentIndex;
@property (nonatomic, strong) NSMutableArray *heartRateMonitors;
@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property NSTimer *updateTimer;
@property NSTimer *dataTimer;
@property NSUInteger cState;
@property NSUInteger y_min;
@property NSUInteger y_max;
@end

typedef enum {
    DISCONNECTED,
    CONNECTING,
    CONNECTED
} connection_state;

@implementation ViewController
@synthesize graphView, graph, lineplot, hrmPlotData, currentIndex, statusLabel, bpmLabel, batLabel, updateTimer, dataTimer, startButton, cState, peripheral, manager, y_max, y_min, metropoliaLogo, tutLogo;

- (IBAction)buttonListener
{
    if (cState != DISCONNECTED)
        [self disconnect: true];
    else
        [self connect];
}

- (void) disconnect: (BOOL) didUserDisconnect {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [updateTimer invalidate];
    updateTimer = nil;
    if (cState == CONNECTING)
        [self stopScan];
    if (peripheral != nil)
        [manager cancelPeripheralConnection:peripheral];
    cState = DISCONNECTED;
    
    metropoliaLogo.alpha = 1.0;
    tutLogo.alpha = 1.0;
    bpmLabel.text = @"0 bpm";
    [startButton setImage:[UIImage imageNamed:@"Pysty_Start.png"] forState:UIControlStateNormal];
    [startButton setTitle:@"Start" forState:UIControlStateNormal];
    
    time_t result = time(NULL);
    NSString * tmp;
    if (didUserDisconnect)
        tmp = [NSString stringWithFormat: @"Disconnected\n%s", asctime(localtime(&result))];
    else
        tmp = [NSString stringWithFormat: @"Connection lost\n%s", asctime(localtime(&result))];
    
    statusLabel.text = tmp;
}

- (void) connect {
    [startButton setImage:[UIImage imageNamed:@"Pysty_stop.png"] forState:UIControlStateNormal];
    [startButton setTitle:@"Stop" forState:UIControlStateNormal];
    statusLabel.text = @"Connecting";
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    cState = CONNECTING;
    self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    [self startScan];
}

- (void) connected {
    metropoliaLogo.alpha = 0.1;
    tutLogo.alpha = 0.1;
    cState = CONNECTED;
    y_min = 1024;
    y_max = 0;
    updateTimer = [NSTimer scheduledTimerWithTimeInterval: 1/kFrameRate target:self selector:@selector(refreshGraph) userInfo:nil repeats:YES];
    //[startButton setTitle:@"Stop" forState:UIControlStateNormal];
    NSString *tmp = [NSString stringWithFormat:@"Connected to %@", [peripheral name]];
    statusLabel.text = tmp;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    if ((toInterfaceOrientation == UIInterfaceOrientationPortrait) || (toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)) {

        CGRect rect = self.graphView.frame;
        rect.origin.y = 88;
        rect.origin.x = 0;
        rect.size.width = 320;
        rect.size.height = 200;
        self.graphView.frame = rect;
        
        rect = self.statusLabel.frame;
        rect.origin.y = 20;
        rect.origin.x = 0;
        rect.size.width = 320;
        rect.size.height = 60;
        self.statusLabel.frame = rect;
        statusLabel.textAlignment = NSTextAlignmentCenter;
        statusLabel.font = [statusLabel.font fontWithSize:17];
        
        rect = self.bpmLabel.frame;
        rect.origin.y = 330;
        rect.origin.x = 20;
        rect.size.width = 100;
        rect.size.height = 30;
        self.bpmLabel.frame = rect;
        
        rect = self.startButton.frame;
        rect.origin.y = 479;
        rect.origin.x = 73;
        rect.size.width = 174;
        rect.size.height = 69;
        self.startButton.frame = rect;
        
        rect = self.tutLogo.frame;
        rect.origin.y = 177;
        rect.origin.x = 20;
        rect.size.width = 280;
        rect.size.height = 91;
        self.tutLogo.frame = rect;
        
        rect = self.metropoliaLogo.frame;
        rect.origin.y = 88;
        rect.origin.x = 20;
        rect.size.width = 280;
        rect.size.height = 106;
        self.metropoliaLogo.frame = rect;
    }
    
    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        
        CGRect rect = self.graphView.frame;
        rect.origin.y = 0;
        rect.size.width = [[UIScreen mainScreen]bounds].size.height;
        rect.size.height = 250;
        self.graphView.frame = rect;
        
        rect = self.statusLabel.frame;
        rect.origin.y = [[UIScreen mainScreen]bounds].size.width - 55;
        rect.origin.x = 5;
        self.statusLabel.frame = rect;
        statusLabel.textAlignment = NSTextAlignmentLeft;
        statusLabel.font = [statusLabel.font fontWithSize:15];
        
        rect = self.bpmLabel.frame;
        rect.origin.y = 10;
        rect.origin.x = [[UIScreen mainScreen]bounds].size.height - 200;
        self.bpmLabel.frame = rect;
        
        rect = self.startButton.frame;
        rect.size.height = 40;
        rect.size.width = 90;
        rect.origin.y = ([[UIScreen mainScreen]bounds].size.width - 45);
        rect.origin.x = ([[UIScreen mainScreen]bounds].size.height / 2) - (rect.size.width / 2);
        self.startButton.frame = rect;
        
        rect = self.tutLogo.frame;
        rect.origin.y = 80;
        rect.origin.x = 250;
        self.tutLogo.frame = rect;
        
        rect = self.metropoliaLogo.frame;
        rect.origin.y = 80;
        rect.origin.x = 0;
        self.metropoliaLogo.frame = rect;
    }
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft
        || self.interfaceOrientation ==UIInterfaceOrientationLandscapeRight) {
        CAGradientLayer * bgLayer = [BackgroundLayer blueGradient: 0.7 secondstop:1.0];
        bgLayer.frame = self.view.bounds;
        [self.view.layer replaceSublayer:[[self.view.layer sublayers] objectAtIndex:0] with:bgLayer];
        bpmLabel.alpha = 0.5;
    } else if (self.interfaceOrientation == UIInterfaceOrientationPortrait) {
        CAGradientLayer * bgLayer = [BackgroundLayer blueGradient: 0.5 secondstop:1.0];
        bgLayer.frame = self.view.bounds;
        [self.view.layer replaceSublayer:[[self.view.layer sublayers] objectAtIndex:0] with:bgLayer];
        bpmLabel.alpha = 1.0;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    CAGradientLayer * bgLayer = [BackgroundLayer blueGradient:0.5 secondstop:1.0];
    bgLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:bgLayer atIndex:0];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    startButton.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    hrmPlotData = [[NSMutableArray arrayWithCapacity:kMaxDataPoints] retain];

    CGRect bounds = graphView.bounds;
    graph = [[[CPTXYGraph alloc] initWithFrame:bounds] autorelease];
    graphView.hostedGraph = graph;
    graphView.collapsesLayers = NO;
    
    graph.plotAreaFrame.paddingTop    = 0.0;
    graph.plotAreaFrame.paddingRight  = 0.0;
    graph.plotAreaFrame.paddingBottom = 0.0;
    graph.plotAreaFrame.paddingLeft   = 0.0;
    graph.plotAreaFrame.masksToBorder = NO;
    graph.paddingTop = graph.paddingBottom = graph.paddingLeft = graph.paddingRight = 0;
    
    CPTMutableLineStyle *borderLineStyle = [CPTMutableLineStyle lineStyle];
    borderLineStyle.lineWidth = 1.0;
    borderLineStyle.lineColor = [CPTColor blackColor];
    graph.plotAreaFrame.borderLineStyle = borderLineStyle;
    
    // Grid line styles
    CPTMutableLineStyle *majorGridLineStyle = [CPTMutableLineStyle lineStyle];
    majorGridLineStyle.lineWidth = 0.75;
    majorGridLineStyle.lineColor = [[CPTColor colorWithGenericGray:0.2] colorWithAlphaComponent:0.75];
    
    CPTMutableLineStyle *minorGridLineStyle = [CPTMutableLineStyle lineStyle];
    minorGridLineStyle.lineWidth = 0.25;
    minorGridLineStyle.lineColor = [[CPTColor colorWithGenericGray:0.1] colorWithAlphaComponent:0.1];
    
    // Axes
    // X axis
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x          = axisSet.xAxis;
    x.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
    x.orthogonalCoordinateDecimal = CPTDecimalFromUnsignedInteger(0);
    x.majorGridLineStyle          = majorGridLineStyle;
    x.minorGridLineStyle          = minorGridLineStyle;
    x.minorTicksPerInterval       = 9;
    //x.title                       = @"X Axis";
    //x.titleOffset                 = 35.0;
    x.axisConstraints             = [CPTConstraints constraintWithLowerOffset:0.0];
    NSNumberFormatter *labelFormatter =[[NSNumberFormatter alloc] init];
    //labelFormatter.numberStyle = NSNumberFormatterNoStyle;
    labelFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    x.labelFormatter           = labelFormatter;

    // Y axis
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
    y.orthogonalCoordinateDecimal = CPTDecimalFromUnsignedInteger(0);
    y.majorGridLineStyle          = majorGridLineStyle;
    y.minorGridLineStyle          = minorGridLineStyle;
    y.minorTicksPerInterval       = 3;
    y.labelOffset                 = 0.0;
    //y.labelFormatter = labelFormatter;
    y.labelFormatter = nil;
    //y.title                       = @"Y Axis";
    //y.titleOffset                 = 30.0;
    y.axisConstraints             = [CPTConstraints constraintWithLowerOffset:0.0];
    
    [labelFormatter release];
    
    // Rotate the labels by 45 degrees, just to show it can be done.
    //x.labelRotation = M_PI * 0.25;
    
    // Create the plot
    CPTScatterPlot *dataSourceLinePlot = [[[CPTScatterPlot alloc] init] autorelease];
    dataSourceLinePlot.identifier     = kPlotIdentifier;
    dataSourceLinePlot.cachePrecision = CPTPlotCachePrecisionDouble;
    
    CPTMutableLineStyle *lineStyle = [[dataSourceLinePlot.dataLineStyle mutableCopy] autorelease];
    lineStyle.lineWidth              = 2.0;
    lineStyle.lineColor              = [CPTColor blackColor];
    dataSourceLinePlot.dataLineStyle = lineStyle;
    
    dataSourceLinePlot.dataSource = self;
    [graph addPlot:dataSourceLinePlot];
    
    // Plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(0) length:CPTDecimalFromUnsignedInteger(kMaxDataPoints - 2)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(0) length:CPTDecimalFromUnsignedInteger(1024)];
    
    self.heartRateMonitors = [NSMutableArray array];
    cState = DISCONNECTED;
}

- (void)refreshGraph
{
    static int prev_y_max = 0, prev_y_min = 1024;
    bool scaleY = false;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    NSUInteger location       = (currentIndex >= kMaxDataPoints ? currentIndex - kMaxDataPoints + 2 : 0);
    CPTPlotRange *newXRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(location) length:CPTDecimalFromUnsignedInteger(kMaxDataPoints - 2)];
    
    if (y_max == 0 && y_min == 1024) {
        prev_y_min = 1024;
        prev_y_max = 0;
    }
    
    if (y_max > prev_y_max) {
        scaleY = true;
        prev_y_max = y_max;
    }
    if (y_min < prev_y_min) {
        scaleY = true;
        prev_y_min = y_min;
    }
    
    if (scaleY) {
        CPTPlotRange *newYRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(prev_y_min) length:CPTDecimalFromUnsignedInteger(prev_y_max - prev_y_min)];
        plotSpace.yRange = newYRange;
    }
    
    plotSpace.xRange = newXRange;
    [graph reloadData];
}

- (void)generateData
{
    [hrmPlotData removeAllObjects];
    currentIndex = 0;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return [hrmPlotData count];
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    NSNumber *num = nil;
    
    switch ( fieldEnum ) {
        case CPTScatterPlotFieldX:
            num = [NSNumber numberWithUnsignedInteger:index + currentIndex - hrmPlotData.count];
            break;
            
        case CPTScatterPlotFieldY:
            num = [hrmPlotData objectAtIndex:index];
            break;
            
        default:
            break;
    }
    
    return num;
}

-(void)newData: (NSNumber*) bpm
{
    CPTGraph *theGraph = graph;
    CPTPlot *thePlot   = [theGraph plotWithIdentifier:kPlotIdentifier];
    
    if (thePlot) {
        if (hrmPlotData.count >= kMaxDataPoints)
            [hrmPlotData removeObjectAtIndex:0];
        
        currentIndex++;
        [hrmPlotData addObject: bpm];
    }
}

#pragma mark - Start/Stop Scan methods

// Use CBCentralManager to check whether the current platform/hardware supports Bluetooth LE.
- (BOOL) isLECapableHardware
{
    NSString * state = nil;
    switch ([self.manager state]) {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;
    }
    NSLog(@"Central manager state: %@", state);
    return FALSE;
}

// Request CBCentralManager to scan for heart rate peripherals using service UUID 0x180D
- (void) startScan
{
    [self.manager scanForPeripheralsWithServices:[NSArray arrayWithObjects:  [CBUUID UUIDWithString:@"180D"],
                                                                            [CBUUID UUIDWithString:@"180F"], nil]
                                                    options:nil];
}

// Request CBCentralManager to stop scanning for heart rate peripherals
- (void) stopScan
{
    [self.manager stopScan];
}

#pragma mark - CBCentralManager delegate methods

// Invoked when the central manager's state is updated.
- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self isLECapableHardware];
}

// Invoked when the central discovers heart rate peripheral while scanning.
- (void) centralManager:(CBCentralManager *)central
  didDiscoverPeripheral:(CBPeripheral *)aPeripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)RSSI
{
    // Retrieve already known devices
    [self.manager retrievePeripherals:[NSArray arrayWithObject:(id)aPeripheral.UUID]];
}

// Invoked when the central manager retrieves the list of known peripherals.
// Automatically connect to first known peripheral
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    NSLog(@"Retrieved peripheral: %u - %@", [peripherals count], peripherals);
    [self stopScan];
    // If there are any known devices, automatically connect to it.
    if([peripherals count] >= 1) {
        self.peripheral = [peripherals objectAtIndex:0];
        [self.manager connectPeripheral:self.peripheral
                                options:[NSDictionary dictionaryWithObject:
                                         [NSNumber numberWithBool:YES]
                                                                    forKey:
                                         CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    }
}

// Invoked when a connection is succesfully created with the peripheral.
// Discover available services on the peripheral
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    NSLog(@"connected");
    [self connected];

    [aPeripheral setDelegate:self];
    [aPeripheral discoverServices:nil];
}

// Invoked when an existing connection with the peripheral is torn down.
// Reset local variables
- (void) centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)aPeripheral
                  error:(NSError *)error
{
    if (error)
    [self disconnect:false];
    else
    [self disconnect:true];
    
    if (self.peripheral) {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

// Invoked when the central manager fails to create a connection with the peripheral.
- (void) centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)aPeripheral
                  error:(NSError *)error
{
    [self disconnect:false];
    
    NSLog(@"Fail to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    if (self.peripheral) {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

#pragma mark - CBPeripheral delegate methods

// Invoked upon completion of a -[discoverServices:] request.
// Discover available characteristics on interested services
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error
{
    for (CBService *aService in aPeripheral.services) {
        NSLog(@"Service found with UUID: %@", aService.UUID);
        
        /* Heart Rate Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180D"]]) {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }

        /* Battery service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180F"]]) {
            [aPeripheral discoverCharacteristics:nil forService:aService];
            NSLog(@"found battery service");
        }
    }
}

// Invoked upon completion of a -[discoverCharacteristics:forService:] request.
// Perform appropriate operations on interested characteristics
- (void) peripheral:(CBPeripheral *)aPeripheral
didDiscoverCharacteristicsForService:(CBService *)service
              error:(NSError *)error
{
    if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180D"]]) {
        for (CBCharacteristic *aChar in service.characteristics) {
            // Set notification on heart rate measurement
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]) {
                [self.peripheral setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found a Heart Rate Measurement Characteristic");
            }

            // Read body sensor location
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]]) {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Body Sensor Location Characteristic");
            }
        }
    }

    if ([service.UUID isEqual:[CBUUID UUIDWithString:@"180F"]]) {
        for (CBCharacteristic *aChar in service.characteristics) {

            // Read battery level
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A19"]]) {
                [self.peripheral setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found a Battery Level Characteristic");
            }

        }
    }
}

// Update UI with heart rate data received from device
- (void) updateWithHRMData:(NSData *)data
{
    const uint8_t *reportData = [data bytes];
    uint16_t bpm;
    uint16_t testi = 0;
    uint8_t bpm_length;
    
    if ((reportData[0] & 0x01) == 0) {
        // uint8 bpm
        bpm = reportData[1];
        bpm_length = 1;

    } else {
        // uint16 bpm
        bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));
        bpm_length = 2;
    }
    if (bpm > y_max)
        y_max = bpm;
    if (bpm < y_min)
        y_min = bpm;
    
    if ((reportData[0] & 0x10) == 0x10) {
        testi = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1 + bpm_length]));
                NSString *tmp = [NSString stringWithFormat:@"%i bpm", testi];
                bpmLabel.text = tmp;
    }
    
    NSNumber *sample = [NSNumber numberWithUnsignedInt:bpm];
    
    [self newData: sample];
}

// Invoked upon completion of a -[readValueForCharacteristic:] request
// or on the reception of a notification/indication.
- (void) peripheral:(CBPeripheral *)aPeripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
              error:(NSError *)error
{
    // Updated value for heart rate measurement received
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]) {
        if(characteristic.value || !error) {
            //NSLog(@"received value: %@", characteristic.value);
            // Update UI with heart rate data
            [self updateWithHRMData:characteristic.value];
        }
    }
    // Value for body sensor location received
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]]) {
        NSData * updatedValue = characteristic.value;
        uint8_t* dataPointer = (uint8_t*)[updatedValue bytes];
        if (dataPointer) {
            uint8_t location = dataPointer[0];
            NSString*  locationString;
            switch (location) {
                case 0:
                    locationString = @"Other";
                    break;
                case 1:
                    locationString = @"Chest";
                    break;
                case 2:
                    locationString = @"Wrist";
                    break;
                case 3:
                    locationString = @"Finger";
                    break;
                case 4:
                    locationString = @"Hand";
                    break;
                case 5:
                    locationString = @"Ear Lobe";
                    break;
                case 6:
                    locationString = @"Foot";
                    break;
                default:
                    locationString = @"Reserved";
                    break;
            }
            NSLog(@"Body Sensor Location = %@ (%d)", locationString, location);
        }
    }
    // Battery level value received
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A19"]]) {
        NSLog(@"Received battery level %@", characteristic.value);
        uint8_t *batval = (uint8_t *)[characteristic.value bytes];
        NSLog(@"battery level is %d", batval[0]);
        NSString *tmp = [NSString stringWithFormat:@"%i %%", batval[0]];
        NSLog(@"%@", tmp);
        batLabel.text = tmp;
    }
}
- (void)dealloc {
    [bpmLabel release];
    [statusLabel release];
    [startButton release];
    [metropoliaLogo release];
    [tutLogo release];
    [batLabel release];
    [super dealloc];
}
@end
