//
//  crc.h
//  testBluetooth
//
//  Created by 罗 显松 on 2017/3/29.
//  Copyright © 2017年 neusoft. All rights reserved.
//

#ifndef crc_h
#define crc_h

#include <stdio.h>

#define CRC_INIT  0xffff
#define M16    0xA001
unsigned int CalcCRC(unsigned char *pBuf, unsigned char ucLen);

#endif /* crc_h */
