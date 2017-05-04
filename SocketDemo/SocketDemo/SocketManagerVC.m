//
//  SocketManagerVC.m
//  SocketDemo
//
//  Created by cao longjian on 17/5/4.
//  Copyright © 2017年 Jiji. All rights reserved.
//

#import "SocketManagerVC.h"
#import "SocketManager.h"

@interface SocketManagerVC ()

@property (nonatomic, strong) SocketManager *socketManager;

@end

@implementation SocketManagerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blueColor];
    
    _socketManager = [SocketManager shareInstance];
    [_socketManager connect];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [_socketManager sendMsg:@"hahah"];
}


@end
