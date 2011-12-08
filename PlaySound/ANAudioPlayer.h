//
//  ANAudioPlayer.h
//  PlaySound
//
//  Created by Alex Nichol on 12/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define kNumBuffers 3

typedef enum {
	ANAudioPlayerStateNotStarted,
	ANAudioPlayerStatePlaying,
	ANAudioPlayerStateDonePlayer
} ANAudioPlayerState;

@class ANAudioPlayer;

@protocol ANAudioPlayerDelegate <NSObject>

@optional
- (void)audioPlayerDidFinishPlaying:(ANAudioPlayer *)anAudioPlayer;

@end

@interface ANAudioPlayer : NSObject {
	ANAudioPlayerState playerState;
	
	AudioFileID audioFile;
	AudioStreamBasicDescription audioFormat;
	AudioQueueRef audioQueue;
	AudioQueueBufferRef buffers[kNumBuffers];
	
	UInt32 packetSizeBytes;
	UInt32 packetCount;
	SInt64 currentPacket;
	
	__weak id<ANAudioPlayerDelegate> delegate;
}

@property (nonatomic, weak) __weak id<ANAudioPlayerDelegate> delegate;

- (id)initWithAudioFile:(NSString *)audioFileName;

- (BOOL)startPlaying;
- (BOOL)resumePlaying;
- (BOOL)isPlaying;
- (void)stopPlaying;

@end
