//
//  THFHTTPBodyTests.m
//  TophatTests
//
//  Created by Aaron D. Parks on 10/23/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "THFHTTPBody.h"

@interface THFHTTPBodyTests : XCTestCase

@end

@implementation THFHTTPBodyTests {
    THFHTTPBody *_body;
}

- (void)setUp {
    [super setUp];
    
    _body = [[THFHTTPBody alloc] init];
}

- (void)testFileCreation {
    // Check file exists at path
    XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:_body.path]);
}

- (void)testFileCleanup {
    // Capture file path and deallocate
    NSString *path = _body.path;
    _body = nil;
    
    // Check file no longer exists at path
    XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:path]);
}

@end
