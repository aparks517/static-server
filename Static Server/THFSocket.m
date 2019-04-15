//
//  THFSocket.m
//  Tophat
//
//  Created by Aaron D. Parks on 11/12/18.
//  Copyright © 2018 Parks Digital LLC. All rights reserved.
//

#import "THFSocket.h"

@implementation THFSocket {
    int _fd;
    dispatch_data_t _buffer;
    dispatch_queue_t _queue;
    dispatch_io_t _io;
    BOOL _reading, _closed;
}

- (id)initWithFileDescriptor:(int)fd
                  bufferSize:(size_t)bufferSize
{
    if (!(self = [super init]))
        return nil;
    
    // Capture
    _fd = fd;
    _bufferSize = bufferSize;
    
    // Dispatch queue for I/O operations
    _queue = dispatch_queue_create("com.parksdigital.tophat.protocol", DISPATCH_QUEUE_SERIAL);
    
    // Dispatch I/O channel for socket file descriptor. Block runs after
    // the I/O channel closes.
    _io = dispatch_io_create(DISPATCH_IO_STREAM, fd, _queue, ^(int error) {
        // Set closed flag so no more reads will be attempted
        self->_closed = YES;
        
        // Report error, if any (set here only if creation fails)
        if (error)
            NSLog(@"Could not create socket I/O channel: %s (%d)",
                  strerror(error), error);
        
        // Close file descriptor or report error trying
        if (close(self->_fd))
            NSLog(@"Could not close socket: %s (%d)", strerror(errno), errno);

        // Notify delegate of closure
        [self->_delegate socketClosed:self];
    });
    
    // Set low-water mark on I/O channel to zero so incoming data will be
    // processed immediately
    dispatch_io_set_low_water(_io, 0);
    
    return self;
}

- (dispatch_data_t)buffer {
    return _buffer;
}

- (void)setBuffer:(dispatch_data_t)buffer {
    // Capture
    _buffer = buffer;

    // Return early if read still outstanding, buffer full, or closed flag set
    if (_reading || dispatch_data_get_size(buffer) >= _bufferSize || _closed)
        return;
    
    // Set read outstanding flag
    _reading = YES;
    
    // Request read up to currently available buffer size
    size_t available = _bufferSize - dispatch_data_get_size(_buffer);
    dispatch_io_read(_io, 0, available, _queue, ^(bool done, dispatch_data_t  _Nullable data, int error) {
        // Report, close, and return early on error
        if (error) {
            NSLog(@"Could not read socket: %s (%d)", strerror(error), error);
            return [self close];
        }
        
        // Close and return early on socket closed
        if (done && data == dispatch_data_empty)
            return [self close];

        // If read complete, clear read outstanding flag
        if (done)
            self->_reading = NO;
        
        // Append incoming data, if any, to buffer. Also triggers new read if read complete.
        self.buffer = dispatch_data_create_concat(self.buffer, data ? data : dispatch_data_empty);
        
        // Notify delegate
        [self->_delegate socketReceivedData:self];
    });
}

- (void)write:(dispatch_data_t)data {
    // Send data to client
    dispatch_io_write(_io, 0, data, _queue, ^(bool done, dispatch_data_t  _Nullable data, int error) {
          // On error, report and close
          if (error) {
              NSLog(@"Could not write socket: %s (%d)", strerror(error), error);
              [self close];
          }
      });
}

- (void)close {
    // Close dispatch I/O channel and stop outstanding operations
    dispatch_io_close(_io, DISPATCH_IO_STOP);
}

@end
