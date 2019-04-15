//
//  THFSocketTests.m
//  TophatTests
//
//  Created by Aaron D. Parks on 10/16/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "THFSocket.h"
#import <sys/socket.h>

@interface THFSocketTests : XCTestCase <THFSocketDelegate>

@end

@implementation THFSocketTests {
    int _socketFd, _testFd;
    THFSocket *_socket;
    XCTestExpectation *_receivedExpectation, *_closedExpectation;
    BOOL _closed;
}

- (void)setUp {
    [super setUp];
    
    // Set up a pair of sockets for testing
    int sockets[2];
    XCTAssertEqual(socketpair(AF_LOCAL, SOCK_STREAM, 0, sockets), 0);
    _socketFd = sockets[0];
    _testFd = sockets[1];
    XCTAssertEqual(setsockopt(_socketFd, SOL_SOCKET, SO_NOSIGPIPE, &(int){1}, sizeof(int)), 0);
    
    // Socket
    _socket = [[THFSocket alloc] initWithFileDescriptor:_socketFd bufferSize:1024];
    _socket.delegate = self;
    _socket.buffer = dispatch_data_empty;

    // Expectations
    _receivedExpectation = [[XCTestExpectation alloc] initWithDescription:@"received"];
    _closedExpectation = [[XCTestExpectation alloc] initWithDescription:@"closed"];
}

- (void)testReceive {
    // Send test to socket
    const char expected[] = "test";
    XCTAssertTrue(write(_testFd, expected, sizeof(expected)));
    
    
    // Check that socket received
    [self waitForExpectations:@[_receivedExpectation] timeout:0.01];
    const void *received;
    size_t received_len;
    dispatch_data_t data = dispatch_data_create_map(_socket.buffer, &received, &received_len);
    XCTAssertEqual(received_len, sizeof(expected));
    XCTAssertFalse(strncmp(received, expected, received_len));
    data = nil;
}

- (void)testSend {
    // Send test through socket
    const char expected[] = "test";
    dispatch_data_t data = dispatch_data_create(expected, sizeof(expected), NULL, nil);
    [_socket write:data];
    
    // Read
    char received[sizeof(expected)];
    XCTAssertEqual(read(_testFd, received, sizeof(expected)), sizeof(expected));
    XCTAssertFalse(strncmp(received, expected, sizeof(expected)));
}

- (void)testClose {
    // Confirm socket is not yet closed
    XCTAssertFalse(_closed);

    // Close socket file descriptor
    XCTAssertEqual(close(_testFd), 0);

    // Confirm socket is now closed
    [self waitForExpectations:@[_closedExpectation] timeout:0.01];
    XCTAssertTrue(_closed);
}

/**
 Socket delegate received data stub
 */
- (void)socketReceivedData:(THFSocket *)socket {
    [_receivedExpectation fulfill];
}

/**
 Socket delegate closed stub
 */
- (void)socketClosed:(THFSocket *)socket {
    _closed = YES;
    [_closedExpectation fulfill];
}

@end
