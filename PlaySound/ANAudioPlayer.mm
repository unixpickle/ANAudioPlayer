//
//  ANAudioPlayer.m
//  PlaySound
//
//  Created by Alex Nichol on 12/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ANAudioPlayer.h"

void ANAudioPlayerBufferCallback (void * inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer);
void ANAudioPlayerIsRunningCallback (void * inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID);

static void _CalculateBytesForTime (AudioStreamBasicDescription& inDesc, UInt32 inMaxPacketSize, Float64 inSeconds, UInt32 * outBufferSize, UInt32 * outNumPackets);
static BOOL _CopyCookieData (AudioFileID& fileID, AudioQueueRef& destination);
static BOOL _CopyChannelLayout (AudioFileID& fileID, AudioQueueRef& destination);

@interface ANAudioPlayer (Private)

- (void)queueToBuffer:(AudioQueueBufferRef)buffer;
- (void)playbackQueueStopped;

@end

@implementation ANAudioPlayer

@synthesize delegate;

- (id)initWithAudioFile:(NSString *)audioFileName {
	if ((self = [super init])) {
		OSStatus status;
		NSURL * theURL = [NSURL fileURLWithPath:audioFileName];
		
		playerState = ANAudioPlayerStateNotStarted;
		
		status = AudioFileOpenURL((__bridge CFURLRef)theURL, kAudioFileReadPermission, 0, &audioFile);
		if (status != noErr) return nil;
		
		UInt32 _formatSize = sizeof(audioFormat);
		status = AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &_formatSize, &audioFormat);
		if (status != noErr) return nil;
		
		status = AudioQueueNewOutput(&audioFormat, ANAudioPlayerBufferCallback, (__bridge void *)self, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 0, &audioQueue);
		if (status != noErr) return nil;
		
		UInt32 maxPacketSize = 0, _packetSizeSize = sizeof(UInt32);
		status = AudioFileGetProperty(audioFile, kAudioFilePropertyPacketSizeUpperBound, &_packetSizeSize, &maxPacketSize);
		if (status != noErr) {
			AudioQueueDispose(audioQueue, false);
			AudioFileClose(audioFile);
			return nil;
		}
		
		_CalculateBytesForTime(audioFormat, maxPacketSize, 0.5f, &packetSizeBytes, &packetCount);
		if (!_CopyCookieData(audioFile, audioQueue) || !_CopyChannelLayout(audioFile, audioQueue)) {
			AudioQueueDispose(audioQueue, false);
			AudioFileClose(audioFile);
			return nil;
		}
		
		AudioQueueAddPropertyListener(audioQueue, kAudioQueueProperty_IsRunning, ANAudioPlayerIsRunningCallback, (__bridge void *)self);
		
		BOOL loosePacketSize = (audioFormat.mBytesPerPacket == 0 || audioFormat.mFramesPerPacket == 0);
		UInt32 packetsPerBuff = (loosePacketSize ? packetCount : 0);
		for (int i = 0; i < kNumBuffers; i++) {
			status = AudioQueueAllocateBufferWithPacketDescriptions(audioQueue, packetSizeBytes, packetsPerBuff, &buffers[i]);
			if (status != noErr) {
				AudioQueueDispose(audioQueue, false);
				AudioFileClose(audioFile);
				return nil;
			}
		}
		
		AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0);
	}
	return self;
}

- (BOOL)startPlaying {
	if ([self isPlaying]) return NO;
	
	currentPacket = 0;
	playerState = ANAudioPlayerStatePlaying;
	
	for (int i = 0; i < kNumBuffers; i++) {
		ANAudioPlayerBufferCallback((__bridge void *)self, audioQueue, buffers[i]);			
	}
	AudioQueueStart(audioQueue, NULL);
	
	return YES;
}

- (BOOL)resumePlaying {
	if ([self isPlaying]) return NO;
	
	playerState = ANAudioPlayerStatePlaying;
	
	for (int i = 0; i < kNumBuffers; i++) {
		ANAudioPlayerBufferCallback((__bridge void *)self, audioQueue, buffers[i]);			
	}
	AudioQueueStart(audioQueue, NULL);
	
	return YES;
}

- (BOOL)isPlaying {
	if (playerState == ANAudioPlayerStatePlaying) return YES;
	UInt32 isRunning = 0, size = sizeof(UInt32);
	OSStatus result = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_IsRunning, &isRunning, &size);
	if (result == noErr) {
		return (BOOL)isRunning;
	}
	return NO;
}

- (void)stopPlaying {
	if (playerState != ANAudioPlayerStatePlaying) {
		return;
	}
	playerState = ANAudioPlayerStateDonePlayer;
	AudioQueueStop(audioQueue, true);
}

- (void)dealloc {
	AudioQueueDispose(audioQueue, true);
	AudioFileClose(audioFile);
	audioQueue = NULL;
	audioFile = NULL;
}

#pragma mark - Private Player -

- (void)queueToBuffer:(AudioQueueBufferRef)buffer {
	if (playerState != ANAudioPlayerStatePlaying) {
		return;
	}
		
	UInt32 numBytes = 0;
	UInt32 nPackets = packetCount;
	OSStatus result = AudioFileReadPackets(audioFile, false, &numBytes,
										   buffer->mPacketDescriptions, currentPacket, &nPackets, 
										   buffer->mAudioData);
	
	if (result != noErr) {
		NSLog(@"Read failed: playing cancelled");
		AudioQueueStop(audioQueue, false);
		playerState = ANAudioPlayerStateDonePlayer;
		return;
	}
	
	if (nPackets == 0) {
		AudioQueueStop(audioQueue, false);
		playerState = ANAudioPlayerStateDonePlayer;
		return;
	} else {
		buffer->mAudioDataByteSize = numBytes;		
		buffer->mPacketDescriptionCount = nPackets;		
		AudioQueueEnqueueBuffer(audioQueue, buffer, 0, NULL);
		currentPacket += nPackets;
	}
}

- (void)playbackQueueStopped {
	playerState = ANAudioPlayerStateDonePlayer;
	if ([delegate respondsToSelector:@selector(audioPlayerDidFinishPlaying:)]) {
		[delegate audioPlayerDidFinishPlaying:self];
	}
}

@end

#pragma mark - C Callbacks -

void ANAudioPlayerBufferCallback (void * inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer) {
	// buffer callback
	ANAudioPlayer * player = (__bridge ANAudioPlayer *)inUserData;
	[player queueToBuffer:inCompleteAQBuffer];
}

void ANAudioPlayerIsRunningCallback (void * inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
	// is running property changed
	ANAudioPlayer * player = (__bridge ANAudioPlayer *)inUserData;
	UInt32 isRunning = 0, size = sizeof(UInt32);
	OSStatus result = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size);
	if (result == noErr && !isRunning) {
		[player playbackQueueStopped];
	}
}

#pragma mark - Helpers -

// Source code taken from Apple's SpeakHere demo
// This function essentially takes a given amount of time, and figures out a good number of bytes
// per packet, and also provides the total number of packets that will be needed for the file.
static void _CalculateBytesForTime (AudioStreamBasicDescription& inDesc, UInt32 inMaxPacketSize, Float64 inSeconds, UInt32 * outBufferSize, UInt32 * outNumPackets) {
	// we only use time here as a guideline
	// we're really trying to get somewhere between 16K and 64K buffers, but not allocate too much if we don't need it
	static const int maxBufferSize = 0x10000; // limit size to 64K
	static const int minBufferSize = 0x4000; // limit size to 16K
	
	if (inDesc.mFramesPerPacket) {
		Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
		*outBufferSize = numPacketsForTime * inMaxPacketSize;
	} else {
		// if frames per packet is zero, then the codec has no predictable packet == time
		// so we can't tailor this (we don't know how many Packets represent a time period
		// we'll just return a default buffer size
		*outBufferSize = maxBufferSize > inMaxPacketSize ? maxBufferSize : inMaxPacketSize;
	}
	
	// we're going to limit our size to our default
	if (*outBufferSize > maxBufferSize && *outBufferSize > inMaxPacketSize)
		*outBufferSize = maxBufferSize;
	else {
		// also make sure we're not too small - we don't want to go the disk for too small chunks
		if (*outBufferSize < minBufferSize)
			*outBufferSize = minBufferSize;
	}
	*outNumPackets = *outBufferSize / inMaxPacketSize;
}

static BOOL _CopyCookieData (AudioFileID& fileID, AudioQueueRef& destination) {
	UInt32 size = sizeof(UInt32);
	OSStatus result = AudioFileGetPropertyInfo(fileID, kAudioFilePropertyMagicCookieData, &size, NULL);
	if (result == noErr && size != 0) {
		char * cookie = (char *)malloc(size);
		result = AudioFileGetProperty(fileID, kAudioFilePropertyMagicCookieData, &size, cookie);
		if (result != noErr) {
			free(cookie);
			return NO;
		}
		result = AudioQueueSetProperty(destination, kAudioQueueProperty_MagicCookie, cookie, size);
		free(cookie);
		if (result != noErr) {
			return NO;
		}
	}
	return YES;
}

static BOOL _CopyChannelLayout (AudioFileID& fileID, AudioQueueRef& destination) {
	UInt32 size = sizeof(UInt32);
	OSStatus result = AudioFileGetPropertyInfo(fileID, kAudioFilePropertyChannelLayout, &size, NULL);
	if (result == noErr && size != 0) {
		AudioChannelLayout * layout = (AudioChannelLayout *)malloc(size);
		result = AudioFileGetProperty(fileID, kAudioFilePropertyChannelLayout, &size, layout);
		if (result != noErr) {
			free(layout);
			return NO;
		}
		result = AudioQueueSetProperty(destination, kAudioQueueProperty_ChannelLayout, layout, size);
		free(layout);
		if (result != noErr) {
			return NO;
		}
	}
	return YES;
}
