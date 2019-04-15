//
//  THFHTTPRequest.m
//  Tophat
//
//  Created by Aaron D. Parks on 9/22/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import "THFHTTPRequest.h"

#import "THFHTTPBody.h"
#import "NSError+THFHTTPError.h"

@implementation THFHTTPRequest

+ (size_t)requestLength:(dispatch_data_t)data {
    // Return early if data is nil
    if (!data)
        return 0;
    
    // Request ends in double CRLF
    const char *search = "\r\n\r\n";
    const size_t searchLen = strlen(search);
    
    // Iterate data regions looking for search string, which may span regions
    __block size_t requestLength = 0, searchOffset = 0;
    dispatch_data_apply(data, ^bool(dispatch_data_t  _Nonnull region, size_t offset, const void * _Nonnull buffer, size_t size) {
        for (size_t i = 0; i < size; i++) {
            if (((const char *)buffer)[i] != search[searchOffset]) {
                searchOffset = 0;
                continue;
            }
            searchOffset++;
            if (searchOffset >= searchLen) {
                requestLength = offset + i + 1;
                return NO;
            }
        }
        return YES;
    });
    
    return requestLength;
}

- (id)init {
    if (!(self = [super init]))
        return nil;
    
    _headerFields = [NSMutableDictionary dictionary];
    
    return self;
}

- (id)initWithData:(dispatch_data_t)data error:(NSError **)error {
    if (!(self = [self init]))
        return nil;
    
    // TODO: return NSError with parse error details
    
    // Make data contiguous and get pointer to and length of region
    const void *buffer;
    size_t length;
    data = dispatch_data_create_map(data, &buffer, &length);
    
    // String from data
    NSString *string = [[NSString alloc] initWithBytes:buffer length:length encoding:NSASCIIStringEncoding];
    
    // Lines from string. If there is not at least a request-line, return nil
    NSArray *lines = [string componentsSeparatedByString:@"\r\n"];
    if ([lines count] < 3) {
        *error = [NSError THFHTTPErrorWithStatus:400
                                     description:@"Could not parse request line"
                                          reason:@"Not present"];
        return nil;
    }
    
    // Request line is first line. Parts are separated by space and must be
    // method, URI, and version
    NSArray *requestLineParts = [lines[0] componentsSeparatedByString:@" "];
    if (requestLineParts.count != 3) {
        *error = [NSError THFHTTPErrorWithStatus:400
                                     description:@"Could not parse request line"
                                          reason:@"Wrong number of parts"];
        return nil;
    }
    _method = requestLineParts[0];
    _URI = [NSURL URLWithString:requestLineParts[1]];
    NSString *version = requestLineParts[2];

    // Version is like "HTTP/x.y" where x and y are each one digit
    if (version.length != 8 ||
        ![[version substringToIndex:5] isEqualToString:@"HTTP/"] ||
        [version characterAtIndex:5] < '0' ||
        [version characterAtIndex:5] > '9' ||
        [version characterAtIndex:6] != '.' ||
        [version characterAtIndex:7] < '0' ||
        [version characterAtIndex:7] > '9')
    {
        *error = [NSError THFHTTPErrorWithStatus:400
                                     description:@"Could not parse request line"
                                          reason:@"Bad version part"];
        return nil;
    }
    _majorVersion = [version characterAtIndex:5] - '0';
    _minorVersion = [version characterAtIndex:7] - '0';
    
    
    // First line is request-line, last two lines are empty. Lines in
    // between are header fields.
    NSRange headerFieldLinesRange = NSMakeRange(1, lines.count - 3);
    NSArray *headerFieldLines = [lines subarrayWithRange:headerFieldLinesRange];

    // Parse header fields to dictionary
    for (NSString *line in headerFieldLines) {
        // Whitespace character set
        NSCharacterSet *whitespace = NSCharacterSet.whitespaceCharacterSet;
        
        // Field name and field value are separated by colon
        NSRange colonRange = [line rangeOfString:@":"];
        if (colonRange.location == NSNotFound) {
            *error = [NSError THFHTTPErrorWithStatus:400
                                         description:@"Could not parse header"
                                              reason:@"No separator"];
            return nil;
        }
        
        // Name cannot contain whitespace. Case-insensitive, so normalize
        // to lowercase to use as dictionary keys.
        NSRange nameRange = NSMakeRange(0, colonRange.location);
        NSString *name = [line substringWithRange:nameRange].lowercaseString;
        if ([name rangeOfCharacterFromSet:whitespace].location != NSNotFound) {
            *error = [NSError THFHTTPErrorWithStatus:400
                                         description:@"Could not parse header"
                                              reason:@"Whitespace in name"];
            return nil;
        }
        
        // Value may have optional whitespace before and after
        NSRange valueRange = NSMakeRange(NSMaxRange(colonRange), line.length - NSMaxRange(colonRange));
        NSString *value = [[line substringWithRange:valueRange] stringByTrimmingCharactersInSet: whitespace];

        // If there is an existing value for this header name, append
        _headerFields[name] = _headerFields[name] ? [_headerFields[name] stringByAppendingFormat:@",%@", value] : value;
    }
    
    return self;
}

@end
