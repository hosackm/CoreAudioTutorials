//
//  main.m
//  CAExample4
//
//  Created by Matthew Hosack on 8/5/13.
//  Copyright (c) 2013 Matthew Hosack. All rights reserved.
//

//#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define kNumberRecordBuffers 3

#pragma mark user data struct
typedef struct MyRecorder{
    AudioFileID recordFile;
    SInt64 recordPacket;
    Boolean running;
}MyRecorder;


#pragma mark utility functions
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

OSStatus MyGetDefaultInputDeviceSampleRate(Float64 *outSampleRate){
    OSStatus error;
    AudioDeviceID deviceID = 0;
    
    AudioObjectPropertyAddress propertyAddress;
    UInt32 propertySize;
    propertyAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
    propertyAddress.mElement = 0;
    propertySize = sizeof(AudioDeviceID);
    error = AudioHardwareServiceGetPropertyData(kAudioObjectSystemObject,
                                         &propertyAddress,
                                         0,
                                         NULL,
                                         &propertySize,
                                         &deviceID);
    if (error) {
        return error;
    }
    
    propertyAddress.mSelector = kAudioDevicePropertyNominalSampleRate;
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
    propertyAddress.mElement = 0;
    propertySize = sizeof(Float64);
    error = AudioHardwareServiceGetPropertyData(deviceID,
                                         &propertyAddress,
                                         0,
                                         NULL,
                                         &propertySize,
                                         outSampleRate);
    return error;
}

static void MyCopyEncoderCookieToFile(AudioQueueRef queue, AudioFileID theFile){
    OSStatus error;
    UInt32 propertySize;
    
    error = AudioQueueGetPropertySize(queue, kAudioConverterCompressionMagicCookie, &propertySize);
    
    if(error == noErr && propertySize > 0){
        Byte *magicCookie = (Byte*)malloc(propertySize);
        CheckError(AudioQueueGetProperty(queue,
                                         kAudioQueueProperty_MagicCookie,
                                         magicCookie,
                                         &propertySize),
                   "Couldn't get audio queue's magic cookie");
        
        CheckError(AudioFileSetProperty(theFile,
                                        kAudioFilePropertyMagicCookieData,
                                        propertySize,
                                        magicCookie),
                   "Couldn't set file's magic cookie");
        free(magicCookie);
    }
}

static int MyComputeRecordBufferSize(const AudioStreamBasicDescription *format,
                                     AudioQueueRef queue,
                                     float seconds)
{
    int packets, frames, bytes;
    frames = (int)ceil(seconds * format->mSampleRate);
    
    if (format->mBytesPerFrame > 0) {
        bytes = frames * format->mBytesPerFrame;
    }
    else
    {
        UInt32 maxPacketSize;
        if (format->mBytesPerPacket)
        {
            maxPacketSize = format->mBytesPerPacket;
        }
        else
        {
            UInt32 propertySize = sizeof(maxPacketSize);
            CheckError(AudioQueueGetProperty(queue,
                                             kAudioConverterPropertyMaximumOutputPacketSize,
                                             &maxPacketSize,
                                             &propertySize),
                       "Couldn't get queue's maximum output size");
        }
        if (format->mFramesPerPacket > 0) {
            packets = frames / format->mFramesPerPacket;
        }
        else{
            packets = frames;
        }
        if (packets == 0) {
            packets = 1;
        }
        bytes = packets * maxPacketSize;
    }
    return bytes;
}




#pragma mark record callback function
static void MyAQInputCallback(void *inUserData,
                              AudioQueueRef inQueue,
                              AudioQueueBufferRef inBuffer,
                              const AudioTimeStamp *inStartTime,
                              UInt32 inNumPackets,
                              const AudioStreamPacketDescription *inPacketDesc)
{
    MyRecorder *recorder = (MyRecorder*)inUserData;
    if (inNumPackets > 0) {
        CheckError(AudioFileWritePackets(recorder->recordFile,
                                         FALSE,
                                         inBuffer->mAudioDataByteSize,
                                         inPacketDesc,
                                         recorder->recordPacket,
                                         &inNumPackets,
                                         inBuffer->mAudioData),
                   "Writing Audio File Packets failed");
    }
    recorder->recordPacket += inNumPackets;
    
    if (recorder->running) {
        CheckError(AudioQueueEnqueueBuffer(inQueue,
                                           inBuffer,
                                           0,
                                           NULL),
                   "AudioQueueEnqueueBuffer failed");
    }
}



#pragma mark main function
int main(int argc, const char * argv[])
{
	MyRecorder recorder = {0};
	AudioStreamBasicDescription recordFormat = {0};
	memset(&recordFormat, 0, sizeof(recordFormat));
    
    MyGetDefaultInputDeviceSampleRate(&recordFormat.mSampleRate);
    // Configure the output data format to be AAC
	recordFormat.mFormatID = kAudioFormatMPEG4AAC;
	recordFormat.mChannelsPerFrame = 2;

    
    UInt32 propSize = sizeof(recordFormat);
    CheckError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                      0,
                                      NULL,
                                      &propSize,
                                      &recordFormat),
               "AudioFormatGetProperty failed");
    
    AudioQueueRef queue = {0};
    CheckError(AudioQueueNewInput(&recordFormat,
                                  MyAQInputCallback,
                                  &recorder,
                                  NULL,
                                  NULL,
                                  0,
                                  &queue),
               "AudioQueueNewInput failed");
    
    UInt32 size = sizeof(recordFormat);
    CheckError(AudioQueueGetProperty(queue,
                                     kAudioConverterCurrentOutputStreamDescription,
                                     &recordFormat,
                                     &size),
               "AudioQueueGetProperty failed");
    
    CFURLRef myFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                       CFSTR("output.caf"),
                                                       kCFURLPOSIXPathStyle,
                                                       false);
    CheckError(AudioFileCreateWithURL(myFileURL, kAudioFileCAFType, &recordFormat, kAudioFileFlags_EraseFile, &recorder.recordFile), "AudioFileCreateWithURL failed");
    CFRelease(myFileURL);
    
    MyCopyEncoderCookieToFile(queue, recorder.recordFile);
    
    int bufferByteSize = MyComputeRecordBufferSize(&recordFormat,queue,0.5);
    
    int bufferIndex;
    for (bufferIndex = 0; bufferIndex < kNumberRecordBuffers; ++bufferIndex) {
        AudioQueueBufferRef buffer;
        CheckError(AudioQueueAllocateBuffer(queue,
                                            bufferByteSize,
                                            &buffer),
                   "AudioQueueAllocateBuffer failed");
        CheckError(AudioQueueEnqueueBuffer(queue,
                                           buffer,
                                           0,
                                           NULL),
                   "AudioQueueEnqueueBuffer failed");
    }
    
    recorder.running = TRUE;
    CheckError(AudioQueueStart(queue, NULL),"AudioQueueStart failed");
    
    printf("Recording... press <enter> to end:\n");
    getchar();
    
    printf("Recording done...\n");
    recorder.running = FALSE;
    CheckError(AudioQueueStop(queue, TRUE), "AudioQueueStop failed");
    MyCopyEncoderCookieToFile(queue,recorder.recordFile);
    AudioQueueDispose(queue, TRUE);
    AudioFileClose(recorder.recordFile);
    
    return 0;
}

