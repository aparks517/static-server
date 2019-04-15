//
//  THFHTTPRequest.h
//  Tophat
//
//  Created by Aaron D. Parks on 9/22/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class THFHTTPBody;

/**
 Represents an HTTP request-line and headers. Can parse from dispatch data.
 */
@interface THFHTTPRequest : NSObject

/**
 Find the length of the first request in data
 @return Length of first request or zero if indeterminable
 */
+ (size_t)requestLength:(dispatch_data_t)data;

/**
 HTTP method
 */
@property NSString *method;

/**
 Target resource URI
 */
@property NSURL *URI;

/**
 Major HTTP version
 */
@property NSInteger majorVersion;

/**
 Minor HTTP version
 */
@property NSInteger minorVersion;

/**
 Header fields. Keys are lower-cased.
 */
@property NSMutableDictionary<NSString *, NSString *> *headerFields;

/**
 Request body
 */
@property THFHTTPBody *body;

/**
 Parse request from data
 */
- (id)initWithData:(dispatch_data_t)data error:(NSError **)error;

@end
