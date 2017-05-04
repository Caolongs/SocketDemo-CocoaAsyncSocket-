//
//  SocketManager.h
//  SocketDemo
//
//  Created by cao longjian on 17/5/4.
//  Copyright © 2017年 Jiji. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SocketManager : NSObject

+ (instancetype)shareInstance;

- (BOOL)connect;
- (void)disConnect;

- (void)sendMsg:(NSString *)msg;
- (void)pullTheMsg;



@end
