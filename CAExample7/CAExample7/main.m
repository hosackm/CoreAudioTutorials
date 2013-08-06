//
//  main.m
//  CAExample7
//
//  Created by Matthew Hosack on 8/5/13.
//  Copyright (c) 2013 Matthew Hosack. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>

#define kInputFileLocation CFSTR("/Users/hosack/Desktop/TwoDoorCinemaClub-SomethingGoodCanWork.m4a")

#pragma mark user-data struct
typedef struct MyAUGraphPlayer{
    AudioStreamBasicDescription inputFormat;
    AudioFileID inputFile;
    
    AUGraph graph;
    AudioUnit fileAU;
}MyAUGraphPlayer;

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

void CreateMyAUGraph(MyAUGraphPlayer *player){
    CheckError(NewAUGraph(&player->graph), "NewAUGraph failed");
    //Create Output Node
    AudioComponentDescription outputcd = {0};
    outputcd.componentType = kAudioUnitType_Output;
    outputcd.componentSubType = kAudioUnitSubType_DefaultOutput;
    outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AUNode outputNode;
    CheckError(AUGraphAddNode(player->graph,
                              &outputcd,
                              &outputNode),
               "AUGraphAddNode output node failed");
    //Create Audio File Node
    AudioComponentDescription fileplayercd = {0};
    fileplayercd.componentType = kAudioUnitType_Generator;
    fileplayercd.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    fileplayercd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AUNode fileplayerNode;
    CheckError(AUGraphAddNode(player->graph,
                              &fileplayercd,
                              &fileplayerNode),
               "AUGraphAddNode File Player failed");
    
    CheckError(AUGraphOpen(player->graph),
               "AUGraphOpen failed");
    
    CheckError(AUGraphNodeInfo(player->graph, fileplayerNode, NULL, &player->fileAU),
               "AUGraphNodeInfo failed");
    CheckError(AUGraphConnectNodeInput(player->graph,
                                       fileplayerNode,
                                       0,
                                       outputNode,
                                       0),
               "Graph connect failed");
    CheckError(AUGraphInitialize(player->graph),
               "AUGraphInitialize failed");
}

Float64 PrepareFileAU(MyAUGraphPlayer *player){
    
    CheckError(AudioUnitSetProperty(player->fileAU,
                                    kAudioUnitProperty_ScheduledFileIDs,
                                    kAudioUnitScope_Global,
                                    0,
                                    &player->inputFile,
                                    sizeof(player->inputFile)),
               "AudioUnitSetProperty failed");
    UInt64 nPackets;
    UInt32 propSize = sizeof(nPackets);
    CheckError(AudioFileGetProperty(player->inputFile,
                                    kAudioFilePropertyAudioDataPacketCount,
                                    &propSize,
                                    &nPackets),
               "AudioFileGetProperty");
    
    ScheduledAudioFileRegion rgn;
    memset(&rgn,0,sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    rgn.mCompletionProc = NULL;
    rgn.mCompletionProcUserData = NULL;
    rgn.mAudioFile = player->inputFile;
    rgn.mLoopCount = 1;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = nPackets * (player->inputFormat.mFramesPerPacket);
    
    CheckError(AudioUnitSetProperty(player->fileAU,
                                    kAudioUnitProperty_ScheduledFileRegion,
                                    kAudioUnitScope_Global,
                                    0,
                                    &rgn,
                                    sizeof(rgn)),
               "AudioUnitSetProperty failed");
    AudioTimeStamp startTime;
    memset(&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    CheckError(AudioUnitSetProperty(player->fileAU,
                                    kAudioUnitProperty_ScheduleStartTimeStamp,
                                    kAudioUnitScope_Global,
                                    0,
                                    &startTime,
                                    sizeof(startTime)),
               "AudioUnitSetProperty Schedule Start time stamp failed");
    return (nPackets * player->inputFormat.mFramesPerPacket) / player->inputFormat.mSampleRate;
}



#pragma mark main function
int main(int argc, const char * argv[])
{
    CFURLRef inputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                          kInputFileLocation,
                                                          kCFURLPOSIXPathStyle,
                                                          false);
    MyAUGraphPlayer player = {0};
    CheckError(AudioFileOpenURL(inputFileURL,
                                kAudioFileReadPermission,
                                0,
                                &player.inputFile),
               "Audio File Open failed");
    CFRelease(inputFileURL);
    
    UInt32 propSize = sizeof(player.inputFormat);
    CheckError(AudioFileGetProperty(player.inputFile,
                                    kAudioFilePropertyDataFormat,
                                    &propSize,
                                    &player.inputFormat),
               "Audio File Get Property failed");
    
    CreateMyAUGraph(&player);
    Float64 fileDuration = PrepareFileAU(&player);
    
    CheckError(AUGraphStart(player.graph),
               "Audio Unit start failed");
    usleep((int)fileDuration * 1000.0 * 1000.0);
    
    AUGraphStop(player.graph);
    AUGraphUninitialize(player.graph);
    AUGraphClose(player.graph);
    AudioFileClose(player.inputFile);
    
    return 0;
}

