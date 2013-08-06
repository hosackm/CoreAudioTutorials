//
//  main.m
//  CAExample5
//
//  Created by Matthew Hosack on 8/5/13.
//  Copyright (c) 2013 Matthew Hosack. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>

//Change the filename to something on your computer...
#define kPlaybackFileLocation CFSTR("/Users/hosack/Desktop/TwoDoorCinemaClub-SomethingGoodCanWork.m4a")
#define kNumberPlaybackBuffers 3

#pragma mark user data struct
//5.2
typedef struct MyPlayer{
    AudioFileID playbackFile;
    SInt64 packetPosition;
    UInt32 numPacketsToRead;
    AudioStreamPacketDescription *packetDesc;
    Boolean isDone;
}MyPlayer;

#pragma mark utility functions
//4.2
static void CheckError(OSStatus err, const char* operation){
    if (err == noErr)return;
    
    char errorString[20];
    *(UInt32 *)(errorString+1) = CFSwapInt32HostToBig(err);
    if(isprint(errorString[1]) && isprint(errorString[2])
       && isprint(errorString[3]) && isprint(errorString[4])){
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    }
    else{
        sprintf(errorString, "%d", (int)err);
    }
    fprintf(stderr, "Error: %s (%s)\n",operation, errorString);
    exit(1);
}
//5.14
static void MyCopyEncoderCookieToQueue(AudioFileID theFile,
                                       AudioQueueRef queue)
{
    UInt32 propertySize;
    OSStatus result = AudioFileGetProperty(theFile,
                                           kAudioFilePropertyMagicCookieData,
                                           &propertySize,
                                           NULL);
    if (result == noErr && propertySize > 0) {
        Byte* magicCookie = (UInt8*)malloc(sizeof(UInt8)*propertySize);
        CheckError(AudioFileGetProperty(theFile,
                                        kAudioFilePropertyMagicCookieData,
                                        &propertySize,
                                        magicCookie),
                   "Audio File get magic cookie failed");
        CheckError(AudioQueueSetProperty(queue,
                                         kAudioQueueProperty_MagicCookie,
                                         magicCookie,
                                         propertySize),
                   "Audio Queue set magic cookie failed");
        free(magicCookie);
    }
}
//5.15
void CalculateBytesForTime(AudioFileID inAudioFile,
                              AudioStreamBasicDescription inDesc,
                              Float64 inSeconds,
                              UInt32 *outBufferSize,
                              UInt32 *outNumPackets)
{
    UInt32 maxPacketSize;
    UInt32 propSize = sizeof(maxPacketSize);
    CheckError(AudioFileGetProperty(inAudioFile,
                                    kAudioFilePropertyPacketSizeUpperBound,
                                    &propSize,
                                    &maxPacketSize),
               "Couldn't get file's max packet size");
    static const int maxBufferSize = 0x10000;
    static const int minBufferSize = 0x4000;
    
    if (inDesc.mFramesPerPacket) {
        Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    }
    else{
        *outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
    }
    
    if(*outBufferSize > maxBufferSize &&
       *outBufferSize > maxPacketSize){
        *outBufferSize = maxBufferSize;
    }
    else{
        if(*outBufferSize < minBufferSize){
            *outBufferSize = minBufferSize;
        }
    }
    *outNumPackets = *outBufferSize / maxPacketSize;
}

#pragma mark playback callback function
//replace with listings 5.16-5.19
static void MyAQOutputCallback(void *inUserData,
                               AudioQueueRef inAQ,
                               AudioQueueBufferRef inCompleteAQBuffer)
{
	MyPlayer *aqp = (MyPlayer*)inUserData;
	if (aqp->isDone) return;	
	UInt32 numBytes;
	UInt32 nPackets = aqp->numPacketsToRead;
	CheckError(AudioFileReadPackets(aqp->playbackFile,
									false,
									&numBytes,
									aqp->packetDesc,
									aqp->packetPosition,
									&nPackets,
									inCompleteAQBuffer->mAudioData),
			   "AudioFileReadPackets failed");
	if (nPackets > 0)
	{
		inCompleteAQBuffer->mAudioDataByteSize = numBytes;
		AudioQueueEnqueueBuffer(inAQ,
								inCompleteAQBuffer,
								(aqp->packetDesc ? nPackets : 0),
								aqp->packetDesc);
		aqp->packetPosition += nPackets;
	}
	else
	{
		CheckError(AudioQueueStop(inAQ, false), "AudioQueueStop failed");
		aqp->isDone = true;
	}
}


#pragma mark main function
int	main(int argc, const char *argv[])
{
	MyPlayer player = {0};
	
	CFURLRef myFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, kPlaybackFileLocation, kCFURLPOSIXPathStyle, false);

	CheckError(AudioFileOpenURL(myFileURL, kAudioFileReadPermission, 0, &player.playbackFile), "AudioFileOpenURL failed");
	CFRelease(myFileURL);
	
	AudioStreamBasicDescription dataFormat;
	UInt32 propSize = sizeof(dataFormat);
	CheckError(AudioFileGetProperty(player.playbackFile, kAudioFilePropertyDataFormat,
									&propSize, &dataFormat), "couldn't get file's data format");
	
	AudioQueueRef queue;
	CheckError(AudioQueueNewOutput(&dataFormat, // ASBD
								   MyAQOutputCallback, // Callback
								   &player, // user data
								   NULL, // run loop
								   NULL, // run loop mode
								   0, // flags (always 0)
								   &queue), // output: reference to AudioQueue object
			   "AudioQueueNewOutput failed");
	
	
 	UInt32 bufferByteSize;
	CalculateBytesForTime(player.playbackFile, dataFormat,  0.5, &bufferByteSize, &player.numPacketsToRead);
	bool isFormatVBR = (dataFormat.mBytesPerPacket == 0 || dataFormat.mFramesPerPacket == 0);
	if (isFormatVBR)
		player.packetDesc = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription) * player.numPacketsToRead);
	else
		player.packetDesc = NULL;	
	MyCopyEncoderCookieToQueue(player.playbackFile, queue);
	
	AudioQueueBufferRef	buffers[kNumberPlaybackBuffers];
	player.isDone = false;
	player.packetPosition = 0;
	int i;
	for (i = 0; i < kNumberPlaybackBuffers; ++i)
	{
		CheckError(AudioQueueAllocateBuffer(queue, bufferByteSize, &buffers[i]), "AudioQueueAllocateBuffer failed");
		
		MyAQOutputCallback(&player, queue, buffers[i]);
		
		if (player.isDone)
			break;
	}
	CheckError(AudioQueueStart(queue, NULL), "AudioQueueStart failed");
	
	printf("Playing...\n");
	do
	{
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
	} while (!player.isDone /*|| gIsRunning*/);

	CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2, false);
	
	player.isDone = true;
	CheckError(AudioQueueStop(queue, TRUE), "AudioQueueStop failed");
	
	AudioQueueDispose(queue, TRUE);
	AudioFileClose(player.playbackFile);
	
	return 0;
}

