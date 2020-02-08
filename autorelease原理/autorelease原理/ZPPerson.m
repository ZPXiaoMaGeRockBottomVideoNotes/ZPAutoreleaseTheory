//
//  ZPPerson.m
//  autorelease原理
//
//  Created by 赵鹏 on 2019/8/27.
//  Copyright © 2019 赵鹏. All rights reserved.
//

#import "ZPPerson.h"

@implementation ZPPerson

-(void)dealloc
{
    NSLog(@"%s", __func__);
    
    [super dealloc];
}

@end
