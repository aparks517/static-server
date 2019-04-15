//
//  THFHTTPRequestTests.m
//  THFHTTPRequestTests
//
//  Created by Aaron D. Parks on 9/22/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "THFHTTPRequest.h"

@interface THFHTTPRequestTests : XCTestCase

@end

@implementation THFHTTPRequestTests

- (void)testLengthNone {
    NSData *data = [@"GET / HTTP/1.0\r\n"
                    @"Accept: text/html\r\n"
                    dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertEqual([THFHTTPRequest requestLength:dispatch_data_create(data.bytes, data.length, NULL, nil)], 0);
}

- (void)testLengthMultiple {
    NSData *data = [@"GET / HTTP/1.0\r\n\r\n"
                    @"GET / HTTP/1.0\r\n\r\n"
                    dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertEqual([THFHTTPRequest requestLength:dispatch_data_create(data.bytes, data.length, NULL, nil)], 18);
}

- (void)testLengthSplit {
    NSData *first = [@"GET / HTTP/1.0\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *second = [@"\r\nGET / HTTP/1.0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    
    XCTAssertEqual([THFHTTPRequest requestLength:dispatch_data_create_concat(dispatch_data_create(first.bytes, first.length, NULL, nil),
                                                                             dispatch_data_create(second.bytes, second.length, NULL, nil))], 18);
}

- (void)testSimple {
    NSData *data = [@"GET / HTTP/1.0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    THFHTTPRequest *req = [[THFHTTPRequest alloc] initWithData:dispatch_data_create(data.bytes, data.length, NULL, nil) error:&error];
    
    XCTAssertEqualObjects(req.method, @"GET");
    XCTAssertEqualObjects(req.URI, [NSURL URLWithString:@"/"]);
    XCTAssertEqual(req.majorVersion, 1);
    XCTAssertEqual(req.minorVersion, 0);
}

- (void)testComplex {
    NSData *data = [@"GET / HTTP/1.1\r\n"
                    @"Accept: text/html\r\n"
                    @"User-agent: test\r\n"
                    @"Accept: image/png\r\n\r\n"
                    dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    THFHTTPRequest *req = [[THFHTTPRequest alloc] initWithData:dispatch_data_create(data.bytes, data.length, NULL, nil) error:&error];

    XCTAssertEqualObjects(req.method, @"GET");
    XCTAssertEqualObjects(req.URI, [NSURL URLWithString:@"/"]);
    XCTAssertEqual(req.majorVersion, 1);
    XCTAssertEqual(req.minorVersion, 1);
    XCTAssertEqualObjects(req.headerFields[@"accept"], @"text/html,image/png");
    XCTAssertEqualObjects(req.headerFields[@"user-agent"], @"test");
}

// TODO: test parse errors

@end
