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
    [_centralManager scanForPeripheralsWithServices:nil options:nil];
}

- (void) centralManager:(CBCentralManager *)central
  didDiscoverPeripheral:(CBPeripheral *)peripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)RSSI
{
    NSLog(@"discovered peripheral: %@ RSSI %@", peripheral, RSSI);
    [self.delegateVisibleDevices deviceDetected: peripheral];
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
    [self.delegateVisibleDevices deviceConnected: peripheral];
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@", peripheral);
}

- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [self.delegateVisibleDevices deviceDisconnected:peripheral];
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
    // This is SHIT SHIT SHIT: we blatantly misuse the Heart Rate profile,
    // because it is intended to transmit BPM data, not samples in real time.
    //
    // All this shit needs to be rewritten completely for the product:
    //      o use BTLE alert profile to start/stop real-time data
    //      o use UART profile from Nordic to send/receive real-time data
    //      o use the HR profile exactly for what it is intended for:
    //        fucking BPM values, AND NOTHING ELSE!!!!!11111

    NSData *data = (NSData *) characteristic.value;
    
    const uint8_t *reportedData = [data bytes];
    uint8_t bpm_length;
    uint16_t bpm;

    if ((reportedData[0] & 0x01) == 0) {
        // uint8 bpm
        bpm = reportedData[1];
        bpm_length = 1;
        
    } else {
        // uint16 bpm
        bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportedData[1]));
        bpm_length = 2;
    }
    
    if ((reportedData[0] & 0x10) == 0x10) {
        uint16_t tmp_bpm;
        
        tmp_bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportedData[1 + bpm_length]));

        // Tell that we received a new BPM value to the
        // view controller that knows about us. That view controller
        // will then update some lebel somewhere, most probably NOT
        // on itself.
        
        [self.delegateVisibleDevices bpmReceived:tmp_bpm];
    }
    
    NSNumber *sample = [NSNumber numberWithUnsignedInt:bpm];
    [self.delegateVisibleDevices sampleReceived:sample];
}
@end
