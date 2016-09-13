//
//  ViewController.m
//  BleOTADemo
//
//  Created by JustBill on 16/9/13.
//  Copyright © 2016年 邢谢飞. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "NSStringTool.h"
#import "AppDelegate.h"

#define kServiceUUID @"FFF0"
#define kServiceUUID2 @"FFF1"

@interface ViewController () <CBCentralManagerDelegate ,CBPeripheralDelegate >
{
    BOOL ncharactexist;
    BOOL kCharactexist;
    BOOL pairconnectde;
    BOOL devicepairornot;
    NSInteger allData;
    NSString *curversion;
    NSData *headData;
    CBCentralManager *centralManager;
}

@property (nonatomic ,strong) NSMutableArray *arr;

@property (nonatomic ,strong) NSMutableData *file;

@property (nonatomic ,assign) NSInteger length;

@property (nonatomic ,assign) NSInteger num;

@property (nonatomic ,strong) NSMutableArray *dataArr;

@property (nonatomic ,strong) CBPeripheral *peripheral;

@end



@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//升级
-(void)updateOTAstart
{
    ncharactexist = NO;
    kCharactexist = NO;
    self.arr=[NSMutableArray array];
    
    self.file=[[NSMutableData alloc]init];
    
    //    NSString *path=  [[NSBundle mainBundle]pathForResource:@"w3.bin" ofType:nil];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString* path = [documentsDirectory stringByAppendingPathComponent:@"upgrade.bin"];
    
    self.file=[NSMutableData  dataWithContentsOfFile:path];
    self.length=self.file.length;
    self.num=self.length%16==0?self.length/16:self.length/16+1;//求发送包数，每包数据16字节
    allData = self.num + 1;//zwl
    
    if (self.length%16!=0) {
        int count=self.length%16;
        
        NSData *data=[self nslogData:@"F" withInt:32-(count*2)];//最后一包，不满16字节补F
        [self.file appendData:data];
        
        self.length=self.file.length;
        NSLog(@"self.length:%lu",(unsigned long)self.length);
        
    }
    self.dataArr=[NSMutableArray array];
    //拼接发送的第一条数据包
    NSString *string=@"A600";
    //软件版本号，日期等的拼接,从服务器端获取
    NSArray *versionInfoArray = [curversion componentsSeparatedByString:@"_"];
    if(versionInfoArray.count >3)
    {
        NSString *datastr = versionInfoArray[2];
        NSInteger year = [[datastr substringWithRange:NSMakeRange(0,4)] integerValue];
        NSInteger month= [[datastr substringWithRange:NSMakeRange(4,2)] integerValue];
        NSString *strmonth = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%02lx",(long)month]];
        
        NSInteger day  = [[datastr substringWithRange:NSMakeRange(6,2)] integerValue];
        NSString *strday = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%02lx",(long)day]];
        
        NSString *versionstr = versionInfoArray[3];
        NSString *finalVersion;
        if(versionstr.length > 1)
        {
            versionstr = [versionstr substringFromIndex:1];
            NSArray *versionArray = [versionstr componentsSeparatedByString:@"."];
            if(versionArray.count>1)
            {
                NSInteger ver1 = [versionArray[0] integerValue];
                NSString *str1 = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%01lx",(long)ver1]];
                NSInteger ver2 = [versionArray[1] integerValue];
                NSString *str2 = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%01lx",(long)ver2]];
                finalVersion = [str1 stringByAppendingString:str2];
            }
        }
        
        NSInteger yearL=year & 0xFF;
        NSString *stryearL = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%02lx",(long)yearL]];
        
        
        NSInteger yearH=year >> 8;
        NSString *stryearH = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%02lx",(long)yearH]];
        //要发送的包总数self.num
        NSInteger numL = self.num & 0xFF;
        NSString *strnumL = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%02lx",(long)numL]];
        
        NSInteger numH=self.num >> 8;
        NSString *strnumH = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%02lx",(long)numH]];
        
        
        string = [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@",string,finalVersion,stryearL,stryearH,strmonth,strday,strnumL,strnumH];
        headData= [NSStringTool convertHexStrToData:string];
    }
    
    //头
    NSString *str=@"A601";
    [self addMidData:str withDataArr:_dataArr];
    
    centralManager = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
    //已经被系统或者其他APP连接上的设备数组
    NSArray *arr = [centralManager retrieveConnectedPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID],[CBUUID UUIDWithString:kServiceUUID2]]];
    
    if(arr.count>0)
    {
        pairconnectde = YES;
        for (CBPeripheral* peripheral in arr)
        {
            if (peripheral != nil)
            {
                devicepairornot = YES;
                peripheral.delegate = self;
                self.peripheral = peripheral;
                [centralManager connectPeripheral:self.peripheral options:nil];
                //[centralManager connectPeripheral:self.peripheral options:@{CBConnectPeripheralOptionNotifyOnConnectionKey : @YES}];
                [AppDelegate sharedAppDelegate].peripheral = peripheral;//zwl
                [AppDelegate sharedAppDelegate].Globeuuidstr = [[AppDelegate sharedAppDelegate].peripheral.identifier UUIDString];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:VDBlueToothSearchSuccessNotification object:nil];
            }
        }
    }
    else
    {
        //扫描设备
        pairconnectde = NO;
        [centralManager scanForPeripheralsWithServices:nil options:nil];
        
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
        {
            if(!pairconnectde )
            {
                [centralManager scanForPeripheralsWithServices:nil options:nil] ;
            }
            else
            {
                [centralManager connectPeripheral:self.peripheral options:nil];
                // [centralManager connectPeripheral:self.peripheral options:@{CBConnectPeripheralOptionNotifyOnConnectionKey : @YES}];
            }
        }
            break;
        case CBCentralManagerStatePoweredOff:
            //NSLog(@"断开－－－－");
            break;
            
        default:
            break;
    }
}
//连接外设
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    //    NSLog(@"[AppDelegate sharedAppDelegate].Globeuuidstr is ------%@",[AppDelegate sharedAppDelegate].Globeuuidstr);
    if(pairconnectde)
    {
        return;
    }
    
    NSArray *arr = [centralManager retrieveConnectedPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID],[CBUUID UUIDWithString:kServiceUUID2]]];
    if(arr.count>0)
    {
        pairconnectde = YES;
        for (CBPeripheral* peripheral in arr)
        {
            if (peripheral != nil)
            {
                peripheral.delegate = self;
                self.peripheral = peripheral;
                [centralManager connectPeripheral:self.peripheral options:nil];
                //            [centralManager connectPeripheral:self.peripheral options:@{CBConnectPeripheralOptionNotifyOnConnectionKey : @YES}];
                [AppDelegate sharedAppDelegate].peripheral = peripheral;//zwl
                [AppDelegate sharedAppDelegate].Globeuuidstr = [[AppDelegate sharedAppDelegate].peripheral.identifier UUIDString];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:VDBlueToothSearchSuccessNotification object:nil];
                
            }
        }
        return;
    }
    
    if ([[AppDelegate sharedAppDelegate].Globeuuidstr isEqualToString:[peripheral.identifier UUIDString]]) {
        CYBLog(@"绑定了");
        self.peripheral = peripheral;
        
        [centralManager connectPeripheral:self.peripheral options:@{CBConnectPeripheralOptionNotifyOnConnectionKey : @YES}];
    }
    
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    //取消扫描
    [centralManager stopScan];//连接上后取消扫描
    
    self.peripheral.delegate = self;
    [self.peripheral discoverServices:@[[CBUUID UUIDWithString:ServiceUUID]]];
}

//发现服务和特征
#pragma mark -- CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if (error==nil) {
        for (CBService *service in peripheral.services) {
            
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}
//＋＋＋＋＋＋搜索到特征＋＋＋＋＋＋
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    
    if (error) {
        NSLog(@"Error discovering characteristic:%@", [error localizedDescription]);
    }
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"6E400003-B5A3-F393-E0A9-E50E24DCCA9E"]]) {
            
            if(ncharactexist)
            {
                return;
            }
            ncharactexist = YES;
            NSLog(@"characteristicUUID:%@",characteristic.UUID);
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"6E400002-B5A3-F393-E0A9-E50E24DCCA9E"]]) {
            if(kCharactexist)
            {
                return;
            }
            kCharactexist = YES;
            NSLog(@"characteristicUUID:＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝%@",characteristic.UUID);
            self.upGradeChracteristic=characteristic;
            [self sendData];
            
            NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
            [userDefault setObject:[peripheral.identifier UUIDString] forKey:kBlueToothUUID];
            [userDefault setObject:peripheral.name forKey:kBlueToothName];
            [userDefault synchronize];
            btnCancel.enabled = YES;
            [AppDelegate sharedAppDelegate].Globeuuidstr = [peripheral.identifier UUIDString];
        }
    }
}
//读取数据
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    [AppDelegate sharedAppDelegate].blueCutLine = NO;
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:nCharacteristicUUID]]) {
        readData=characteristic.value;
        MXLog(@"+++readData+++%@",readData);
        NSString *str=[[NSString alloc]initWithFormat:@"%@",readData];
        if([str isEqualToString:@"<a60200>"])
        {
            VoodaProgressHUD * myhudfailure = [[VoodaProgressHUD alloc] initWithFrame:CGRectMake((kScreenWidth-240)/2, (kScreenHeight-60)/2, 240, 60)];;
            myhudfailure.mode = MBProgressHUDModeText;
            myhudfailure.labelText = NSLocalizedString(@"校验出错,升级失败",nil);
            [myhudfailure hide:NO];
            [myhudfailure show:YES];
            [myhudfailure hide:YES afterDelay:2.0];
            
            [self removeSubView];
        }
        if([str isEqualToString:@"<a60201>"])
        {
            [centralManager cancelPeripheralConnection:self.peripheral];
            [self performSelector:@selector(versionOTASuceess) withObject:nil afterDelay:0.5];
        }
        [self.arr addObject:str];
        //在这建立分线程，判读命令字是第几包，再发送下一包
        NSThread *thread=[[NSThread alloc]initWithTarget:self selector:@selector(startClick) object:nil];
        [thread start];
    }
}
//＋＋＋＋发初始化信息
-(void)sendData{
    [self.peripheral writeValue:headData forCharacteristic:self.upGradeChracteristic type:CBCharacteristicWriteWithoutResponse];
}
-(void)writeValue:(int)k
{
    [self.peripheral writeValue:[_dataArr objectAtIndex:k-1] forCharacteristic:self.upGradeChracteristic type:CBCharacteristicWriteWithoutResponse];
}
-(void)startClick{
    
    if(_stop)
    {
        return;
    }
    //＋＋＋＋＋发升级数据包
    if(self.arr.count == 1)
    {
        for (NSInteger j = 0; j<10 && j<= self.num; j++)
        {
            [NSThread sleepForTimeInterval:0.1];
            [self.peripheral writeValue:[_dataArr objectAtIndex:j] forCharacteristic:self.upGradeChracteristic type:CBCharacteristicWriteWithoutResponse];
        }
    }
    else{
        for (NSInteger k = (self.arr.count-1)*10; k<self.arr.count*10 && k< self.num; k++)
        {
            [NSThread sleepForTimeInterval:0.001];
            [self.peripheral writeValue:[_dataArr objectAtIndex:k] forCharacteristic:self.upGradeChracteristic type:CBCharacteristicWriteWithoutResponse];
        }
    }
    //zwl
    currenData = self.arr.count * 10;
    [[NSNotificationCenter defaultCenter] postNotificationName:VDBlueToothOTAProgress object:nil];
    
    //＋＋＋＋＋发复位信息
    if (self.arr.count >= self.num/10+1) {
        unsigned short result = [self crc16:self.file];
        NSInteger resultL=result & 0xFF;
        NSString *strresultL = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%02lx",(long)resultL]];
        
        NSInteger resultH=result >> 8;
        NSString *strresultH = [NSString stringWithFormat:@"%@",[[NSString alloc] initWithFormat:@"%02lx",(long)resultH]];
        
        NSString *tStr=@"A602";
        [AppDelegate sharedAppDelegate].curtserversucess= YES;
        tStr = [NSString stringWithFormat:@"%@%@%@",tStr,strresultL,strresultH];
        NSData *tData= [NSStringTool convertHexStrToData:tStr];
        [self.peripheral writeValue:tData forCharacteristic:self.upGradeChracteristic type:CBCharacteristicWriteWithoutResponse];
        self.isNeed=NO;
        
        //升级成功，更改本地版本
        // NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
        //[userDefault setObject:curversion forKey:@"localVersion"];
        //[userDefault synchronize];
        connectTimer = nil;
    }
}

-(void)addMidData:(NSString *)str withDataArr:(NSMutableArray *)dataArr{
    for (int i=0; i<self.num; i++) {
        
        //中间
        NSString *midStr=   [[NSStringTool addZero:[NSStringTool ToHex:i+1] withLength:4]transform];
        
        NSString *string=[NSString stringWithFormat:@"%@%@",str,midStr];
        fileData=[NSStringTool convertHexStrToData:string];
        //尾部添加的字段
        
        //        NSLog(@"------------%@",fileData);
        
        NSData *  aData=[self.file subdataWithRange:NSMakeRange(i*16,16)];
        
        [fileData appendData:aData];
        
        [dataArr addObject:fileData];
    }
}

//输出16个同样的数字  转化为data
-(NSData *)nslogData:(NSString *)str withInt:(int)num{
    NSMutableString *string=[[NSMutableString alloc]init];
    for (int i=0; i<num;i++) {
        [string appendString:str];
        
    }
    NSData *data=[[NSData alloc]init];
    data=[NSStringTool convertHexStrToData:string];
    return data;
}


- (unsigned short)crc16: (NSData*) data
{
    unsigned short crc16table[] =
    {
        0x0000, 0x1189, 0x2312, 0x329B, 0x4624, 0x57AD, 0x6536, 0x74BF,
        
        0x8C48, 0x9DC1, 0xAF5A, 0xBED3, 0xCA6C, 0xDBE5, 0xE97E, 0xF8F7,
        
        0x1081, 0x0108, 0x3393, 0x221A, 0x56A5, 0x472C, 0x75B7, 0x643E,
        
        0x9CC9, 0x8D40, 0xBFDB, 0xAE52, 0xDAED, 0xCB64, 0xF9FF, 0xE876,
        
        0x2102, 0x308B, 0x0210, 0x1399, 0x6726, 0x76AF, 0x4434, 0x55BD,
        
        0xAD4A, 0xBCC3, 0x8E58, 0x9FD1, 0xEB6E, 0xFAE7, 0xC87C, 0xD9F5,
        
        0x3183, 0x200A, 0x1291, 0x0318, 0x77A7, 0x662E, 0x54B5, 0x453C,
        
        0xBDCB, 0xAC42, 0x9ED9, 0x8F50, 0xFBEF, 0xEA66, 0xD8FD, 0xC974,
        
        0x4204, 0x538D, 0x6116, 0x709F, 0x0420, 0x15A9, 0x2732, 0x36BB,
        
        0xCE4C, 0xDFC5, 0xED5E, 0xFCD7, 0x8868, 0x99E1, 0xAB7A, 0xBAF3,
        
        0x5285, 0x430C, 0x7197, 0x601E, 0x14A1, 0x0528, 0x37B3, 0x263A,
        
        0xDECD, 0xCF44, 0xFDDF, 0xEC56, 0x98E9, 0x8960, 0xBBFB, 0xAA72,
        
        0x6306, 0x728F, 0x4014, 0x519D, 0x2522, 0x34AB, 0x0630, 0x17B9,
        
        0xEF4E, 0xFEC7, 0xCC5C, 0xDDD5, 0xA96A, 0xB8E3, 0x8A78, 0x9BF1,
        
        0x7387, 0x620E, 0x5095, 0x411C, 0x35A3, 0x242A, 0x16B1, 0x0738,
        
        0xFFCF, 0xEE46, 0xDCDD, 0xCD54, 0xB9EB, 0xA862, 0x9AF9, 0x8B70,
        
        0x8408, 0x9581, 0xA71A, 0xB693, 0xC22C, 0xD3A5, 0xE13E, 0xF0B7,
        
        0x0840, 0x19C9, 0x2B52, 0x3ADB, 0x4E64, 0x5FED, 0x6D76, 0x7CFF,
        
        0x9489, 0x8500, 0xB79B, 0xA612, 0xD2AD, 0xC324, 0xF1BF, 0xE036,
        
        0x18C1, 0x0948, 0x3BD3, 0x2A5A, 0x5EE5, 0x4F6C, 0x7DF7, 0x6C7E,
        
        0xA50A, 0xB483, 0x8618, 0x9791, 0xE32E, 0xF2A7, 0xC03C, 0xD1B5,
        
        0x2942, 0x38CB, 0x0A50, 0x1BD9, 0x6F66, 0x7EEF, 0x4C74, 0x5DFD,
        
        0xB58B, 0xA402, 0x9699, 0x8710, 0xF3AF, 0xE226, 0xD0BD, 0xC134,
        
        0x39C3, 0x284A, 0x1AD1, 0x0B58, 0x7FE7, 0x6E6E, 0x5CF5, 0x4D7C,
        
        0xC60C, 0xD785, 0xE51E, 0xF497, 0x8028, 0x91A1, 0xA33A, 0xB2B3,
        
        0x4A44, 0x5BCD, 0x6956, 0x78DF, 0x0C60, 0x1DE9, 0x2F72, 0x3EFB,
        
        0xD68D, 0xC704, 0xF59F, 0xE416, 0x90A9, 0x8120, 0xB3BB, 0xA232,
        
        0x5AC5, 0x4B4C, 0x79D7, 0x685E, 0x1CE1, 0x0D68, 0x3FF3, 0x2E7A,
        
        0xE70E, 0xF687, 0xC41C, 0xD595, 0xA12A, 0xB0A3, 0x8238, 0x93B1,
        
        0x6B46, 0x7ACF, 0x4854, 0x59DD, 0x2D62, 0x3CEB, 0x0E70, 0x1FF9,
        
        0xF78F, 0xE606, 0xD49D, 0xC514, 0xB1AB, 0xA022, 0x92B9, 0x8330,
        
        0x7BC7, 0x6A4E, 0x58D5, 0x495C, 0x3DE3, 0x2C6A, 0x1EF1, 0x0F78
    };
    
    unsigned int    crc;
    
    crc = 0xFFFF;
    
    uint8_t byteArray[[data length]];
    [data getBytes:&byteArray];
    
    for (int i = 0; i<[data length]; i++) {
        Byte byte = byteArray[i];
        crc = (crc >> 8) ^ crc16table[(crc^ byte) & 0xFF];
    }
    //    crc = (crc >> 8) ^ table[(crc ^ bytes[i]) & 0xff];
    
    return crc;
}

@end
