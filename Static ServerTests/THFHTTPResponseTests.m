//
//  THFHTTPResponseTests.m
//  TophatTests
//
//  Created by Aaron D. Parks on 9/25/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "THFHTTPResponse.h"

@interface THFHTTPResponseTests : XCTestCase

@end

@implementation THFHTTPResponseTests

- (void)testDefaultResponse {
    // Default response
    THFHTTPResponse *res = [[THFHTTPResponse alloc] init];

    // Check encoded response
    NSString *actual = [[NSString alloc] initWithBytes:[(id)res.data bytes]
                                                length:[(id)res.data length]
                                              encoding:NSUTF8StringEncoding];
    NSString *expected =
    @"HTTP/1.1 204 No Content\r\n"
    @"\r\n";
    XCTAssertEqualObjects(actual, expected);
}

- (void)testErrorResponse {
    // Response with error
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"description",
                               NSLocalizedFailureReasonErrorKey: @"reason"};
    NSError *error = [[NSError alloc] initWithDomain:@"domain"
                                                code:123
                                            userInfo:userInfo];
    THFHTTPResponse *res = [[THFHTTPResponse alloc] initWithError:error status:500];
    
    // Check encoded response
    NSString *actual = [[NSString alloc] initWithBytes:[(id)res.data bytes]
                                                length:[(id)res.data length]
                                              encoding:NSUTF8StringEncoding];
    NSString *expected =
    @"HTTP/1.1 500 Internal Server Error\r\n"
    @"content-length: 19\r\n"
    @"\r\n"
    @"description: reason";
    XCTAssertEqualObjects(actual, expected);
}

- (void)testComplexResponse {
    // Response with header and body
    THFHTTPResponse *res = [[THFHTTPResponse alloc] init];
    res.code = 200;
    res.headerFields[@"x-test"] = @"test";
    res.body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
    
    // Check encoded response
    NSString *actual = [[NSString alloc] initWithBytes:[(id)res.data bytes]
                                                length:[(id)res.data length]
                                              encoding:NSUTF8StringEncoding];
    NSString *expected =
    @"HTTP/1.1 200 OK\r\n"
    @"content-length: 4\r\n"
    @"x-test: test\r\n"
    @"\r\n"
    @"body";
    XCTAssertEqualObjects(actual, expected);
}

@end
