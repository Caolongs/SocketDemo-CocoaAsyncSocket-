//
//  ViewController.m
//  SocketDemo
//
//  Created by cao longjian on 17/5/3.
//  Copyright © 2017年 Jiji. All rights reserved.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"

#import "SocketManagerVC.h"

#define  WWW_PORT 8889  // 0 => automatic
#define  WWW_HOST @"127.0.0.1"
#define CERT_HOST @"127.0.0.1"

#define USE_SECURE_CONNECTION    1
#define USE_CFSTREAM_FOR_TLS     0 // Use old-school CFStream style technique
#define MANUALLY_EVALUATE_TRUST  1

#define READ_HEADER_LINE_BY_LINE 0
@interface ViewController () <GCDAsyncSocketDelegate>

@property (nonatomic) GCDAsyncSocket *asyncSocket;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self startSocket];
    
}



- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{

    SocketManagerVC *vc = [[SocketManagerVC alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)startSocket
{
    _asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *error = nil;
    
    uint16_t port = WWW_PORT;
    if (port == 0)
    {
#if USE_SECURE_CONNECTION
        port = 443; // HTTPS
#else
        port = 80;  // HTTP
#endif
    }
    
    if (![_asyncSocket connectToHost:WWW_HOST onPort:port error:&error])
    {
        
        NSLog(@"Unable to connect to due to invalid configuration: %@", error);
    }
    else
    {
        NSLog(@"Connecting to \"%@\" on port %hu...", WWW_HOST, port);
    }
    
#if USE_SECURE_CONNECTION
    
    // The connect method above is asynchronous.
    // At this point, the connection has been initiated, but hasn't completed.
    // When the connection is established, our socket:didConnectToHost:port: delegate method will be invoked.
    //
    // Now, for a secure connection we have to connect to the HTTPS server running on port 443.
    // The SSL/TLS protocol runs atop TCP, so after the connection is established we want to start the TLS handshake.
    //
    // We already know this is what we want to do.
    // Wouldn't it be convenient if we could tell the socket to queue the security upgrade now instead of waiting?
    // Well in fact you can! This is part of the queued architecture of AsyncSocket.
    //
    // After the connection has been established, AsyncSocket will look in its queue for the next task.
    // There it will find, dequeue and execute our request to start the TLS security protocol.
    //
    // The options passed to the startTLS method are fully documented in the GCDAsyncSocket header file.
    
#if USE_CFSTREAM_FOR_TLS
    {
        // Use old-school CFStream style technique
        
        NSDictionary *options = @{
                                  GCDAsyncSocketUseCFStreamForTLS : @(YES),
                                  GCDAsyncSocketSSLPeerName : CERT_HOST
                                  };
        
        NSLog(@"Requesting StartTLS with options:\n%@", options);
        [asyncSocket startTLS:options];
    }
#elif MANUALLY_EVALUATE_TRUST
    {
        // Use socket:didReceiveTrust:completionHandler: delegate method for manual trust evaluation
        
        NSDictionary *options = @{
                                  GCDAsyncSocketManuallyEvaluateTrust : @(YES),
                                  GCDAsyncSocketSSLPeerName : CERT_HOST
                                  };
        
        NSLog(@"Requesting StartTLS with options:\n%@", options);
        [_asyncSocket startTLS:options];
    }
#else
    {
        // Use default trust evaluation, and provide basic security parameters
        
        NSDictionary *options = @{
                                  GCDAsyncSocketSSLPeerName : CERT_HOST
                                  };
        
        NSLog(@"Requesting StartTLS with options:\n%@", options);
        [asyncSocket startTLS:options];
    }
#endif
    
#endif
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"socket:didConnectToHost:%@ port:%hu", host, port);
    
    NSString *requestStrFrmt = @"HEAD / HTTP/1.0\r\nHost: %@\r\n\r\n";
    
    NSString *requestStr = [NSString stringWithFormat:requestStrFrmt, WWW_HOST];
    NSData *requestData = [requestStr dataUsingEncoding:NSUTF8StringEncoding];
    
    [_asyncSocket writeData:requestData withTimeout:-1.0 tag:0];
    
    NSLog(@"Sending HTTP Request:\n%@", requestStr);
    
    
#if READ_HEADER_LINE_BY_LINE
    
    // Now we tell the socket to read the first line of the http response header.
    // As per the http protocol, we know each header line is terminated with a CRLF (carriage return, line feed).
    
    [asyncSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1.0 tag:0];
    
#else
    
    // Now we tell the socket to read the full header for the http response.
    // As per the http protocol, we know the header is terminated with two CRLF's (carriage return, line feed).
    
    NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    
    [_asyncSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];
    
#endif
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust
completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    NSLog(@"socket:shouldTrustPeer:");
    
    dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(bgQueue, ^{
        
        SecTrustResultType result = kSecTrustResultDeny;
        OSStatus status = SecTrustEvaluate(trust, &result);
        
        if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
            completionHandler(YES);
        }
        else {
            completionHandler(NO);
        }
    });
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
    NSLog(@"socketDidSecure:");
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"socket:didWriteDataWithTag:");
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSLog(@"socket:didReadData:withTag:");
    
    NSString *httpResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
#if READ_HEADER_LINE_BY_LINE
    
    DDLogInfo(@"Line httpResponse: %@", httpResponse);
    
    if ([data length] == 2) // 2 bytes = CRLF
    {
        DDLogInfo(@"<done>");
    }
    else
    {
        // Read the next line of the header
        [asyncSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1.0 tag:0];
    }
    
#else
    
    NSLog(@"Full HTTP Response:\n%@", httpResponse);
    
#endif
    
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{

    
    NSLog(@"socketDidDisconnect:withError: \"%@\"", err);
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
