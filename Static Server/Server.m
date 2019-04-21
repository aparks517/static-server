//
//  Server.m
//  Static Server
//
//  Created by Aaron D. Parks on 4/12/19.
//  Copyright © 2019 Parks Digital LLC. All rights reserved.
//

#import "Server.h"
#import "THFListener.h"
#import "THFHTTPProtocol.h"
#import "THFHTTPRequest.h"
#import "THFHTTPResponse.h"

@interface Server () <THFHTTPProtocolDelegate>

@end

@implementation Server {
    NSNumber *_port;
    THFListener *_listener;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    self.port = @(0);
}

- (void)setPort:(NSNumber *)port {
    @synchronized(self) {
        _port = port;
        
        if (_listener && port.integerValue == _listener.port)
            return;
        
        NSError *error;
        __weak id weakSelf = self;
        _listener = [[THFListener alloc] initWithAddress:@"127.0.0.1" port:port.integerValue backlog:128 error:&error block:^(int fd) {
            THFSocket *socket = [[THFSocket alloc] initWithFileDescriptor:fd bufferSize:1024];
            THFHTTPProtocol *protocol = [[THFHTTPProtocol alloc] initWithSocket:socket
                                                                    maxBodySize:1024 * 1024
                                                                        timeout:5000
                                                                   errorTimeout:500];
            protocol.delegate = weakSelf;
            socket.delegate = protocol;
            socket.buffer = dispatch_data_empty;
        }];
        if (!_listener)
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSAlert alertWithError:error] beginSheetModalForWindow:self.window completionHandler:nil];
            });
        
        self.port = @(_listener.port);
    }
}

- (NSNumber *)port {
    @synchronized(self) {
        return _port;
    }
}

- (IBAction)openURL:(id)sender {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%@/", self.port]];
    [NSWorkspace.sharedWorkspace openURL:url];
}

- (void)HTTPProtocol:(THFHTTPProtocol *)protocol
     receivedRequest:(THFHTTPRequest *)request
            withBody:(THFHTTPBody *)body
{
    // Response
    THFHTTPResponse *response = [[THFHTTPResponse alloc] init];

    // Disable caching; this is a local development server, so we request
    // that the client not cache anything.
    [response setValue:@"no-cache" forHeader:@"cache-control"];

    // Only GET is supported
    if (![request.method isEqualToString:@"GET"]) {
        response.code = 405;
        response.body = [@"Only GET method is supported" dataUsingEncoding:NSUTF8StringEncoding];
        return [protocol send:response];
    }
    
    // Requested file
    NSURL *fileURL = _root;
    if (request.URI.pathComponents.count > 1) {
        NSRange range = NSMakeRange(1, request.URI.pathComponents.count - 1);
        NSArray *components = [request.URI.pathComponents subarrayWithRange:range];
        fileURL = [NSURL fileURLWithPath:[components componentsJoinedByString:@"/"] relativeToURL:_root];
    }

    // File must be inside served directory
    if (![fileURL.standardizedURL.path hasPrefix:_root.path]) {
        response.code = 403;
        response.body = [@"Requested resource outside document root" dataUsingEncoding:NSUTF8StringEncoding];
        return [protocol send:response];
    }

    // If file is a directory, append index.html
    BOOL isDirectory;
    if ([NSFileManager.defaultManager fileExistsAtPath:fileURL.path isDirectory:&isDirectory] && isDirectory)
        fileURL = [fileURL URLByAppendingPathComponent:@"index.html"];
    
    // File must exist
    if (![NSFileManager.defaultManager fileExistsAtPath:fileURL.path]) {
        response.code = 404;
        response.body = [@"File does not exist" dataUsingEncoding:NSUTF8StringEncoding];
        return [protocol send:response];
    }

    // Get Uniform Type Identifier (UTI) of file and translate to MIME type
    NSString *uti = [NSWorkspace.sharedWorkspace typeOfFile:fileURL.path error:nil];
    NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)uti, kUTTagClassMIMEType);
    [response setValue:mimeType forHeader:@"content-type"];
    
    // Send file
    response.code = 200;
    response.body = [NSData dataWithContentsOfURL:fileURL];
    [protocol send:response];
}

@end
