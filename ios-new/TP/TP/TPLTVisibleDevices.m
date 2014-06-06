//
//  TPLTVisibleDevices.m
//  TP
//
//  Created by Dmitri Vorobiev on 28/05/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import "TPLTVisibleDevices.h"

@interface TPLTVisibleDevices ()

@property (strong, nonatomic) CBCentralManager *centralManager;

@end

@implementation TPLTVisibleDevices

-(instancetype) init {

    self = [super init];
    
    if (self) {
        
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
    }
    
    return self;
}

- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"%@", central);
    
    // scan for available devices
    [_centralManager scanForPeripheralsWithServices:nil options:nil];
}

- (void) centralManager:(CBCentralManager *)central
  didDiscoverPeripheral:(CBPeripheral *)peripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)RSSI
{
    NSLog(@"discovered peripheral: %@ RSSI %@", peripheral, RSSI);
    [self.delegate deviceDetected: peripheral];
}

- (void) stopScan
{
    [_centralManager stopScan];
}

- (void) connectToPeripheral:(CBPeripheral *)peripheral
{
    [_centralManager connectPeripheral:peripheral options:nil];
}

- (void) disconnectFromPeripheral:(CBPeripheral *)peripheral
{
    [_centralManager cancelPeripheralConnection:peripheral];
}

-(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connected to %@", peripheral);
    [self.delegate deviceConnected: peripheral];
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@", peripheral);
}

- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self.delegate deviceDisconnected:peripheral];
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    bool hasHeartRate = false;
    bool hasBattery = false;
    CBService *heartRateService, *batteryService;
    
    for (CBService *service in peripheral.services) {

        if ([service.UUID isEqual:[CBUUID UUIDWithString:@"0x180D"]]) {
            hasHeartRate = true;
            heartRateService = service;
        }
        
        if ([service.UUID isEqual:[CBUUID UUIDWithString:@"0x180F"]]) {
            hasBattery = true;
            batteryService = service;
        }
    }
    
    if (!hasHeartRate) {
        // no heart rate, not our device, show alert
        
        // clean the shit up and go back scanning
        
        return;
    } else {
        [peripheral discoverCharacteristics:nil forService:heartRateService];
    }
    
    if (batteryService) {
        [peripheral discoverCharacteristics:nil forService:batteryService];
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for (CBCharacteristic *c in service.characteristics) {
        NSLog(@"discovered %@", c);
        
        if ([c.UUID isEqual:[CBUUID UUIDWithString:@"0x2A37"]]) {
            NSLog(@"Found heart rate measurement characteristic");
            [peripheral setNotifyValue:YES forCharacteristic:c];
        }
        
        if ([c.UUID isEqual:[CBUUID UUIDWithString:@"0x2A38"]]) {
            NSLog(@"Found body sensor location characteristic");
            
            // show it somewhere
        }
        
        if ([c.UUID isEqual:[CBUUID UUIDWithString:@"0x2A19"]]) {
            NSLog(@"Found battery level characteristic");
            
            // subsribe to it
        }
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@", [error localizedDescription]);
        return;
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    //NSLog(@"%@", characteristic.value);
}
@end
