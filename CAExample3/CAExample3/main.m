//
//  main.m
//  CAExample3
//
//  Created by Matthew Hosack on 8/5/13.
//  Copyright (c) 2013 Matthew Hosack. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

int main(int argc, const char * argv[])
{

    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc]init];
    
    AudioFileTypeAndFormatID fileTypeAndFormat;
    fileTypeAndFormat.mFileType = kAudioFileCAFType;//kAudioFileWAVEType;//kAudioFileAIFFType;
    fileTypeAndFormat.mFormatID = kAudioFormatMPEG4AAC;//kAudioFormatLinearPCM;
    
    //fileTypeAndFormat.mFileType = kAudioFileMP3Type;
    //fileTypeAndFormat.mFormatID = kAudioFormatMPEG4AAC; // throws error!
    
    
    OSStatus audioErr = noErr;
    UInt32 infoSize = 0;
    audioErr = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
                                          sizeof(fileTypeAndFormat),
                                          &fileTypeAndFormat,
                                          &infoSize);
    
    if (audioErr != noErr) { //for error documented in comments on lines 21-22
        UInt32 errormp3 = CFSwapInt32HostToBig(audioErr);
        NSLog(@"%4.4s",(char*)&errormp3);
    }
    
    AudioStreamBasicDescription *asbds = malloc(infoSize);
    audioErr = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
                                      sizeof(fileTypeAndFormat),
                                      &fileTypeAndFormat,
                                      &infoSize,
                                      asbds);
    assert(audioErr == noErr);
    
    int asbdCount = infoSize / sizeof(AudioStreamBasicDescription);
    for(int i = 0; i < asbdCount; i++){
        UInt32 format4cc = CFSwapInt32HostToBig(asbds[i].mFormatID);
        NSLog(@"%d: mFormatID %4.4s, mFormatFlags: %d , mBitsPerChannel: %d",
              i,
              (char*)&format4cc,
              asbds[i].mFormatFlags,
              asbds[i].mBitsPerChannel);
    }
    
    free(asbds);
    [pool drain];
    return 0;
}

