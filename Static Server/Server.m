//
//  Server.m
//  Static Server
//
//  Created by Aaron D. Parks on 4/12/19.
//  Copyright © 2019 Parks Digital LLC. All rights reserved.
//

#import "Server.h"
#import "THFListener.h"
#import "THFSocket.h"

@interface Server () <THFSocketDelegate>

@end

@implementation Server {
    THFListener *_listener;
    NSMutableArray *_sockets;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _sockets = [NSMutableArray array];
    
    NSError *error;
    _listener = [[THFListener alloc] initWithAddress:@"127.0.0.1" port:0 backlog:128 error:&error block:^(int fd) {
        THFSocket *socket = [[THFSocket alloc] initWithFileDescriptor:fd bufferSize:1024];
        socket.delegate = self;
        socket.buffer = dispatch_data_empty;
        [self->_sockets addObject:socket];
    }];
    if (!_listener)
        [[NSAlert alertWithError:error] beginSheetModalForWindow:self.window completionHandler:nil];
    
    self.port = @(_listener.port);
}

- (IBAction)openURL:(id)sender {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%@/", self.port]];
    [NSWorkspace.sharedWorkspace openURL:url];
}

- (void)socketReceivedData:(THFSocket *)socket {
    NSLog(@"Received %ld bytes from %d", dispatch_data_get_size(socket.buffer), socket.fd);
    socket.buffer = dispatch_data_empty;
}

- (void)socketClosed:(THFSocket *)socket {
    [_sockets removeObject:socket];
}

@end
