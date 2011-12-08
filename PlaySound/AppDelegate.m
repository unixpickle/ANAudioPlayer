//
//  AppDelegate.m
//  PlaySound
//
//  Created by Alex Nichol on 12/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
	NSString * songFile = [[NSBundle mainBundle] pathForResource:@"thedeepend" ofType:@"wav"];
	player = [[ANAudioPlayer alloc] initWithAudioFile:songFile];
	[player setDelegate:self];
}

- (IBAction)playStop:(NSButton *)sender {
	if ([[sender title] isEqualToString:@"Stop"]) {
		[progress startAnimation:nil];
		[sender setTitle:@"Play"];
		[player stopPlaying];
	} else {
		if (![player startPlaying]) return;
		[progress stopAnimation:nil];
		[sender setTitle:@"Stop"];
	}
}

- (void)audioPlayerDidFinishPlaying:(ANAudioPlayer *)anAudioPlayer {
	[progress stopAnimation:nil];
	[playPauseButton setTitle:@"Play"];
}

@end
