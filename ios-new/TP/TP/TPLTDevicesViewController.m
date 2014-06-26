//
//  TPLTFirstViewController.m
//  TP
//
//  Created by Dmitri Vorobiev on 27/05/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import "TPLTDevicesViewController.h"
#import "TPLTRealTimeViewController.h"
#import "TPLTVisibleDevices.h"

@interface TPLTDevicesViewController ()

@property (strong, nonatomic) TPLTVisibleDevices *visibleDevices;
@property (strong, nonatomic) NSMutableArray *devicesFound;
@property (weak, nonatomic) IBOutlet UIPickerView *devicesPickerView;
@property (nonatomic) NSInteger deviceToConnect;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *connectionInProgressActivity;
@property (strong) NSTimer *connectionTimedOutTimer;
@property (weak, nonatomic) IBOutlet UILabel *whereWeAreConnectedLabel;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;

@end

@implementation TPLTDevicesViewController

- (void) restartScanning
{
    self.connectedDevice = nil;
    _visibleDevices = [[TPLTVisibleDevices alloc] init];
    _visibleDevices.delegateVisibleDevices = self;
    self.deviceToConnect = 0;
    self.devicesFound = [[NSMutableArray alloc] init];
    [self.devicesPickerView reloadAllComponents];
    [self.devicesPickerView setUserInteractionEnabled:YES];
    [self.whereWeAreConnectedLabel setText:@"Not connected"];
    [self.connectButton setBackgroundColor:[UIColor greenColor]];
    [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    [self restartScanning];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger) numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger) pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    NSLog(@"Picker asked for the number of rows, ");
    if ([self.devicesFound count]) {
        return [self.devicesFound count];
    } else {
        return 1;
    }
}

- (void) deviceDetected: (CBPeripheral *) peripheral
{    
    [self.devicesFound addObject:peripheral];
    [self.devicesPickerView reloadAllComponents];
}

- (void) pickerView:(UIPickerView *)pickerView
       didSelectRow:(NSInteger)row
        inComponent:(NSInteger)component
{
    NSLog(@"selected row %d", row);
    self.deviceToConnect = row;
}

- (IBAction) connectButtonPressed:(id)sender
{
    if (self.connectedDevice) {
        
        [_visibleDevices disconnectFromPeripheral:self.connectedDevice];

    } else if ([self.devicesFound count]) {
        CBPeripheral *p = [self.devicesFound objectAtIndex:self.deviceToConnect];
        
        [_visibleDevices stopScan];
        [_visibleDevices connectToPeripheral:p];
        [self.connectionInProgressActivity startAnimating];
        [self.connectionTimedOutTimer invalidate];
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                          target:self
                                                        selector:@selector(connectionTimedOut:)
                                                        userInfo:nil repeats:NO];
        self.connectionTimedOutTimer = timer;
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No sensors available"
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void) connectionTimedOut: (NSTimer *) timer
{
    [self.connectionTimedOutTimer invalidate];
    [self.connectionInProgressActivity stopAnimating];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection timed out"
                                                    message:nil
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    [self restartScanning];
}

- (void) deviceConnected: (CBPeripheral *) peripheral
{
    [self.connectionTimedOutTimer invalidate];
    [self.connectionInProgressActivity stopAnimating];
    [self.whereWeAreConnectedLabel setText:@"Connected"];
    [self.devicesPickerView setUserInteractionEnabled:NO];
    [self.connectButton setBackgroundColor:[UIColor redColor]];
    [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
    self.connectedDevice = peripheral;
}

- (void) deviceDisconnected: (CBPeripheral *)peripheral
{
    NSArray *viewContollers = [self.tabBarController viewControllers];
    TPLTRealTimeViewController *rtvc = [viewContollers objectAtIndex:1];
    
    [rtvc stopRecord];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection lost"
                                                    message:[NSString stringWithFormat:@"Sensor %@ disconnected", peripheral.name]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    [self restartScanning];
}

- (NSString *) pickerView:(UIPickerView *)pickerView
              titleForRow:(NSInteger)row
             forComponent:(NSInteger)component
{
    if ([self.devicesFound count]) {
        NSLog(@" setting title for row %d", row);
        CBPeripheral *p = [self.devicesFound objectAtIndex:row];
        return p.name;
    } else {
        return @"No sensors found";
    }
}

- (void) bpmReceived:(uint16_t)bpm
{
    NSArray *viewContollers = [self.tabBarController viewControllers];
    TPLTRealTimeViewController *rtvc = [viewContollers objectAtIndex:1];
    
    [rtvc setBPM: bpm];
}

- (void) sampleReceived: (NSNumber *)sample
{
    NSArray *viewContollers = [self.tabBarController viewControllers];
    TPLTRealTimeViewController *rtvc = [viewContollers objectAtIndex:1];

    [rtvc gotSample:sample];
}
@end
