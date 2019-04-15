//
//  THFListenerTests.m
//  TophatTests
//
//  Created by Aaron D. Parks on 11/17/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "THFListener.h"
#import <arpa/inet.h>

@interface THFListenerTests : XCTestCase
@end

@implementation THFListenerTests

- (void)testConnect {
    // Expectation
    XCTestExpectation *connectExpectation = [[XCTestExpectation alloc] initWithDescription:@"connect"];

    // Start listener
    NSError *error;
    __block int acceptedFd = -1;
    THFListener *listener = [[THFListener alloc] initWithAddress:@"127.0.0.1" port:0 backlog:1 error: &error block:^(int fd) {
        acceptedFd = fd;
        [connectExpectation fulfill];
    }];
    XCTAssertNotNil(listener);
    XCTAssertNil(error);

    // Prepare client
    struct sockaddr_in addr;
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(listener.port);
    inet_aton("127.0.0.1", &addr.sin_addr);
    int clientFd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    XCTAssertGreaterThanOrEqual(clientFd, 0);
    
    // Connect client
    int ret = connect(clientFd, (struct sockaddr *)&addr, addr.sin_len);
    XCTAssertGreaterThanOrEqual(ret, 0);

    // Test connected
    [self waitForExpectations:@[connectExpectation] timeout:0.01];
    XCTAssertGreaterThanOrEqual(acceptedFd, 0);
}

@end
