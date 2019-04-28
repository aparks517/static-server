//
//  AppDelegate.m
//  Static Server
//
//  Created by Aaron D. Parks on 4/12/19.
//  Copyright © 2019 Parks Digital LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "Server.h"

@interface AppDelegate ()

@property NSMutableArray *servers;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Hold references to server window controllers until their windows close
    _servers = [NSMutableArray array];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(windowWillClose:)
                                               name:NSWindowWillCloseNotification
                                             object:nil];
}

- (IBAction)open:(id)sender {
    // Get path to serve from open panel
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    [panel runModal];
    
    // Server window with selected path
    Server *server = [[Server alloc] initWithWindowNibName:@"Server"];
    server.root = panel.URL;
    [server showWindow:sender];
    [_servers addObject:server];
}

- (void)windowWillClose:(NSNotification *)sender {
    [_servers removeObject:[sender.object windowController]];
}

- (IBAction)showHelp:(id)sender {
    // Open HTML help from main bundle in Safari
    NSURL *helpURL = [NSBundle.mainBundle URLForResource:@"Help-Index" withExtension:@"html"];
    [NSWorkspace.sharedWorkspace openURLs:@[helpURL]
                  withAppBundleIdentifier:@"com.apple.Safari"
                                  options:NSWorkspaceLaunchDefault
           additionalEventParamDescriptor:nil
                        launchIdentifiers:nil];
}

@end
