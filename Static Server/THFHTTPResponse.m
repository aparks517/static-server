//
//  THFHTTPResponse.m
//  Tophat
//
//  Created by Aaron D. Parks on 9/25/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import "THFHTTPResponse.h"

static NSDictionary *reasons;

@implementation THFHTTPResponse {
    NSMutableDictionary *_headerFields;
}

+ (void)initialize {
    reasons = @{@100: @"Continue",
                @101: @"Switching Protocols",
                @200: @"OK",
                @201: @"Created",
                @202: @"Accepted",
                @203: @"Non-Authoritative Information",
                @204: @"No Content",
                @205: @"Reset Content",
                @206: @"Partial Content",
                @300: @"Multiple Choices",
                @301: @"Moved Permanently",
                @302: @"Found",
                @303: @"See Other",
                @304: @"Not Modified",
                @305: @"Use Proxy",
                @307: @"Temporary Redirect",
                @400: @"Bad Request",
                @401: @"Unauthorized",
                @402: @"Payment Required",
                @403: @"Forbidden",
                @404: @"Not Found",
                @405: @"Method Not Allowed",
                @406: @"Not Acceptable",
                @408: @"Request Timeout",
                @409: @"Conflict",
                @410: @"Gone",
                @411: @"Length Required",
                @412: @"Precondition Failed",
                @413: @"Request Entity Too Large",
                @415: @"Unsupported Media Type",
                @416: @"Requested Range Not Satisfiable",
                @417: @"Expectation Failed",
                @426: @"Upgrade Required",
                @500: @"Internal Server Error",
                @501: @"Not Implemented",
                @503: @"Service Unavailable",
                @505: @"HTTP Version Not Supported"};
}

- (id)init {
    if (!(self = [super init]))
        return nil;
    
    _code = 204;
    _headerFields = [NSMutableDictionary dictionary];
    
    return self;
}

- (id)initWithError:(NSError *)error status:(NSUInteger)code {
    if (!(self = [self init]))
        return nil;
    
    _body = [[NSString stringWithFormat:@"%@: %@",
              error.userInfo[NSLocalizedDescriptionKey],
              error.userInfo[NSLocalizedFailureReasonErrorKey]]
             dataUsingEncoding:NSUTF8StringEncoding];
    _code = code;

    return self;
}

- (dispatch_data_t)data {
    // The semantics of certain status codes are that no payload will be included
    BOOL includePayload = _code != 205 && _code != 204 && _code != 101 && _code != 100;
    
    // Set content-length if payload will be included
    if (includePayload)
        [self setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[_body length]] forHeader:@"content-length"];
    
    // Flatten headers dictionary to array
    NSMutableArray *headerFieldArray = [NSMutableArray arrayWithCapacity:_headerFields.count];
    for (NSString *key in [_headerFields.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        // Convert CR and LF to spaces in keys and values
        NSString *strippedKey = [[key stringByReplacingOccurrencesOfString:@"\r" withString:@" "]
                                 stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        NSString *strippedValue = [[_headerFields[key] stringByReplacingOccurrencesOfString:@"\r" withString:@" "]
                                   stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

        // Trim whitespace from around key
        NSString *trimmedKey = [strippedKey stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];

        // Add stripped, trimmed, and formatted string to header array
        [headerFieldArray addObject:[NSString stringWithFormat:@"%@: %@", trimmedKey, strippedValue]];
    }
    
    // Response string, starting with status line
    NSMutableString *responseString =
    [NSMutableString stringWithFormat:@"HTTP/1.1 %03lu %@\r\n", (unsigned long)_code, reasons[@(_code)]];
    
    // Add formatted header fields, if any, to response string
    if (headerFieldArray.count)
        [responseString appendFormat:@"%@\r\n", [headerFieldArray componentsJoinedByString:@"\r\n"]];
    
    // Second CRLF before body (if any)
    [responseString appendString:@"\r\n"];
    
    // Encode response string as ASCII
    NSMutableData *responseData = [[responseString dataUsingEncoding:NSASCIIStringEncoding] mutableCopy];
    
    // Append body to response data if payload will be included
    if (includePayload)
        [responseData appendData:_body];
    
    // Dispatch data from NSData
    CFDataRef cfdr = CFBridgingRetain(responseData);
    dispatch_data_t dd = dispatch_data_create(CFDataGetBytePtr(cfdr), CFDataGetLength(cfdr), NULL, ^{ CFRelease(cfdr); });

    return dd;
}

- (void)setValue:(NSString *)value forHeader:(NSString *)name {
    [_headerFields setObject:value forKey:name];
}

@end
