//
//  THFHTTPProtocol.m
//  Tophat
//
//  Created by Aaron D. Parks on 9/22/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import "THFHTTPProtocol.h"
#import "THFHTTPRequest.h"
#import "THFHTTPBody.h"
#import "THFHTTPResponse.h"

static NSString * const THFHTTPProtocolErrorDomain = @"THFHTTPProtocolErrorDomain";

@implementation THFHTTPProtocol {
    THFSocket *_socket;
    size_t _maxBodySize;
    NSTimeInterval _timeout, _errorTimeout;

    NSTimer *_timer;
    THFHTTPRequest *_request;
    THFHTTPBody *_body;
    BOOL _dispatched;
}

- (id)initWithSocket:(THFSocket *)socket
         maxBodySize:(size_t)maxBodySize
             timeout:(NSTimeInterval)timeout
        errorTimeout:(NSTimeInterval)errorTimeout
{
    if (!(self = [super init]))
        return nil;

    _socket = socket;
    _maxBodySize = maxBodySize;
    _timeout = timeout;
    _errorTimeout = errorTimeout;
    
    [self setTimer:timeout];
    socket.delegate = self;
    
    return self;
}

- (void)socketReceivedData:(THFSocket *)socket {
    // If there's not a request already decoded, try to get one from the buffer
    if (!_request) {
        // If there's not a whole request in the buffer, return early
        // unless the buffer is also full, in which case return error
        size_t reqLen = [THFHTTPRequest requestLength:socket.buffer];
        if (!reqLen && dispatch_data_get_size(socket.buffer) >= socket.bufferSize)
            return [self sendError:[NSError errorWithDomain:THFHTTPProtocolErrorDomain
                                                       code:400
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Could not read request",
                                                              NSLocalizedFailureReasonErrorKey: @"Too long"
                                                              }]];
        else if (!reqLen)
            return;

        // Get request data from socket buffer and put back the remainder
        dispatch_data_t reqData = dispatch_data_create_subrange(socket.buffer, 0, reqLen);
        _socket.buffer = dispatch_data_create_subrange(socket.buffer, reqLen, SIZE_MAX);

        // Decode the request or send error and return early
        NSError *error;
        if (!(_request = [[THFHTTPRequest alloc] initWithData:reqData error:&error]))
            return [self sendError:error];
        
        // Only HTTP 1 is supported
        if (_request.majorVersion != 1)
            return [self sendError:[NSError errorWithDomain:THFHTTPProtocolErrorDomain
                                                       code:505
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Could not validate request",
                                                              NSLocalizedFailureReasonErrorKey: @"Unsupported major version"
                                                              }]];
        
        // TODO: check that the host header is valid

        // Transfer encoding not supported (client should specify content-length instead)
        if (_request.headerFields[@"transfer-encoding"])
            return [self sendError:[NSError errorWithDomain:THFHTTPProtocolErrorDomain
                                                       code:411
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Could not validate request",
                                                              NSLocalizedFailureReasonErrorKey: @"Transfer encoding not supported"
                                                              }]];
        
        // Maximum body size
        if (_request.headerFields[@"content-length"].integerValue > _maxBodySize)
            return [self sendError:[NSError errorWithDomain:THFHTTPProtocolErrorDomain
                                                       code:413
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Could not validate request",
                                                              NSLocalizedFailureReasonErrorKey: @"Payload too large"
                                                              }]];
        
        // If client expects Continue, provide it
        if ([_request.headerFields[@"expect"] isEqualToString:@"100-continue"] && _request.minorVersion >= 1) {
            THFHTTPResponse *response = [[THFHTTPResponse alloc] init];
            response.code = 100;
            [_socket write:response.data];
        }
    }

    // If additional request payload is expected, apply buffer to body up to expected length
    // TODO: support chunked encoding
    if (_request.headerFields[@"content-length"].integerValue > _body.length) {
        // Initialize body if not already
        if (!_body)
            _body = [[THFHTTPBody alloc] init];
        
        // Get data from buffer up to expected body length
        size_t expected = _request.headerFields[@"content-length"].integerValue - _body.length;
        dispatch_data_t bodyData = dispatch_data_create_subrange(_socket.buffer, 0, expected);
        _socket.buffer = dispatch_data_create_subrange(_socket.buffer, expected, SIZE_MAX);
        
        // Append data to body, checking for error
        if (![_body append:bodyData])
            [self sendError:[NSError errorWithDomain:THFHTTPProtocolErrorDomain
                                                code:0
                                            userInfo:@{NSLocalizedDescriptionKey: @"Could not accept payload",
                                                       NSLocalizedFailureReasonErrorKey: @"Error storing body data"
                                                       }]];
    }
    
    // If request is parsed and no additional payload is expected, dispatch
    if (!_dispatched && _request && _body.length <= _request.headerFields[@"content-length"].integerValue) {
        _dispatched = YES;
        [_delegate HTTPProtocol:self receivedRequest:_request withBody:_body];
    }
}

- (void)socketClosed:(THFSocket *)socket {
    // Invalidate timer, breaking retain cycle that prevents deallocation
    [self invalidateTimer];
}


- (void)send:(THFHTTPResponse *)response
{
    // Reset request and body and dispatched flag, send response to client, process socket buffer
    _request = nil;
    _body = nil;
    _dispatched = NO;
    [_socket write:response.data];
    if (_socket)
        [self socketReceivedData:_socket];
}

- (THFSocket *)sendUpgrade:(THFHTTPResponse *)response {
    // Clear self from socket delegate, send response, invalidate timer
    // (allowing deallocation of this instance), and return socket
    _socket.delegate = nil;
    [_socket write:response.data];
    [self invalidateTimer];
    return _socket;
}

/**
 Send error response and start error timeout to close socket
 */
- (void)sendError:(NSError *)error {
    // Default error status is 500, but request parse errors are the result
    // of client errors (status 400) and protocol errors have the status in
    // the error code property
    NSUInteger code = 500;
    if (error.domain == THFHTTPRequestErrorDomain)
        code = 400;
    else if (error.domain == THFHTTPProtocolErrorDomain)
        code = error.code;
    
    // Send error message and reset timer for error timeout
    [_socket write:[[THFHTTPResponse alloc] initWithError:error status:code].data];
    [self setTimer:_errorTimeout];
}

/**
 Set the timer, invalidating first if it is already running. This creates
 a retain cycle between this instance and the timer.
 @param interval Interval to set on the timer
 */
- (void)setTimer:(NSTimeInterval)interval {
    // Timer is scheduled on main thread's run loop
    dispatch_async(dispatch_get_main_queue(), ^{
        // If timer is already scheduled, invalidate
        if (self->_timer)
            [self->_timer invalidate];
        
        // Schedule timer
        self->_timer =
        [NSTimer scheduledTimerWithTimeInterval:interval
                                         target:self
                                       selector:@selector(timeout:)
                                       userInfo:nil
                                        repeats:NO];
    });
}

/**
 Timeout handler.
 */
- (void)timeout:(id)userInfo {
    // Close socket and invalidate timer. This timeout fires when an error
    // has been sent and the client has not closed the connection before
    // the error timeout or when the client has not sent a complete request
    // before the request timeout. No error is sent for the request timeout,
    // otherwise the client might send a request during the error timeout
    // and get confused because it had not read the timeout error 😳
    [_socket close];
    _socket = nil;
    [self invalidateTimer];
}

/**
 Invalidate the timer, breaking the retain cycle and allowing this instance
 to deallocate
 */
- (void)invalidateTimer {
    // Timer is scheduled on main thread's run loop, so invalidation must
    // happen on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_timer invalidate];
        self->_timer = nil;
    });
}

@end
