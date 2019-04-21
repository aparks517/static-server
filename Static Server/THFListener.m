//
//  THFListener.m
//  Tophat
//
//  Created by Aaron D. Parks on 9/26/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import "THFListener.h"
#import <arpa/inet.h>

@implementation THFListener {
    dispatch_queue_t _queue;
    dispatch_source_t _source;
}

- (id)initWithAddress:(NSString *)address
                 port:(unsigned short)port
              backlog:(int)backlog
                error:(NSError **)error
                block:(void (^)(int))block
{
    if (!(self = [super init]))
        return nil;
    
    // Create IPv4 TCP socket
    int listenFd;
    if ((listenFd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) == -1) {
        if (error)
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        NSLog(@"Socket not created: %s (%d)", strerror(errno), errno);
        return nil;
    }
    
    // Set SO_REUSEADDR on socket (this allows the server to bind an
    // address/port combination even if it is in linger state)
    if (setsockopt(listenFd, SOL_SOCKET, SO_REUSEADDR, &(int){1}, sizeof(int)) == -1) {
        if (error)
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        NSLog(@"Socket option not set: %s (%d)", strerror(errno), errno);
        return nil;
    }
    
    // Make socket non-blocking (in case a connection is reset while
    // waiting to accept, so the event handler doesn't block.)
    if (fcntl(listenFd, F_SETFL, O_NONBLOCK) == -1) {
        if (error)
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        NSLog(@"Non-blocking flag not set: %s (%d)", strerror(errno), errno);
        return nil;
    }
    
    // Socket address (ephemeral port if port is 0)
    struct sockaddr_in addr;
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    
    // Internet address from parameter or any address if nil
    if (address) {
        const char *name = [address cStringUsingEncoding:NSASCIIStringEncoding];
        if (!inet_aton(name, &addr.sin_addr)) {
            if (error)
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            NSLog(@"Invalid address %@", address);
            return nil;
        }
    } else {
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
    }

    // Bind socket to address
    if (bind(listenFd, (struct sockaddr *)&addr, sizeof(addr))) {
        if (error)
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        NSLog(@"Socket not bound: %s (%d)", strerror(errno), errno);
        return nil;
    }
    
    // Get bound address (so selected ephemeral port can be captured)
    socklen_t addr_len = sizeof(addr);
    if (getsockname(listenFd, (struct sockaddr *)&addr, &addr_len)) {
        if (error)
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        NSLog(@"Socket address not retrieved: %s (%d)", strerror(errno), errno);
        return nil;
    }
    
    // Convert byte-order and capture bound port number
    _port = ntohs(addr.sin_port);
    
    // Listen on socket
    if (listen(listenFd, backlog) == -1) {
        if (error)
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        NSLog(@"Socket not listening: %s (%d)", strerror(errno), errno);
        return nil;
    }
    
    // Dispatch queue for accepting connections
    _queue = dispatch_queue_create("com.parksdigital.tophat.server", DISPATCH_QUEUE_SERIAL);
    
    // Dispatch source for socket readable (new connection)
    if (!(_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, listenFd, 0, _queue))) {
        if (error)
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        NSLog(@"Dispatch source not created: %s (%d)", strerror(errno), errno);
        return nil;
    }
    
    // Accept connection when socket is readable
    dispatch_source_set_event_handler(_source, ^{
        // Accept connection
        int connFd = accept(listenFd, NULL, 0);
        if (connFd == -1) {
            NSLog(@"Connection not accepted: %s (%d)", strerror(errno), errno);
            return;
        }
        
        // Disable SIGPIPE on socket file descriptor. Instead of SIGPIPE, EPIPE
        // will be returned if libdispatch tries to write to the socket after
        // it is closed. SIGPIPE would cause the program to terminate.
        if (setsockopt(connFd, SOL_SOCKET, SO_NOSIGPIPE, &(int){1}, sizeof(int)) == -1) {
            NSLog(@"Socket option not set: %s (%d)", strerror(errno), errno);
            return;
        }
        
        // Run block with new connection socket
        block(connFd);
    });
    
    // Close listening socket when dispatch source is canceled
    // (when the server is deallocated)
    dispatch_source_set_cancel_handler(_source, ^{
        close(listenFd);
    });
    
    // Enable dispatch source
    dispatch_resume(_source);
    
    return self;
}

- (void)dealloc {
    // If the listener source is set and has not been canceled, cancel it.
    // Otherwise, if the socket is set, close it.
    if (_source && !dispatch_source_testcancel(_source))
        dispatch_source_cancel(_source);
}

@end
