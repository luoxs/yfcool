//
//  ViewController.h
//  yfcool
//
//  Created by apple on 2022/7/18.
//

#import <UIKit/UIKit.h>
#import "BabyBluetooth.h"

@interface ViewController : UIViewController{
@public
BabyBluetooth *baby;
}
@property (nonatomic, strong) NSData *dataRead;
@property (nonatomic,strong)CBCharacteristic *characteristic;
@property (nonatomic,strong)CBPeripheral *currPeripheral;

@end

