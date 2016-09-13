//
//  AppDelegate.h
//  BleOTADemo
//
//  Created by JustBill on 16/9/13.
//  Copyright © 2016年 邢谢飞. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic ,strong) CBPeripheral *peripheral;

@property (nonatomic ,copy) NSString *Globeuuidstr;

@end

