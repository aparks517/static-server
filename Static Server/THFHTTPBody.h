//
//  THFHTTPBody.h
//  Tophat
//
//  Created by Aaron D. Parks on 9/23/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Represents the payload of an HTTP request, stored in a temporary file.
 */
@interface THFHTTPBody : NSObject

/**
 Current length of temporary file
 */
@property (readonly) NSUInteger length;

/**
 Path to temporary file
 */
@property (readonly) NSString *path;

/**
 Designated initializer
 */
- (id)init;

/**
 Append data to the temporary file
 */
- (BOOL)append:(dispatch_data_t)data;

@end
