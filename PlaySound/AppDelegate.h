//
//  AppDelegate.h
//  PlaySound
//
//  Created by Alex Nichol on 12/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ANAudioPlayer.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, ANAudioPlayerDelegate> {
	ANAudioPlayer * player;
	IBOutlet NSButton * playPauseButton;
	IBOutlet NSProgressIndicator * progress;
}

@property (assign) IBOutlet NSWindow * window;

- (IBAction)playStop:(NSButton *)sender;

@end
