//
//  ViewController.m
//  yfcool
//
//  Created by apple on 2022/7/18.
//

#import "ViewController.h"
#import "BabyBluetooth.h"
#import "SDAutoLayout.h"
#import "MBProgressHUD.h"
#import "crcLib.h"
#import "ExplainViewController.h"
#import "AboutViewController.h"

@interface ViewController (){
    Byte write[5];
    Byte read[128];
    int  realtemp;
    int  tempsetting;
    BOOL unitceis;
    BOOL powerstatus;  //开关状态
}
@property (retain, nonatomic)  MBProgressHUD *hud;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setAutoLayout];
    
    //初始化BabyBluetooth 蓝牙库
    baby = [BabyBluetooth shareBabyBluetooth];
    //设置蓝牙委托
    [self babyDelegate];
    
    realtemp = 0;
    tempsetting = 0;
    unitceis = YES;
    powerstatus = YES;
    
    //设置委托后直接可以使用，无需等待CBCentralManagerStatePoweredOn状态
    //baby.scanForPeripherals().begin();
    //baby.scanForPeripherals().begin(10);
    /*
    baby.scanForPeripherals().connectToPeripherals().discoverServices()
        .discoverCharacteristics().readValueForCharacteristic().discoverDescriptorsForCharacteristic()
        .readValueForDescriptors().begin();
     */
}

-(void)viewWillDisappear:(BOOL)animated{
    [baby cancelAllPeripheralsConnection];
    
}
//蓝牙网关初始化和委托方法设置
-(void)babyDelegate{
    
    __weak typeof(self) weakSelf = self;
    [baby setBlockOnCentralManagerDidUpdateState:^(CBCentralManager *central) {
        if (central.state == CBManagerStatePoweredOn) {
            NSLog(@"设备打开成功，开始扫描设备");
        }
    }];
    
    //设置扫描到设备的委托
    [baby setBlockOnDiscoverToPeripherals:^(CBCentralManager *central, CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI) {
        NSLog(@"扫描到了设备:%@",peripheral.name);
        if([peripheral.name isEqualToString:@"YF-REF"]){
            [central stopScan];
        }
    }];
    
    //设置设备连接成功的委托,同一个baby对象，使用不同的channel切换委托回调
    [baby setBlockOnConnected:^(CBCentralManager *central, CBPeripheral *peripheral) {
        NSLog(@"设备：%@--连接成功",peripheral.name);
        if([peripheral.name isEqualToString:@"YF-REF"]){
            weakSelf.currPeripheral = peripheral;
            UILabel *lbstatus = (UILabel *)[weakSelf.view  viewWithTag:200];
            lbstatus.text = @"YF-REF";
            UIButton *btConnect = (UIButton *)[weakSelf.view viewWithTag:300];
            [btConnect setTitle:@"Disconnect" forState:UIControlStateNormal];
            UIImageView *ivBluetooth = (UIImageView *)[weakSelf.view viewWithTag:100];
            [ivBluetooth setImage:[UIImage imageNamed:@"bluetooth"]];
        }
    }];
    
    //设置设备连接失败的委托
    [baby setBlockOnFailToConnect:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
        NSLog(@"设备：%@--连接失败",peripheral.name);
    }];
    
    //设置设备断开连接的委托
    [baby setBlockOnDisconnect:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
        NSLog(@"设备：%@--断开连接",peripheral.name);
        if([peripheral.name isEqualToString:@"YF-REF"]){
            weakSelf.currPeripheral = peripheral;
            UILabel *lbstatus = (UILabel *)[weakSelf.view  viewWithTag:200];
            lbstatus.text = @"Not Linked";
            UIButton *btConnect = (UIButton *)[weakSelf.view viewWithTag:300];
            [btConnect setTitle:@"Connect" forState:UIControlStateNormal];
            UIImageView *ivBluetooth = (UIImageView *)[weakSelf.view viewWithTag:100];
            [ivBluetooth setImage:[UIImage imageNamed:@"bluetooth1"]];
        }
    }];
    
    //设置发现设备的Services的委托
    [baby setBlockOnDiscoverServices:^(CBPeripheral *peripheral, NSError *error) {
        for (CBService *s in peripheral.services) {
            NSLog(@"servicing %@ discovered!----",s.description);
        }
    }];
    
    //设置发现设service的Characteristics的委托
    [baby setBlockOnDiscoverCharacteristics:^(CBPeripheral *peripheral, CBService *service, NSError *error) {
        NSLog(@"Dicover Characteristics ===service name:%@",service.UUID);
    }];
    
    //设置读取characteristics的委托
    [baby setBlockOnReadValueForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
        NSLog(@"characteristic name:%@ value is:%@",characteristics.UUID,characteristics.value);
        [weakSelf.hud removeFromSuperview];
        weakSelf.hud = nil;
        
        if([characteristics.UUID.UUIDString isEqualToString:@"FFE1"]){
            weakSelf.characteristic = characteristics;
            Byte r[20] = {0};
            NSData *data = characteristics.value;
      
            if(data.length == 5){
                memcpy(r,[data bytes],5);
                NSLog(@"hehe");
                
                switch (r[1]) {
                    case 0x01:{  //开关机
                        Byte  status = r[2];
                        if(status==0){
                            self->powerstatus = NO;
                        }else{
                            self->powerstatus = YES;
                        }
                    }
                        break;
                        
                    case 0x03:{  //设定温度
                        Byte r2 = r[2];
                        if(r2>0x10){
                            r[2] = 0xff - r2 + 1;   //负数补码表示,取绝对值
                            self->tempsetting = r[2] *(-1);  //相反数
                        }else{
                            self->tempsetting = r[2];
                        }
                        UILabel *lbsetting = (UILabel *)[weakSelf.view viewWithTag:800];
                        if(self->unitceis){
                            lbsetting.text = [NSString stringWithFormat:@"%d℃",self->tempsetting];
                        }else{
                            int Fahrenheitreal = (int)(self->tempsetting *1.8  + 32);
                            lbsetting.text = [NSString stringWithFormat:@"%d℉",Fahrenheitreal];
                        }
                    }
                        break;
                        
                    case 0x04:{   //实时温度
                        self->realtemp = r[2];
                        UILabel *lbreal = (UILabel *)[weakSelf.view viewWithTag:600];
                        if(self->unitceis){
                            lbreal.text = [NSString stringWithFormat:@"%d℃",self->realtemp];
                        }else{
                            int Fahrenheitreal = (int)(self->realtemp *1.8 + 32);
                            lbreal.text = [NSString stringWithFormat:@"%d℉",Fahrenheitreal];
                        }
                    }
                        break;
                        
                    case 0x06:{//报警
                        NSLog(@"数据异常");
                    }
                        
                    default:
                        break;
                }
            }else if(data.length ==20){
                memcpy(r,[data bytes],20);
                NSLog(@"haha");
                //电源
                UIImageView *ivPower = (UIImageView *)[self.view viewWithTag:400];
                UIImageView *ivPowerFail = (UIImageView *)[self.view viewWithTag:500];
                if(r[2]==1){
                    self->powerstatus = YES;
                    ivPower.hidden = NO;
                    ivPowerFail.hidden = YES;
                }else{
                    self->powerstatus = NO;
                    ivPower.hidden = YES;
                    ivPowerFail.hidden = NO;
                }
                
                /*r[7]为状态字节
                 数据格式：b1 b2 b3 b4 b5 b6 b7 b8（8 bits）
                 b1:  0为摄氏；1为华氏
                 b2:  0为压缩机停（显示位置：左下角，显示状态：灰白色）
                 1为压缩机开（显示位置：左下角，显示状态：绿色）
                 b3b4:  01正常（显示位置：右下角，显示状态：灰白色）
                 10-故障（显示位置：右下角，显示状态：红色）
                 b6b7b8: 100 LOW、010-MID、001-HIG
                 */
                UILabel *lbSetting = (UILabel *)[self.view viewWithTag:800];
                Byte b1 = r[7] & 0x80;
                if(b1==0){
                    self->unitceis = YES;
                    [lbSetting setText:@"0℃"];
                }else{
                    self->unitceis = NO;
                    [lbSetting setText:@"32℉"];
                }
                
                UISegmentedControl *sgBattery  = (UISegmentedControl *)[self.view viewWithTag:900];
                Byte b678 = r[7] & 0x07;
                if(b678 == 0x04){
                    [sgBattery setSelectedSegmentIndex:0];
                }else if(b678 == 0x02){
                    [sgBattery setSelectedSegmentIndex:1];
                }else{
                    [sgBattery setSelectedSegmentIndex:2];
                }
                
                UILabel *lbreal = (UILabel *)[weakSelf.view viewWithTag:600];
                self->realtemp = r[17];
                if(self->unitceis){
                    lbreal.text = [NSString stringWithFormat:@"%d℃",self->realtemp];
                }else{
                    int Fahrenheitreal = (int)(self->realtemp * 1.8  + 32);
                    lbreal.text = [NSString stringWithFormat:@"%d℉",Fahrenheitreal];
                }
                [self.view updateLayout];
            }
        }
        //[weakSelf.currPeripheral setNotifyValue:NO forCharacteristic:weakSelf.characteristic];
    }];
    
    
    //设置发现characteristics的descriptors的委托
    [baby setBlockOnDiscoverDescriptorsForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error) {
        //  NSLog(@"===characteristic name:%@",characteristic.service.UUID);
        for (CBDescriptor *d in characteristic.descriptors) {
            NSLog(@"CBDescriptor name is :%@",d.UUID);
        }
    }];
    
    //设置读取Descriptor的委托
    [baby setBlockOnReadValueForDescriptors:^(CBPeripheral *peripheral, CBDescriptor *descriptor, NSError *error) {
        NSLog(@"Descriptor name:%@ value is:%@",descriptor.characteristic.UUID, descriptor.value);
            //重新定义写内容
            Byte  write[5];
            write[0] = 68;
            write[1] = 5;
            write[2] = 65;
            write[3] = 66;
            write[4] = 55;
            
            NSData *data = [[NSData alloc]initWithBytes:write length:5];
            for(int i=0;i<2;i++){
                [weakSelf.currPeripheral writeValue:data forCharacteristic:weakSelf.characteristic type:CBCharacteristicWriteWithResponse];
                [weakSelf.currPeripheral setNotifyValue:YES forCharacteristic:weakSelf.characteristic];
            }
    }];
    
    
    [baby setBlockOnDidWriteValueForCharacteristic:^(CBCharacteristic *characteristic, NSError *error) {
        NSLog(@"Write data successful!");
    }];
    
    //设置查找设备的过滤器
    [baby setFilterOnDiscoverPeripherals:^BOOL(NSString *peripheralName, NSDictionary *advertisementData, NSNumber *RSSI) {
        if ([peripheralName isEqualToString:@"YF-REF"]) {
            return YES;
        }
        return NO;
    }];
    
    //扫描选项->CBCentralManagerScanOptionAllowDuplicatesKey:忽略同一个Peripheral端的多个发现事件被聚合成一个发现事件
    NSDictionary *scanForPeripheralsWithOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@YES};
    //连接设备->
    [baby setBabyOptionsWithScanForPeripheralsWithOptions:scanForPeripheralsWithOptions connectPeripheralWithOptions:nil scanForPeripheralsWithServices:nil discoverWithServices:nil discoverWithCharacteristics:nil];
}

#pragma mark control event

-(void)connect:(id)sender{
    
    UIButton *btConnect = (UIButton *)[self.view viewWithTag:300];
    
    if([btConnect.titleLabel.text isEqualToString:@"Connect"]){
        baby.scanForPeripherals().connectToPeripherals().discoverServices()
            .discoverCharacteristics().readValueForCharacteristic().discoverDescriptorsForCharacteristic()
            .readValueForDescriptors().begin();
        self.hud = [[MBProgressHUD alloc] init];
        [self.view addSubview:self.hud];
        self.hud.mode = MBProgressHUDModeIndeterminate;
        self.hud.label.text = @"连接设备中……";
        [self.hud  showAnimated:YES];
    }else{
        [baby cancelAllPeripheralsConnection];
        UILabel *lbTemperature = (UILabel *)[self.view viewWithTag:600];
        if(unitceis){
            [lbTemperature setText:@"--℃"];
        }else{
            [lbTemperature setText:@"--℉"];
        }
    }
}

//poweron--off
-(void) powerchg:(id)sender{
    powerstatus = !powerstatus;
    UIImageView *ivPower = (UIImageView *)[self.view viewWithTag:400];
    UIImageView *ivPowerFail = (UIImageView *)[self.view viewWithTag:500];
    
    write[0] = 68;
    write[1] = 1;
    write[4] = 55;
    if(powerstatus){
        ivPower.hidden = NO;
        write[2]= 1;
        write[3]= 2;
        ivPowerFail.hidden = YES;
    }else{
        ivPower.hidden = YES;
        write[2]= 0;
        write[3]= 1;
        ivPowerFail.hidden = NO;
    }
    
    NSData *data = [[NSData alloc]initWithBytes:write length:5];
    for(int i=0;i<2;i++){
        [self.currPeripheral writeValue:data forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
        [self.currPeripheral setNotifyValue:YES forCharacteristic:self.characteristic];
    }
}

-(void) addTemp:(id)sender{
    UILabel *lbsetting = (UILabel *)[self.view viewWithTag:800];
    if(tempsetting<=11){
        tempsetting++;
        if(unitceis){
            lbsetting.text = [NSString stringWithFormat:@"%d℃",tempsetting];
        }else {
            int  Fahrenheit = (int)((tempsetting*1.8 +32));
            lbsetting.text = [NSString stringWithFormat:@"%d℉",Fahrenheit];
        }
        write[0] = 68;
        write[1] = 3;
        write[2] = tempsetting;
        write[3] = tempsetting + 1;
        write[4] = 55;
        NSData *data = [[NSData alloc]initWithBytes:write length:5];
        for(int i=0;i<2;i++){
            [self.currPeripheral writeValue:data forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
            [self.currPeripheral setNotifyValue:YES forCharacteristic:self.characteristic];
        }
    }
}


-(void)subTemp:(id)sender{
    UILabel *lbSetting = (UILabel *)[self.view viewWithTag:800];
    if(tempsetting>=-21){
        tempsetting--;
        if(unitceis){
            lbSetting.text = [NSString stringWithFormat:@"%d℃",tempsetting];
        }else {
            int  Fahrenheit = (int)(tempsetting * 1.8  + 32);
            lbSetting.text = [NSString stringWithFormat:@"%d℉",Fahrenheit];
        }
        write[0] = 68;
        write[1] = 3;
        write[2] = tempsetting;
        write[3] = tempsetting + 1;
        write[4] = 55;
        NSData *data = [[NSData alloc]initWithBytes:write length:5];
        for(int i=0;i<2;i++){
            [self.currPeripheral writeValue:data forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
            [self.currPeripheral setNotifyValue:YES forCharacteristic:self.characteristic];
        }
    }
}

-(void) chgunit:(id)sender{
    unitceis = !unitceis;
    UILabel *lbSetting = (UILabel *)[self.view viewWithTag:800];
    UILabel *lbreal = (UILabel *)[self.view viewWithTag:600];
    if(unitceis){
        lbSetting.text = [NSString stringWithFormat:@"%d℃",tempsetting];
        lbreal.text = [NSString stringWithFormat:@"%d℃",realtemp];
    }else{
        int Fahrenheitsetting = (int)(tempsetting * 1.8 + 32);
        int Fahrenheitreal = (int)(realtemp * 1.8  + 32);
        lbSetting.text = [NSString stringWithFormat:@"%d℉",Fahrenheitsetting];
        lbreal.text = [NSString stringWithFormat:@"%d℉",Fahrenheitreal];
    }
    
    UISegmentedControl *sgBattery = (UISegmentedControl *)[self.view viewWithTag:900];
    write[0] = 68;
    write[1] = 2;
    write[4] = 55;
    if(sgBattery.selectedSegmentIndex == 0){
        write[2] = 0x04;
    }else if(sgBattery.selectedSegmentIndex == 1){
        write[2] = 0x02;
    }else{
        write[2] = 0x01;
    }
    
    if(!unitceis){
        write[2] = 0x80 + write[2];
    }
    write[3] = write[2] +1;
    NSData *data = [[NSData alloc]initWithBytes:write length:5];
    for(int i=0;i<2;i++){
        [self.currPeripheral writeValue:data forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
        [self.currPeripheral setNotifyValue:YES forCharacteristic:self.characteristic];
    }
}

//设置电池容量
-(void)batteryChg:(id)sender{
    /*
     数据格式：b1 b2 b3 b4 b5 b6 b7 b8（8 bits）
     数据协议
     b1:  0为摄氏；1为华氏
     b2:  0为压缩机停（显示位置：左下角，显示状态：灰白色）
     1为压缩机开（显示位置：左下角，显示状态：绿色）
     b3b4:  01正常（显示位置：右下角，显示状态：灰白色）
     10-故障（显示位置：右下角，显示状态：红色）
     b6b7b8: 100 LOW、010-MID、001-HIG（电量显示位置：中下部）
     */
    UISegmentedControl *sgBattery = (UISegmentedControl *)[self.view viewWithTag:900];
    write[0] = 68;
    write[1] = 2;
    write[4] = 55;
    if(sgBattery.selectedSegmentIndex == 0){
        write[2] = 0x04;
    }else if(sgBattery.selectedSegmentIndex == 1){
        write[2] = 0x02;
    }else{
        write[2] = 0x01;
    }
    
    if(!unitceis){
        write[2] = 0x80 + write[2];
    }
    write[3] = write[2] +1;
    NSData *data = [[NSData alloc]initWithBytes:write length:5];
    for(int i=0;i<2;i++){
        [self.currPeripheral writeValue:data forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
        [self.currPeripheral setNotifyValue:YES forCharacteristic:self.characteristic];
    }
}


-(void)explain:(id)sender{
    ExplainViewController *explain = [ExplainViewController new];
    [self presentViewController:explain animated:YES completion:^{
        NSLog(@"present expalin  viewcontroller");
    }];
}

-(void)about:(id)sender{
    AboutViewController *about = [AboutViewController new];
    [self presentViewController:about animated:YES completion:^{
        NSLog(@"present about  viewcontroller");
    }];
}



#pragma mark setAutoLayout

-(void)setAutoLayout{
    
    float interval = self.view.height/18;
    //颜色值一定要用实数
    [self.view setBackgroundColor:[UIColor colorWithRed:172.0/255 green:212.0/255 blue:255.0/255 alpha:0.9]];
    //interface operation instructions
    
    UIButton *btInterface = [[UIButton alloc]init];
    [self.view addSubview:btInterface];
    btInterface.sd_layout
        .topSpaceToView(self.view, interval+16)
        .leftSpaceToView(self.view, 16)
        .heightRatioToView(self.view, 0.06)
        .widthEqualToHeight();
    [btInterface setBackgroundImage:[UIImage imageNamed:@"interface"] forState:UIControlStateNormal];
    [btInterface addTarget:self action:@selector(explain:) forControlEvents:UIControlEventTouchUpInside];
    
    //bluetooth connection
    UIImageView *ivBluetooth = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"bluetooth1"]];
    [self.view addSubview:ivBluetooth];
    ivBluetooth.sd_layout
        .topEqualToView(btInterface)
        .leftSpaceToView(btInterface, 16)
        .heightRatioToView(self.view, 0.06)
        .widthRatioToView(self.view, 0.12);
    [ivBluetooth setTag:100];
    
    //information show
    UIButton *btAbout = [[UIButton alloc]init];
    [btAbout setBackgroundImage:[UIImage imageNamed:@"infomation"] forState:UIControlStateNormal];
    [self.view addSubview:btAbout];
    btAbout.sd_layout
        .centerYEqualToView(btInterface)
        .rightSpaceToView(self.view, 16)
        .heightRatioToView(self.view, 0.06)
        .widthEqualToHeight();
    [btAbout addTarget:self action:@selector(about:) forControlEvents:UIControlEventTouchUpInside];
    
    //label1
    UILabel  *label1 = [UILabel new];
    [self.view addSubview:label1];
    label1.text = @"Actual BLE State:";
    label1.sd_layout
        .leftSpaceToView(self.view, 16.0)
        .topSpaceToView(btInterface, 8)
        .widthRatioToView(self.view, 0.4)
        .heightIs(interval);
    //[label1 setSingleLineAutoResizeWithMaxWidth:[self.view.width*0.3]];
    [label1 setFont:[UIFont fontWithName:@"Arial" size:18]];
    [label1 setTextColor:[UIColor brownColor]];
    
    //label2
    UILabel  *lbStatus = [UILabel new];
    [self.view addSubview:lbStatus];
    lbStatus.text = @"Not Linked";
    [lbStatus setFont:[UIFont fontWithName:@"Arial" size:18]];
    lbStatus.sd_layout
        .leftSpaceToView(label1, 4.0)
        .widthRatioToView(self.view, 0.25)
        .heightRatioToView(label1, 1.0)
        .centerYEqualToView(label1);
    [lbStatus setSingleLineAutoResizeWithMaxWidth:100];
    [lbStatus setTextColor:[UIColor brownColor]];
    [lbStatus setTag:200];
    
    //button connect
    UIButton *btConnect = [[UIButton alloc] init];
    [self.view addSubview:btConnect];
    btConnect.sd_layout
        .centerYEqualToView(label1)
        .widthRatioToView(self.view, 0.25)
        .heightRatioToView(label1, 1.0)
        .rightSpaceToView(self.view, 16);
    [btConnect setBackgroundColor:[UIColor brownColor]];
    [btConnect setTitle:@"Connect" forState:UIControlStateNormal];
    [btConnect setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
    [btConnect addTarget:self action:@selector(connect:) forControlEvents:UIControlEventTouchUpInside];
    [btConnect setTag:300];
    
    //logo
    UIImageView *ivLogo = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"logo"]];
    [self.view addSubview:ivLogo];
    ivLogo.sd_layout
        .topSpaceToView(label1, 8)
        .centerXEqualToView(self.view)
        .heightRatioToView(self.view, 0.07)
        .widthRatioToView(self.view, 0.5);
    
    //power
    UIButton *btPower = [[UIButton alloc] init];
    [btPower setBackgroundImage:[UIImage imageNamed:@"power"] forState:UIControlStateNormal];
    [self.view addSubview:btPower];
    btPower.sd_layout
        .topSpaceToView(ivLogo, interval)
        .centerXEqualToView(self.view)
        .heightRatioToView(self.view, 0.12)
        .widthEqualToHeight();
    [btPower addTarget:self action:@selector(powerchg:) forControlEvents:UIControlEventTouchUpInside];
    
    //power indicator
    UIImageView *ivPower = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"greendot"]];
    [self.view addSubview:ivPower];
    ivPower.sd_layout
        .topSpaceToView(ivLogo, interval+10)
        .leftSpaceToView(btPower,30)
        .heightRatioToView(self.view, 0.02)
        .widthEqualToHeight();
    [ivPower setTag:400];
    
    UIImageView *ivPowerFail = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"reddot"]];
    [self.view addSubview:ivPowerFail];
    ivPowerFail.sd_layout
        .topSpaceToView(ivPower, interval)
        .leftSpaceToView(btPower, 30)
        .heightRatioToView(self.view, 0.02)
        .widthEqualToHeight();
    [ivPowerFail setTag:500];
    
    if(powerstatus){
        ivPower.hidden = NO;
        ivPowerFail.hidden = YES;
    }else{
        ivPower.hidden = YES;
        ivPowerFail.hidden = NO;
    }
    
    //temperature background
    UIView *vTemperature = [[UIView alloc]init];
    [self.view addSubview:vTemperature];
    vTemperature.sd_layout
        .topSpaceToView(btPower, interval)
        .leftSpaceToView(self.view, 50)
        .heightRatioToView(self.view, 0.10)
        .widthRatioToView(self.view, 0.5);
    //[vTemperature setBackgroundColor:[UIColor blueColor]];
    [vTemperature setBackgroundColor:[UIColor colorWithRed:64.0/255 green:142.0/255 blue:178.0/255 alpha:1.0]];
    
    //real temperature
    UILabel *lbTemperature = [[UILabel alloc] init];
    lbTemperature.text = @"--℃";
    [lbTemperature setFont:[UIFont fontWithName:@"Arial" size:48]];
    [vTemperature addSubview:lbTemperature];
    lbTemperature.sd_layout
        .spaceToSuperView(UIEdgeInsetsMake(10, 10, 10, 10));
    lbTemperature.textAlignment = NSTextAlignmentCenter;
    [lbTemperature setBackgroundColor:[UIColor colorWithRed:12.0/255 green:80.0/255 blue:144.0/255 alpha:1.0]];
    [lbTemperature setTextColor:[UIColor whiteColor]];
    [lbTemperature setTag:600];
    
    
    //unit backgrount
    UIImageView *vUnit = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"pinkdot"]];
    [self.view addSubview:vUnit];
    vUnit.sd_layout
        .centerYEqualToView(vTemperature)
        .rightSpaceToView(self.view, 50)
        .heightRatioToView(self.view, 0.10)
        .widthEqualToHeight();
    
    //uinit  button
    UIButton *btUint = [[UIButton alloc] init];
    [self.view addSubview:btUint];
    [btUint setBackgroundImage:[UIImage imageNamed:@"bluedot"] forState:UIControlStateNormal];
    [btUint setTitle:@"C/F" forState:UIControlStateNormal];
    btUint.titleLabel.font = [UIFont fontWithName:@"Arial" size:40];
    btUint.sd_layout
        .centerYEqualToView(vTemperature)
        .rightSpaceToView(self.view, 50)
        .heightRatioToView(self.view, 0.10)
        .widthEqualToHeight();
    [btUint addTarget:self action:@selector(chgunit:) forControlEvents:UIControlEventTouchUpInside];
    
    
    //temperature setting background
    UIView *vSetting = [[UIView alloc]init];
    [self.view addSubview:vSetting];
    vSetting.sd_layout
        .topSpaceToView(vUnit, interval)
        .centerXEqualToView(self.view)
        .heightRatioToView(self.view, 0.10)
        .widthRatioToView(self.view, 0.7);
    //[vTemperature setBackgroundColor:[UIColor blueColor]];
    [vSetting setBackgroundColor:[UIColor colorWithRed:64.0/255 green:142.0/255 blue:178.0/255 alpha:1.0]];
    
    //button sub
    UIButton *btSub = [UIButton new];
    [vSetting addSubview: btSub];
    [btSub setBackgroundImage:[UIImage imageNamed:@"minus"] forState:UIControlStateNormal];
    [btSub setBackgroundImage:[UIImage imageNamed:@"minus1"] forState:UIControlStateHighlighted];
    btSub.sd_layout
        .topSpaceToView(vSetting, 8.0)
        .leftSpaceToView(vSetting, 8.0)
        .bottomSpaceToView(vSetting, 8.0)
        .widthEqualToHeight();
    [btSub addTarget:self action:@selector(subTemp:) forControlEvents:UIControlEventTouchUpInside];
    
    //button add
    UIButton *btAdd = [UIButton new];
    [vSetting addSubview: btAdd];
    [btAdd setBackgroundImage:[UIImage imageNamed:@"add"] forState:UIControlStateNormal];
    [btAdd setBackgroundImage:[UIImage imageNamed:@"add1"] forState:UIControlStateHighlighted];
    btAdd.sd_layout
        .topSpaceToView(vSetting, 8.0)
        .rightSpaceToView(vSetting, 8.0)
        .bottomSpaceToView(vSetting, 8.0)
        .widthEqualToHeight();
    [btAdd addTarget:self action:@selector(addTemp:) forControlEvents:UIControlEventTouchUpInside];
    //label setting
    UILabel  *lbSetting = [UILabel new];
    [vSetting addSubview:lbSetting];
    [lbSetting setBackgroundColor:[UIColor whiteColor]];
    //lbSetting.text = @"24°c";
    lbSetting.text = @"0℃";
    lbSetting.sd_layout
        .leftSpaceToView(btSub, 16.0)
        .rightSpaceToView(btAdd, 16.0)
        .topSpaceToView(vSetting, 8.0)
        .bottomSpaceToView(vSetting, 8.0);
    [lbSetting setFont:[UIFont fontWithName:@"Arial" size:36] ];
    // [lbSetting setSingleLineAutoResizeWithMaxWidth:200];
    lbSetting.textAlignment = NSTextAlignmentCenter;
    [lbSetting setTextColor:[UIColor brownColor]];
    [lbSetting setTag:800];
    
    //battery protection
    UISegmentedControl *sgBattery = [[UISegmentedControl alloc] initWithItems:@[@"low",@"middle",@"high"]];
    [self.view addSubview:sgBattery];
    sgBattery.sd_layout
        .centerXEqualToView(self.view)
        .topSpaceToView(vSetting, interval)
        .heightRatioToView(self.view, 0.06)
        .widthRatioToView(self.view, 0.6);
    [sgBattery setBackgroundColor:[UIColor colorWithRed:64.0/255 green:142.0/255 blue:178.0/255 alpha:1.0]];
    [sgBattery setSelectedSegmentIndex:0];
    [sgBattery setSelectedSegmentTintColor:[UIColor colorWithRed:12.0/255 green:80.0/255 blue:144.0/255 alpha:1.0]];
    [sgBattery setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor],NSFontAttributeName:[UIFont fontWithName:@"Arial" size:24]}forState:UIControlStateNormal];
    [sgBattery setTag:900];
    [sgBattery addTarget:self action:@selector(batteryChg:) forControlEvents:UIControlEventValueChanged];
    
    //battery icon
    UIImageView *ivBattery = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"battery"]];
    [self.view addSubview:ivBattery];
    ivBattery.sd_layout
        .centerYEqualToView(sgBattery)
        .rightSpaceToView(sgBattery, 0)
        .heightRatioToView(sgBattery, 1.0)
        .widthRatioToView(self.view, 0.1);
}


@end
