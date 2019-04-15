//
//  Server.h
//  Static Server
//
//  Created by Aaron D. Parks on 4/12/19.
//  Copyright © 2019 Parks Digital LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface Server : NSWindowController

@property IBOutlet NSURL *root;
@property IBOutlet NSNumber *port;

@end

NS_ASSUME_NONNULL_END
