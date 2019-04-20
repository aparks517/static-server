//
//  THFHTTPBody.m
//  Tophat
//
//  Created by Aaron D. Parks on 9/23/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import "THFHTTPBody.h"

@implementation THFHTTPBody {
    int _fd;
}

+ (void)initialize {
    if (self != [THFHTTPBody self])
        return;
    
    // Clean up temporary files (normally cleaned up on deallocation, but
    // can be left behind if deallocation doesn't happen -- program ends
    // abruptly, for example)
    for (NSString *file in [NSFileManager.defaultManager enumeratorAtPath:NSTemporaryDirectory()]) {
        // Skip if not a body temporary file
        if (![file hasPrefix:@"body-"])
            continue;
        
        // Try to remove or report error
        NSError *error;
        if (![NSFileManager.defaultManager removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:file] error:&error])
            NSLog(@"Could not remove temporary file %@: %@ (%@)", file,
                  error.localizedDescription, error.localizedFailureReason);
    }
}

- (id)init {
    if (!(self = [super init]))
        return nil;

    // Template for file in temporary directory copied to mutable C string on stack
    const char *template = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"body-XXXXXX"] cStringUsingEncoding:NSUTF8StringEncoding];
    char *path = alloca(strlen(template));
    strcpy(path, template);

    // Create and open temporary file
    _fd = mkstemp(path);
    if (_fd < 0) {
        NSLog(@"Could not create temporary file: %s (%d)", strerror(errno), errno);
        return nil;
    }
    
    // Capture temporary file name
    _path = [NSString stringWithCString:path encoding:NSUTF8StringEncoding];
    
    return self;
}

- (void)dealloc {
    // Close and unlink temporary file if open
    if (_fd >= 0) {
        if (close(_fd))
            NSLog(@"Could not close temporary file %@: %s", _path, strerror(errno));
        
        NSError *error;
        if (![NSFileManager.defaultManager removeItemAtPath:_path error:&error])
        {
            NSLog(@"Could not remove temporary file %@: %@ (%@)", _path,
                  error.localizedDescription, error.localizedFailureReason);
        }
    }
}

- (NSUInteger)length {
    return lseek(_fd, 0, SEEK_CUR);
}

- (BOOL)append:(dispatch_data_t)data {
    // Seek to end of file
    lseek(_fd, 0, SEEK_END);

    // Write each data region
    return dispatch_data_apply(data, ^bool(dispatch_data_t _Nonnull region, size_t offset, const void * _Nonnull buffer, size_t size) {
        ssize_t ret = write(self->_fd, buffer, size);
        if (ret < 0) {
            NSLog(@"Could not write to temporary file %@: %s",
                  self->_path, strerror(errno));
            return NO;
        } else if (ret < size) {
            NSLog(@"Could not complete write to temporary file %@",
                  self->_path);
            return NO;
        }
        return YES;
    });
}

@end
