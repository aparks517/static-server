//
//  THFHTTPResponse.h
//  Tophat
//
//  Created by Aaron D. Parks on 9/25/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 An HTTP response
 */
@interface THFHTTPResponse : NSObject 

/**
 Header fields
 */
@property NSMutableDictionary<NSString *, NSString *> *headerFields;

/**
 Status code
 */
@property NSUInteger code;

/**
 Body data
 */
@property NSData *body;

/**
 Encoded response data, ready to send to client
 */
@property (readonly) dispatch_data_t data;

/**
 Convenience initializer to prepare error response
 @param error Error object to get message from
 @param code Status code to use
 */
- (id)initWithError:(NSError *)error status:(NSUInteger)code;

/**
 Set header field value. Creates if not present, replaces otherwise.
 @param value Value to set
 @param name Name of header field to set
 */
- (void)setValue:(NSString *)value forHeader:(NSString *)name;

@end
