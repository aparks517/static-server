//
//  THFHTTPProtocolTests.m
//  TophatTests
//
//  Created by Aaron D. Parks on 9/23/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "THFHTTPProtocol.h"
#import "THFHTTPRequest.h"
#import "THFHTTPBody.h"
#import "THFHTTPResponse.h"

#pragma mark Socket fake

@interface THFHTTPProtocolTestsSocket : THFSocket

@property NSMutableData *written;
@property XCTestExpectation *writeExpectation;
@property XCTestExpectation *closeExpectation;

- (id)init;

@end

@implementation THFHTTPProtocolTestsSocket

- (id)init {
    self.written = [NSMutableData data];
    self.writeExpectation = [[XCTestExpectation alloc] initWithDescription:@"write"];
    self.closeExpectation = [[XCTestExpectation alloc] initWithDescription:@"close"];
    self.buffer = dispatch_data_empty;
    return self;
}

- (size_t)bufferSize {
    return 1024;
}

- (void)write:(dispatch_data_t)data {
    [self.written appendBytes:[(id)data bytes] length:[(id)data length]];
    [self.writeExpectation fulfill];
}

- (void)close {
    [self.closeExpectation fulfill];
}

@end

#pragma mark Tests

@interface THFHTTPProtocolTests : XCTestCase <THFHTTPProtocolDelegate>

@end

@implementation THFHTTPProtocolTests {
    THFHTTPProtocolTestsSocket *_socket;
    THFHTTPProtocol *_proto;
    XCTestExpectation *_delegationExpectation;
    THFHTTPRequest *_delegatedRequest;
    THFHTTPBody *_delegatedBody;
}

- (void)setUp {
    [super setUp];
    
    _socket = [[THFHTTPProtocolTestsSocket alloc] init];

    _proto = [[THFHTTPProtocol alloc] initWithSocket:_socket
                                         maxBodySize:1024
                                             timeout:0.2
                                        errorTimeout:0.1];
    _proto.delegate = self;

    _delegationExpectation = [[XCTestExpectation alloc] initWithDescription:@"delegation"];
}

- (void)testRequestTimeout {
    // Wait for request timeout
    [self waitForExpectations:@[_socket.closeExpectation] timeout:0.25];
}

- (void)testErrorTimeout {
    // Prepare request data in socket buffer and notify protocol
    NSData *data = [@"GET / HTTP/9.9\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    _socket.buffer = dispatch_data_create(data.bytes, data.length, NULL, nil);
    [_proto socketReceivedData:_socket];

    // Wait for write and check response
    [self waitForExpectations:@[_socket.writeExpectation] timeout:0.01];
    NSString *expected =
    @"HTTP/1.1 505 HTTP Version Not Supported\r\n"
    @"content-length: 53\r\n\r\n"
    @"Could not validate request: Unsupported major version";
    NSString *actual = [[NSString alloc] initWithData:_socket.written encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(actual, expected);

    // Wait for error timeout
    [self waitForExpectations:@[_socket.closeExpectation] timeout:0.15];
}

// TODO: test socket close

- (void)testSimple {
    // Prepare request data in socket buffer and notify protocol
    NSData *data = [@"GET / HTTP/1.1\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    _socket.buffer = dispatch_data_create(data.bytes, data.length, NULL, nil);
    [_proto socketReceivedData:_socket];
    
    // Wait for delegation and check request
    [self waitForExpectations:@[_delegationExpectation] timeout:0.01];
    XCTAssertEqualObjects(_delegatedRequest.method, @"GET");
    XCTAssertEqualObjects(_delegatedRequest.URI, [NSURL URLWithString:@"/"]);
}

- (void)testExpectContinue {
    // Prepare request data in socket buffer and notify protocol
    NSData *data = [@"PUT / HTTP/1.1\r\n"
                    @"Content-length: 4\r\n"
                    @"Expect: 100-continue\r\n"
                    @"\r\n"
                    @"test"
                    dataUsingEncoding:NSUTF8StringEncoding];
    _socket.buffer = dispatch_data_create(data.bytes, data.length, NULL, nil);
    [_proto socketReceivedData:_socket];
    
    // Wait for write and check response
    [self waitForExpectations:@[_socket.writeExpectation] timeout:0.01];
    NSString *expected =
    @"HTTP/1.1 100 Continue\r\n\r\n"
    @"HTTP/1.1 204 No Content\r\n\r\n";
    NSString *actual = [[NSString alloc] initWithData:_socket.written encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(actual, expected);
}

- (void)testPlainBody {
    // Prepare request data in socket buffer and notify protocol
    NSData *data = [@"PUT / HTTP/1.1\r\n"
                    @"Content-type: text/plain\r\n"
                    @"Content-length: 4\r\n"
                    @"\r\n"
                    @"test"
                    dataUsingEncoding:NSUTF8StringEncoding];
    _socket.buffer = dispatch_data_create(data.bytes, data.length, NULL, nil);
    [_proto socketReceivedData:_socket];

    // Wait for delegation and check
    [self waitForExpectations:@[_delegationExpectation] timeout:0.01];
    XCTAssertEqual(_delegatedBody.length, 4);
}

- (void)testMultipleRequests {
    // Two delegations will be expected
    _delegationExpectation.expectedFulfillmentCount = 2;

    // Prepare requests in socket buffer and notify protocol
    NSData *data = [@"GET / HTTP/1.1\r\n\r\n"
                    @"GET / HTTP/1.1\r\n\r\n"
                    dataUsingEncoding:NSUTF8StringEncoding];
    _socket.buffer = dispatch_data_create(data.bytes, data.length, NULL, nil);
    [_proto socketReceivedData:_socket];
    
    // Wait for delegations
    [self waitForExpectations:@[_delegationExpectation] timeout:0.01];
}

- (void)testPerformance {
    // Prepare requests
    NSData *data = [@"GET / HTTP/1.1\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    dispatch_data_t dd = dispatch_data_empty;
    for (NSUInteger i = 0; i < 1000; i++) {
        dd = dispatch_data_create_concat(dd, dispatch_data_create(data.bytes, data.length, NULL, nil));
    }

    // Send requests and wait for responses
    [self measureBlock:^{
        self->_socket.buffer = dd;
        [self->_proto socketReceivedData:self->_socket];
    }];
}

#pragma mark Delegate stub

- (void)HTTPProtocol:(THFHTTPProtocol *)protocol
     receivedRequest:(THFHTTPRequest *)request
            withBody:(THFHTTPBody *)body
{
    _delegatedRequest = request;
    _delegatedBody = body;
    [protocol send:[[THFHTTPResponse alloc] init]];
    [_delegationExpectation fulfill];
}

@end
