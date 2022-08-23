//
//  crc.c
//  testBluetooth
//
//  Created by 罗 显松 on 2017/3/29.
//  Copyright © 2017年 neusoft. All rights reserved.
//

#include "crc.h"

unsigned int  CalcCRC(unsigned char *pBuf, unsigned char ucLen)
{
    unsigned char ucByte, ucBit, ucShf;
    //unsigned int uiCRC;
    unsigned int uiCRC;
    uiCRC = CRC_INIT;
    for(ucByte = 0; ucByte < ucLen; ucByte++)
    {
        ucShf = *pBuf;
        for(ucBit = 0; ucBit < 8; ucBit++)
        {
            if((uiCRC ^ ucShf) & 0x0001)
                uiCRC = (uiCRC >> 1) ^ M16;
            else 
                uiCRC >>= 1; 
            ucShf >>= 1; 
        } 
        pBuf++; 
    }
    return uiCRC;
}
