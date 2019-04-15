//
//  THFSocket.h
//  Tophat
//
//  Created by Aaron D. Parks on 11/12/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class THFSocket;

/**
 Socket delegates must adopt this protocol
 */
@protocol THFSocketDelegate

/**
 Called when data is received from the client. The delagate should remove
 any consumed data from the buffer, allowing more data to be read from the
 client.
 @param socket The socket that received data
 */
- (void)socketReceivedData:(THFSocket *)socket;

/**
 Called when the socket has closed
 @param socket The socket that closed
 */
- (void)socketClosed:(THFSocket *)socket;

@end

/**
 Manages a socket, reading incoming data until the buffer is full and notifying
 the delegate as data is received and when the socket closes. Also allows
 sending data asynchronously. After setting a delegate, set the buffer to
 dispatch_data_empty to start reading data from the client into the buffer.
 */
@interface THFSocket : NSObject

@property (readonly) int fd;

/**
 Maximum buffer size
 */
@property (readonly) size_t bufferSize;

/**
 Socket delegate
 */
@property (weak) id<THFSocketDelegate> delegate;

/**
 Received data is appended to this buffer. Upon consuming, delegate must
 replace it with unconsumed portion or empty data. On a new socket, set
 to empty data to start reading.
 */
@property (nonatomic) dispatch_data_t buffer;

/**
 Designated initializer
 @param fd Socket file descriptor to manage
 @param bufferSize Maximum buffer size
 */
- (id)initWithFileDescriptor:(int)fd
                  bufferSize:(size_t)bufferSize
    NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

/**
 Send data to the client
 */
- (void)write:(dispatch_data_t)data;

/**
 Close the socket and stop any outstanding I/O operations
 */
- (void)close;

@end
