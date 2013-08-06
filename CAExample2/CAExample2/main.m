//
//  main.m
//  CAExample2
//
//  Created by Matthew Hosack on 8/5/13.
//  Copyright (c) 2013 Matthew Hosack. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define SAMPLE_RATE 44100
#define DURATION 0.5
#define FILENAME_FORMAT @"%0.3f-square.aiff"

enum {TRIANGLE,SQUARE,SINE};
int waveformChoice = SINE;

int main(int argc, const char * argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    if (argc < 2) {
        printf("Usage: CAExample2 n\n");
        return -1;
    }
    
    double hz = atof(argv[1]);
    assert(hz > 0);
    NSLog(@"generating %.3f hz tone.",hz);
    
    NSString *filename;
    switch (waveformChoice) {
        case TRIANGLE:
            filename = [NSString stringWithFormat:@"triangle-%0.3f.aiff",hz];
            break;
        case SQUARE:
            filename = [NSString stringWithFormat:@"square-%0.3f.aiff",hz];
            break;
        case SINE:
            filename = [NSString stringWithFormat:@"sine-%0.3f.aiff",hz];
            break;
        default:
            filename = [NSString stringWithFormat:@"output-%0.3f.aiff",hz];
            break;
    }
    
    NSString *filepath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:filename];
    NSURL *fileURL = [NSURL fileURLWithPath:filepath];
    
    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    asbd.mSampleRate = SAMPLE_RATE;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsBigEndian |
                        kAudioFormatFlagIsSignedInteger |
                        kAudioFormatFlagIsPacked;
    asbd.mBitsPerChannel = 16;
    asbd.mChannelsPerFrame = 1;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 2;
    asbd.mBytesPerPacket = 2;
    
    AudioFileID audioFile;
    OSStatus audioError = noErr;
    audioError = AudioFileCreateWithURL((CFURLRef)fileURL ,
                                        kAudioFileAIFFType,
                                        &asbd,
                                        kAudioFileFlags_EraseFile,
                                        &audioFile);
    assert(audioError == noErr);
    
    long maxSampleCount = SAMPLE_RATE * DURATION;
    long sampleCount = 0;
    UInt32 bytesToWrite = 2;
    double wavelengthInSamples = SAMPLE_RATE / hz;
    
    while (sampleCount < maxSampleCount) {
        for(int i = 0; i < wavelengthInSamples; i++){
            SInt16 sample;
            switch (waveformChoice) {
                case TRIANGLE:
                    sample = CFSwapInt16HostToBig(SHRT_MAX * 2 * (i / wavelengthInSamples) - SHRT_MAX);
                    break;
                case SQUARE:
                    if(i < wavelengthInSamples / 2){
                        sample = CFSwapInt16HostToBig(SHRT_MAX);
                    }
                    else{
                        sample = CFSwapInt16HostToBig(SHRT_MIN);
                    }
                    break;
                case SINE:
                    sample = CFSwapInt16HostToBig(SHRT_MAX * sin(2.0 * M_1_PI * (i/wavelengthInSamples)));
                    break;
                default:
                    break;
            }
            audioError = AudioFileWriteBytes(audioFile,
                                             false,
                                             sampleCount * 2,
                                             &bytesToWrite, &sample);
            assert(audioError == noErr);
            sampleCount++;
        }
    }
    audioError = AudioFileClose(audioFile);
    assert(audioError == noErr);
    NSLog(@"wrote %ld samples",sampleCount);
    
    [pool drain];
    return 0;
}

