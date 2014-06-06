//
//  TPLTVisibleDevices.h
//  TP
//
//  Created by Dmitri Vorobiev on 28/05/14.
//  Copyright (c) 2014 Electria. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

// Protocol definition starts here
@protocol TPLTVisibleDesicesDelegate <NSObject>
@required

// These methods will be implemented in another class and called from
// an instance of that another class whenever a device is found.
// Apple sucks big nigger stinky dick for the shitty terminology.
- (void) deviceDetected: (CBPeripheral *) peripheral;
- (void) deviceConnected: (CBPeripheral *) peripheral;
- (void) deviceDisconnected: (CBPeripheral *) peripheral;

@end
// Protocol definition ends here

@interface TPLTVisibleDevices : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

{
    // Delegate to whom to respond back
    id <TPLTVisibleDesicesDelegate> _delegate;
}
@property (strong, nonatomic) id delegate;

- (void) stopScan;
- (void) connectToPeripheral:(CBPeripheral *) peripheral;
- (void) disconnectFromPeripheral:(CBPeripheral *)peripheral;

@end
