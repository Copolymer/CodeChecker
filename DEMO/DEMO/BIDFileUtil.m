//
//  BIDFileUtil.m
//  AutoTestPlatform
//
//  Created by Aesthetic on 2018/9/19.
//  Copyright © 2018年 Aesthetic. All rights reserved.
//

#import "BIDFileUtil.h"
#define kFilename @"TaskList.data"


void KSLog(NSString * log, ...) {
    NSLog(@"log = %@", log);
    NSString * path = [NSString stringWithFormat:@"%@UserSimulateLog.txt", [BIDFileUtil getResultDir]];
    NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    NSString * currentDateStr = [dateFormatter stringFromDate:[NSDate date]];
    NSString * string = [NSString stringWithFormat:@"%@_%@\n", currentDateStr, log];
    [BIDFileUtil writeFileAtEnd:path result:string];
}

void NYLog(NSString * log, NSString *path) {
    NSLog(@"log = %@", log);
    NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    NSString * currentDateStr = [dateFormatter stringFromDate:[NSDate date]];
    NSString * string = [NSString stringWithFormat:@"%@\t%@\n", currentDateStr, log];
    [BIDFileUtil writeFileAtEnd:path result:string];
}


void DebugLog(NSString *format, ...) {
#ifdef DEBUG
    NSLog(@"DEBUG_LOG:");
#else

#endif
}

@implementation BIDFileUtil
+ (NSString *)getDocumentsDir{
    NSString* documentsDirectory = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/"];
    return documentsDirectory;
}

+ (NSString *)getScriptDir{
    NSString *path=[NSString stringWithFormat:@"%@Scripts/",[self getDocumentsDir]];
    [BIDFileUtil createFolderIfNotExist:path];
    return path;
}

+ (NSString *)getTaskFilePath{
    NSString *path=[NSString stringWithFormat:@"%@%@",[self getDocumentsDir],kFilename];
    return path;
}

+ (NSString *)getChangeDir{
    NSString *path=[NSString stringWithFormat:@"%@Changes/",[self getDocumentsDir]];
    [BIDFileUtil createFolderIfNotExist:path];
    return path;
}

+ (NSString *)getResultDir{
    NSString *path=[NSString stringWithFormat:@"%@Results/",[self getDocumentsDir]];
    [BIDFileUtil createFolderIfNotExist:path];
    return path;
}

+ (NSString *)resultDir {
    NSString *path=[NSString stringWithFormat:@"%@Results",[self getDocumentsDir]];
    return path;
}

+ (BOOL)createFileIfNotExist:(NSString *)path{
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return NO;
    }
//    NSLog(@"==>CreateFile:%@", path);
    [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    return YES;
}

+ (BOOL)createFolderIfNotExist:(NSString *)path{
    BOOL isFolder = YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isFolder]) {
        return NO;
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return YES;
}

+ (BOOL)writeFileAtEnd:(NSString *)path result:(NSString *)res {
    [self createFileIfNotExist:path];
    NSFileHandle *myHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (myHandle != nil) {
        [myHandle seekToEndOfFile];
        [myHandle writeData:[res dataUsingEncoding:NSUTF8StringEncoding]];
        [myHandle closeFile];
        return YES;
    }
    return NO;
}

+ (BOOL)removeAllElements:(NSString *)path{
    NSFileManager * fileManager = [NSFileManager defaultManager];
    BOOL isDir = YES;
    if ([fileManager fileExistsAtPath:path isDirectory:&isDir]) {
        [fileManager removeItemAtPath:path error:nil];
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        return YES;
    }
    return NO;
}

@end


