//
//  THFHTTPProtocol.h
//  Tophat
//
//  Created by Aaron D. Parks on 9/22/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THFSocket.h"

@class THFHTTPProtocol;
@class THFHTTPRequest;
@class THFHTTPBody;
@class THFHTTPResponse;

/**
 HTTP delegates adopt this protocol
 */
@protocol THFHTTPProtocolDelegate

/**
 Sent to delegate when a request is received from the client
 */
- (void)HTTPProtocol:(THFHTTPProtocol *)protocol
     receivedRequest:(THFHTTPRequest *)request
            withBody:(THFHTTPBody *)body;

@end

/**
 Communicates with client using the HTTP protocol. Parses incoming
 requests and delegates them. See RFC 7230, 7231, and friends.
 */
@interface THFHTTPProtocol : NSObject <THFSocketDelegate>

/**
 Delegate will receive incoming requests
 */
@property id<THFHTTPProtocolDelegate> delegate;

/**
 Designated initializer
 @param socket Socket to accept HTTP requests on
 @param maxBodySize Maximum allowed request body size
 @param timeout Maximum time to wait for a complete request before sending
                a timeout error reponse
 @param errorTimeout Maximum time to wait after sending an error response
                     before closing the socket
 */
- (id)initWithSocket:(THFSocket *)socket
         maxBodySize:(size_t)maxBodySize
             timeout:(NSTimeInterval)timeout
        errorTimeout:(NSTimeInterval)errorTimeout
    NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

/**
 Send response to client
 @param response Response to send
 */
- (void)send:(THFHTTPResponse *)response;

/**
 Send upgrade response to client
 */
- (THFSocket *)sendUpgrade:(THFHTTPResponse *)response;

@end
