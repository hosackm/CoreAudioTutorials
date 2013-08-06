//
//  main.m
//  CAExample1
//
//  Created by Matthew Hosack on 8/5/13.
//  Copyright (c) 2013 Matthew Hosack. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

int main(int argc, const char * argv[])
{

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    if(argc < 2){
        printf("Usage: CAExample1 /full/path/to/audio/file\n");
        return -1;
    }
    
    NSString *audioFilePath = [[NSString stringWithUTF8String:argv[1]]
                               stringByExpandingTildeInPath];
    NSURL *audioURL = [NSURL fileURLWithPath:audioFilePath];;
    AudioFileID audioFile;
    OSStatus audioErr = noErr;
    audioErr = AudioFileOpenURL((CFURLRef)audioURL,
                                kAudioFileReadPermission,
                                0,
                                &audioFile);
    //assert(audioErr == noErr);
    UInt32 dictionarySize = 0;
    audioErr = AudioFileGetPropertyInfo(audioFile,
                                        kAudioFilePropertyInfoDictionary,
                                        &dictionarySize,
                                        0);
    //assert(audioErr == noErr);
    CFDictionaryRef dictionary;
    audioErr = AudioFileGetProperty(audioFile,
                                    kAudioFilePropertyInfoDictionary,
                                    &dictionarySize,
                                    &dictionary);
    //assert(audioErr == noErr);
    NSLog(@"dictionary: %@",dictionary);
    CFRelease(dictionary);
    
    audioErr = AudioFileClose(audioFile);
    //assert(audioErr == noErr);
    
    [pool drain];
    return 0;
}

