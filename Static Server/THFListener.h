//
//  THFListener.h
//  Tophat
//
//  Created by Aaron D. Parks on 9/26/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Listens on a given address and port, running a given block with the new file
 descriptor for each accepted connection.
 */
@interface THFListener : NSObject

/**
 Listening port. Contains the port specified on initialization or, if zero
 was specified, the ephemeral port that was selected.
 */
@property (readonly) unsigned short port;

/**
 Designated initializer
 @param address Address to listen on
 @param port Port to listen on, zero for ephemeral port
 @param backlog Maximum length for the queue of pending connections
 @param error Error, if any
 @param block Run with new file descriptor for each accepted connection
 */
- (id)initWithAddress:(NSString *)address
                 port:(unsigned short)port
              backlog:(int)backlog
                error:(NSError **)error
                block:(void (^)(int fd))block
NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

@end
