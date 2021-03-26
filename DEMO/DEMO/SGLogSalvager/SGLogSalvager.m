//
//  SGLogSalvager.m
//  SogouInput
//
//  Created by Aesthetic on 2020/12/4.
//  Copyright © 2020 Sogou.Inc. All rights reserved.
//

#import "SGLogSalvager.h"
#import <sys/time.h>
#include <sys/mount.h>
#import "SGDeviceUtil.h"
#include <clogan_core.h>
#import "SGLogSalvageTask.h"
#import "TYStatistics.h"

#define LogSalvager_NullStr (@"null")

#define LOG_SALVAGE_TEST

// 日志上传URL
static NSString *const SALVAGE_LOG_UPLOAD_URL = @"http://requality.android.shouji.sogou.com/log_monitor.gif";

// 上一次log文件名保存KEY
static NSString *const LAST_LOG_TIMESTAMP_STORE_KEY = @"LAST_LOG_TIMESTAMP_STORE_KEY";

// 空余磁盘空间5M 5*1024*1024
static NSInteger __MAX_FREE_SPACE = 5242880;

// 一小时秒数
static NSInteger __ONE_HOUR_MILLI_SECONDS = 3600000;

// 加密KEY
static NSString *__AES_KEY = @"AIWLA1021ownWNi1";
static NSString *__AES_IV = @"AIWLA1021ownWNi1";

// 文件最大size 1.5M 1.5 * 1024 * 1024
static uint64_t __MAX_FILE_SIZE = 1572864;

// 过期时间 4天 4 * 24 * 60 * 60
static uint32_t __MAX_RESERVED_DATE = 345600;


@interface SGLogSalvager()

/// 日志打印队列
@property (nonatomic, strong) dispatch_queue_t salvagerLogQueue;

/// 日志上传队列
@property (nonatomic, strong) dispatch_queue_t logUploadQueue;

/// 最后检查空余磁盘的时间
@property (nonatomic, assign) NSTimeInterval lastCheckFreeSpace;

/// 上一次打印文件的时间
@property (nonatomic, assign) long long lastLogFileHourMillisecondTimestamp;

/// 系统信息拼接原始数据
@property (nonatomic, copy) NSString *primitiveSystemSplicingFields;

/// 小时粒度时间Formatter
@property (nonatomic, strong) NSDateFormatter *hourDateformatter;

@end

@implementation SGLogSalvager

- (nonnull instancetype)init {
    if (self = [super init]) {
        dispatch_async(self.salvagerLogQueue, ^{
            [self initLoganCLib];
        });
    }
    return self;
}

- (void)run
{
    @autoreleasepool {
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
    }
}


- (void)initLoganCLib
{
    const char *salvageLogDir = [self salvageLogDirectory].UTF8String;
    const char *loganCacheDir = [self loganCacheDirectory].UTF8String;
    
    const char *aeskey = (const char *)[[__AES_KEY dataUsingEncoding:NSUTF8StringEncoding] bytes];
    const char *aesiv = (const char *)[[__AES_IV dataUsingEncoding:NSUTF8StringEncoding] bytes];
    
    // 初始化clogan，最大文件size是1.5M
    clogan_init(loganCacheDir, salvageLogDir, (int)__MAX_FILE_SIZE, aeskey, aesiv);
    
    // 从mmap恢复上一次未flush到磁盘的内容
    long long lastLogFileHourMillisecondTimestamp = [[[NSUserDefaults standardUserDefaults] objectForKey:LAST_LOG_TIMESTAMP_STORE_KEY] longLongValue];
    if (lastLogFileHourMillisecondTimestamp) {
        self.lastLogFileHourMillisecondTimestamp = lastLogFileHourMillisecondTimestamp;
        clogan_open((char *)[NSString stringWithFormat:@"%lld", lastLogFileHourMillisecondTimestamp].UTF8String);
    }
}


- (void)log:(id<SGSalvageLogFormat>)log withBusinessID:(SGLogSalvagerBusinessID)businessID andAttacher:(nullable LOG_SALVAGER_ATTACHER)attacher
{
    [self log:log withBusinessID:businessID andAttacher:attacher andCustomAttachments:nil];
}


- (void)log:(id<SGSalvageLogFormat>)log withBusinessID:(SGLogSalvagerBusinessID)businessID andAttacher:(nullable LOG_SALVAGER_ATTACHER)attacher andCustomAttachments:(nullable SGLogSalvagerCustomAttachmentFunc)customAttachmentFunc, ...;
{
    if (!log || ![log respondsToSelector:@selector(salvageLogFormat)]) return;

    //当前打印毫秒时间戳
    long long millisecondTimestamp = [self currentMillisecondTimeStamp];

    //LogContent
    NSString *logContent = [log salvageLogFormat];
    if (!logContent || ![logContent isKindOfClass:NSString.class]) return;

    NSMutableString *primitiveLogString = [NSMutableString stringWithFormat:@"log=%@&&", logContent];

    //BusinessID
    [primitiveLogString appendFormat:@"business_id=%ld&&", (long)businessID];

    //Attacher
    if (attacher) {
        [primitiveLogString appendFormat:@"%@=%@&&", attacher().attacherName, attacher().attacherContent];
    }

    //CustomAttachments
    va_list args;
    va_start(args, customAttachmentFunc);
    for (SGLogSalvagerCustomAttachmentFunc currentObject = customAttachmentFunc; currentObject != nil; currentObject = va_arg(args, SGLogSalvagerCustomAttachmentFunc)) {
        [primitiveLogString appendFormat:@"%@=%@&&", currentObject.attachmentName, currentObject.attachmentContent];
    }
    va_end(args);
    
    // 记录细节
    [self _primitiveLog:primitiveLogString withMillisecondTimestamp:millisecondTimestamp];
}

- (void)uploadLogFilesWithTask:(SGLogSalvageTask *)task withProcessBlock:(SGLogSalvageUploadProcessBlock)processBlock
{
    // 日志上传任务组
    dispatch_group_t uploadGroup = dispatch_group_create();
    
    // 假定所有文件上传成功
    __block BOOL allLogFileUploaded = YES;
    
    __weak typeof(self) weakSelf = self;
    // 收集日期之间的Log文件并分割成包进行上传
    [self collectPacketsToBeUploadedWithTask:task usingBlock:^(NSString *base64StringLogPacket, NSArray<NSString *> *logFilesInPacket) {

        // 将上传任务放到任务组
        dispatch_group_async(uploadGroup, weakSelf.logUploadQueue, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            
            // 上传文件包
            if ([strongSelf syncUploadBase64StringLogPacket:base64StringLogPacket withTaskID:task.taskID] == NO) {
                allLogFileUploaded = NO;
            } else {
                if (processBlock) {
                    processBlock(logFilesInPacket, NO);
                }
            }
        });
        
    }];
    
    // 等所有日志文件上传结束
    dispatch_group_wait(uploadGroup, DISPATCH_TIME_FOREVER);
    
    // 回调上传过程结束block
    if (processBlock) {
        processBlock(nil, allLogFileUploaded);
    }
}

- (void)collectPacketsToBeUploadedWithTask:(SGLogSalvageTask *)task usingBlock:(void(^)(NSString *base64StringLogPacket, NSArray<NSString *> *logFilesInPacket))block
{
    __block NSMutableData *mutableLogPacketData = [NSMutableData data];
    __block NSMutableArray<NSString *> *mutableLogFilesInPacket = [NSMutableArray array];
    
    __block NSInteger currentPacketLength = 0;
    
    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:task.startTime];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:task.endTime];
    
    __weak typeof(self) weakSelf = self;
    [self enumerateLocalLogFilesFromDate:startDate toDate:endDate usingBlock:^(NSString *filepath, BOOL * _Nonnull stop) {
        @autoreleasepool {
            __strong typeof(weakSelf) strongSelf = weakSelf;

            // 筛选已经上传过的log文件
            if ([task.uploadedLogFiles containsObject:filepath]) {
                return;
            }
            
            // 如果上传的文件为当前正在记录的文件，则需要先进行flush
            if (strongSelf.lastLogFileHourMillisecondTimestamp == [[filepath lastPathComponent] longLongValue]) {
                clogan_flush();
            }
            
            
            NSData *filedata = [NSData dataWithContentsOfFile:filepath];
            
            //*********************最大拼接包不超过1.5M**********************//
            
            // (如果单个日志文件大于1.5M，则不进行切割或拼接，直接当成一个包返回)
            if (filedata.length >= __MAX_FILE_SIZE) {
                if (block) {
                    block([filedata base64EncodedStringWithOptions:0], @[filepath]);
                }
                return;
            }
            
            NSInteger expectedPacketLength = currentPacketLength + filedata.length;
            
            // (如果当前拼接包的预期大小超过1.5M，则打包返回，进行下一个包的拼接)
            if (expectedPacketLength > __MAX_FILE_SIZE) {
                if (block) {
                    block([filedata base64EncodedStringWithOptions:0], mutableLogFilesInPacket);
                }
                mutableLogPacketData = [NSMutableData data];
                mutableLogFilesInPacket = [NSMutableArray array];
                currentPacketLength = 0;
            }
            
            // 进行包的拼接
            [mutableLogPacketData appendData:filedata];
            [mutableLogFilesInPacket addObject:filepath];
            currentPacketLength = expectedPacketLength;
        }
    }];
    
    // 遍历结束后回调还未返回的包
    if (block && mutableLogPacketData.length) {
        block([mutableLogPacketData base64EncodedStringWithOptions:0], mutableLogFilesInPacket);
    }
}


- (BOOL)deleteOutdatedLogFiles
{
    __block BOOL allDeleted = YES;
    
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    
    NSDate *maxReservedDateAgo = [NSDate dateWithTimeIntervalSince1970:(currentTimestamp - __MAX_RESERVED_DATE)];
    
    [self enumerateLocalLogFilesFromDate:[NSDate distantPast] toDate:maxReservedDateAgo usingBlock:^(NSString *filepath, BOOL * _Nonnull stop) {
        
        if ([[NSFileManager defaultManager] removeItemAtPath:filepath error:nil] == NO) {
            allDeleted = NO;
        }
        
    }];
    
    return allDeleted;
}

- (void)flush
{
    clogan_flush();
}

- (void)flushInLogQueue
{
    dispatch_async(self.salvagerLogQueue, ^{
        clogan_flush();
    });
}

- (void)clearAllLogFiles
{
    [self enumerateLocalLogFilesFromDate:[NSDate distantPast] toDate:[NSDate distantFuture] usingBlock:^(NSString *filepath, BOOL * _Nonnull stop) {
        [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
    }];
}

- (void)removeAllOperation
{
    
}


#pragma mark - Private
- (void)_primitiveLog:(NSString *)primitiveLog withMillisecondTimestamp:(long long)millisecondTimestamp
{
    // 线程名称
    NSString *threadName = [[NSThread currentThread] name];
    char *threadNameC = threadName ? (char *)threadName.UTF8String : "";

    // 当前线程数量（如果在主线程调用，则不获取）
    NSInteger threadNum = 1;
    BOOL threadIsMain = [[NSThread currentThread] isMainThread];
    if (!threadIsMain) {
        threadNum = [self getCurrentThreadNumber];
    }
    
    // 拼接系统类参数
    primitiveLog = [primitiveLog stringByAppendingString:self.primitiveSystemSplicingFields];
    
    if (self.logInConsole) {
        [self _printfLogInConsole:primitiveLog];
    }
    
    // 检查剩余空间
    if (![self hasFreeSpace]) return;
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(self.salvagerLogQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        // 在首次打印或打印时间超出一小时（或打印时间被调到当前打印文件时间戳之前）新建小时时间戳文件
        if (strongSelf.lastLogFileHourMillisecondTimestamp == 0 ||
            millisecondTimestamp >= strongSelf.lastLogFileHourMillisecondTimestamp + __ONE_HOUR_MILLI_SECONDS ||
            millisecondTimestamp < strongSelf.lastLogFileHourMillisecondTimestamp) {

            strongSelf.lastLogFileHourMillisecondTimestamp = [strongSelf hourMillisecondTimestampWithCurrentMillisecondTimeStamp:millisecondTimestamp];

            // flush当前内存的内容，并打开新文件
            clogan_flush();

            NSString *lastLogFileHourMillisecondTimestampStr = [NSString stringWithFormat:@"%lld", strongSelf.lastLogFileHourMillisecondTimestamp];
            clogan_open((char *)lastLogFileHourMillisecondTimestampStr.UTF8String);

            // 存储最后一次打印文件的文件名（以备异常退出情况mmap恢复使用）
            [[NSUserDefaults standardUserDefaults] setObject:lastLogFileHourMillisecondTimestampStr forKey:LAST_LOG_TIMESTAMP_STORE_KEY];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        // clogan写入内容
        clogan_write(SGLogSalvageLogTypeDefault, (char *)primitiveLog.UTF8String, millisecondTimestamp, threadNameC, (long long)threadNum, (int)threadIsMain);
    });

}

- (void)cloganWithPrimitiveLog:(NSString *)primitiveLog withMillisecondTimestamp:(long long)millisecondTimestamp withThreadName:(NSString *)threadName withThreadNum:(NSInteger)threadNum andThreadIsMain:(BOOL)threadIsMain
{
//    clogan_write(SGLogSalvageLogTypeDefault, (char *)primitiveLog.UTF8String, millisecondTimestamp, (char *)threadName.UTF8String, (long long)threadNum, (int)threadIsMain);
//    clogan_write(SGLogSalvageLogTypeDefault, (char *)@"33333".UTF8String, 327874828, (char *)@"thread_name".UTF8String, (long long)1, (int)YES);
}

- (void)_printfLogInConsole:(NSString *)log
{
    static time_t dtime = -1;
    if (dtime == -1) {
        time_t tm;
        time(&tm);
        struct tm *t_tm;
        t_tm = localtime(&tm);
        dtime = t_tm->tm_gmtoff;
    }
    
    struct timeval time;
    gettimeofday(&time, NULL);
    int secOfDay = (time.tv_sec + dtime) % (3600 * 24);
    int hour = secOfDay / 3600;
    int minute = secOfDay % 3600 / 60;
    int second = secOfDay % 60;
    int millis = time.tv_usec / 1000;
    NSString *str = [[NSString alloc] initWithFormat:@"[SALVAGE_LOG]%02d:%02d:%02d.%03d [%lu] %@\n", hour, minute, second, millis, (unsigned long)SGLogSalvageLogTypeDefault, log];
    
    const char *buf = [str cStringUsingEncoding:NSUTF8StringEncoding];
    printf("%s", buf);
}


#pragma mark - 懒加载
- (dispatch_queue_t)salvagerLogQueue
{
    if (!_salvagerLogQueue) {
        _salvagerLogQueue = dispatch_queue_create("com.sogou.logan.salvagerLogQueue", DISPATCH_QUEUE_SERIAL);
    }
    return _salvagerLogQueue;
}

- (dispatch_queue_t)logUploadQueue
{
    if (!_logUploadQueue) {
        _logUploadQueue = dispatch_queue_create("com.sogou.logan.logUploadQueue", DISPATCH_QUEUE_SERIAL);
    }
    return _logUploadQueue;
}

#pragma mark - Directories
- (NSString *)salvageLogDirectory
{
    static NSString *dir = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dir = [self directoryInDocumentsDirWithName:@"Logan/log"];
    });
    return dir;
}

- (NSString *)loganCacheDirectory
{
    static NSString *dir = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dir = [self directoryInDocumentsDirWithName:@"Logan"];
    });
    return dir;
}

#pragma mark - Utils
- (NSString *)directoryInDocumentsDirWithName:(NSString *)dirName
{
    NSString *dir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:dirName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:dir] == NO) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

- (void)enumerateLocalLogFilesFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate usingBlock:(void (^)(NSString *filepath, BOOL * _Nonnull stop))block
{
    dispatch_group_t enumerateGroup = dispatch_group_create();
    
    if (!fromDate || !toDate) {
        return;
    }
    __weak typeof(self) weakSelf = self;

    // 遍历log文件需要放在打印队列（避免多线程问题）
    dispatch_group_async(enumerateGroup, self.salvagerLogQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *allLocalFiles = [fileManager contentsOfDirectoryAtPath:[self salvageLogDirectory] error:nil];
        
        [allLocalFiles enumerateObjectsUsingBlock:^(NSString * _Nonnull filename, NSUInteger idx, BOOL * _Nonnull stop) {
            @autoreleasepool {
                __strong typeof(weakSelf) strongSelf = weakSelf;

                NSString *filepath = [[strongSelf salvageLogDirectory] stringByAppendingPathComponent:filename];
                
                // 过滤非正常文件名文件（并删除）
                if (filename.length != 13) {
                    [fileManager removeItemAtPath:filepath error:nil];
                    return;
                }
                
                // 过滤不存在文件以及文件夹文件（并删除）
                BOOL isDir = NO;
                if (![fileManager fileExistsAtPath:filepath isDirectory:&isDir] || isDir == YES) {
                    [fileManager removeItemAtPath:filepath error:nil];
                    return;
                }
                
                // 过滤文件名为非时间戳的文件（并删除）
                long long millisecondTimestamp = [filename longLongValue];
                if (millisecondTimestamp == 0 || ![NSDate dateWithTimeIntervalSince1970:millisecondTimestamp/1000]) {
                    [fileManager removeItemAtPath:filepath error:nil];
                    return;
                }
                
                // 过滤时间段之外的文件
                NSDate *fileDate = [NSDate dateWithTimeIntervalSince1970:millisecondTimestamp/1000];
                
                if (!fileDate ||
                    [fileDate compare:fromDate] == NSOrderedAscending ||
                    [fileDate compare:toDate] == NSOrderedDescending) {
                    return;
                }
                
                // 回调过滤后的文件路径
                if (block) {
                    block(filepath, stop);
                }
            }
        }];
    });
    
    // 等待遍历完成（在log队列）之后才返回
    dispatch_group_wait(enumerateGroup, DISPATCH_TIME_FOREVER);
}

- (BOOL)syncUploadBase64StringLogPacket:(NSString *)base64StringLogPacket withTaskID:(NSString *)taskID
{
    __block BOOL uploadSuccess = NO;
    dispatch_semaphore_t uploadSema = dispatch_semaphore_create(0);
#ifdef LOG_SALVAGE_TEST
    NSMutableURLRequest *uploadRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://ares.ime.sogou/api/public/log/upload/testUploadLogBase64"]
      cachePolicy:NSURLRequestUseProtocolCachePolicy
      timeoutInterval:10.0];
    NSDictionary *headers = @{
      @"Content-Type": @"application/x-www-form-urlencoded",
      @"Cookie": @"IPISP=ISP; IPLOC=ZZ"
    };

    [uploadRequest setAllHTTPHeaderFields:headers];
    
    NSString *postStr = [NSString stringWithFormat:@"logData=%@", [self encodeURLParam:base64StringLogPacket]];
    
    [uploadRequest setHTTPBody:[postStr dataUsingEncoding:NSUTF8StringEncoding]];

    [uploadRequest setHTTPMethod:@"POST"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:uploadRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error && data) {
            NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
            NSLog(@"resp:%@", resp);
            if (resp &&
                [resp isKindOfClass:NSDictionary.class] &&
                [[(NSDictionary *)resp valueForKey:@"code"] intValue] == 200) {
                uploadSuccess = YES;
            }
        }
        dispatch_semaphore_signal(uploadSema);
    }] resume];

#else
    NSString *uploadURL = [NSString stringWithFormat:@"%@log_taskid=%@&log_v=1&log_data=%@", SALVAGE_LOG_UPLOAD_URL, task.taskID, [self encodeURLParam:base64StringLogPacket];
                           
    NSURLRequest *uploadRequest = [SGSURL requestWithCookieForUrl:uploadURL withParams:nil encrypt:YES];
    [[[NSURLSession sharedSession] dataTaskWithRequest:uploadRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //TODO:请求成功赋值
        if (!error && data) {
            NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
            
            if (resp &&
                [resp isKindOfClass:NSDictionary.class] &&
                [[(NSDictionary *)resp valueForKey:@"code"] intValue] == 200) {
                uploadSuccess = YES;
            }
        }
        dispatch_semaphore_signal(uploadSema);

    }] resume];
#endif
    dispatch_semaphore_wait(uploadSema, DISPATCH_TIME_FOREVER);
    return uploadSuccess;
}

- (NSInteger)getCurrentThreadNumber
{
    NSString *description = [[NSThread currentThread] description];
    NSRange beginRange = [description rangeOfString:@"{"];
    NSRange endRange = [description rangeOfString:@"}"];
    
    if (beginRange.location == NSNotFound || endRange.location == NSNotFound) return -1;
    
    NSInteger length = endRange.location - beginRange.location - 1;
    if (length < 1) {
        return -1;
    }
    
    NSRange keyRange = NSMakeRange(beginRange.location + 1, length);
    
    if (keyRange.location == NSNotFound) return -1;
    
    if (description.length > (keyRange.location + keyRange.length)) {
        NSString *keyPairs = [description substringWithRange:keyRange];
        NSArray *keyValuePairs = [keyPairs componentsSeparatedByString:@","];
        for (NSString *keyValuePair in keyValuePairs) {
            NSArray *components = [keyValuePair componentsSeparatedByString:@"="];
            if (components.count) {
                NSString *key = components[0];
                key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (([key isEqualToString:@"num"] ||
                    [key isEqualToString:@"number"]) &&
                    components.count > 1) {
                    return [components[1] integerValue];
                }
            }
        }
    }
    return -1;
}

- (NSString *)primitiveSystemSplicingFields
{
    if (!_primitiveSystemSplicingFields) {
        // IMEI
        NSString *devIMEI = [SGDeviceUtil uniqueIdentifier];
        devIMEI = (devIMEI && devIMEI.length) ? devIMEI : LogSalvager_NullStr;
        // IMSI
        NSString *devIMSI = [SGDeviceUtil IDFVIdentifier];
        devIMSI = (devIMSI && devIMSI.length) ? devIMSI : LogSalvager_NullStr;
        
        NSString *target = LogSalvager_NullStr;
#ifdef SOGOU_INPUT_APP
        target = @"APP";
#elif defined SOGOU_INPUT_EXTENSION
        target = @"KEYBOARD";
#endif
        _primitiveSystemSplicingFields = [NSString stringWithFormat:@"version=%@&&imei=%@&&imsi=%@&&target=%@", [SGDeviceUtil buildVersion], devIMEI, devIMSI, target];
    }
    return _primitiveSystemSplicingFields;
}

- (BOOL)hasFreeSpace
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    // 每隔至少1分钟，检查一下剩余空间
    if (now > (_lastCheckFreeSpace + 60)) {
        _lastCheckFreeSpace = now;
        long long freeDiskSpace = [self freeDiskSpaceInBytes];
        if (freeDiskSpace <= __MAX_FREE_SPACE) { // 剩余空间不足5M时，不再写入
            return NO;
        }
    }
    return YES;
}

- (long long)freeDiskSpaceInBytes
{
    struct statfs buf;
    long long freespace = -1;
    if (statfs("/var", &buf) >= 0) {
        freespace = (long long)(buf.f_bsize * buf.f_bfree);
    }
    return freespace;
}

- (NSString *)encodeURLParam:(NSString *)param
{
    if (!param) {
        return nil;
    }
    
    CFStringRef encodeParaCf = CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)param, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
    
    if (encodeParaCf == NULL) {
        return nil;
    }
    
    NSString *encodePara = (__bridge NSString *)(encodeParaCf);
    
    CFRelease(encodeParaCf);
    
    return encodePara;
}

#pragma mark - TimeInterval

/// 当前时间戳，精确到s
- (long long)currentMillisecondTimeStamp
{
    NSTimeInterval localTime = [[NSDate date] timeIntervalSince1970];
    return (long long)localTime*1000;
}

- (long long)hourMillisecondTimestampWithCurrentMillisecondTimeStamp:(long long)currentMillisecondTimestamp
{
    NSString *formatDateStr = [self.hourDateformatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:currentMillisecondTimestamp/1000]];
    return [self timeSwitchTimestamp:formatDateStr andFormatter:self.hourDateformatter]*1000;
}

- (long long)timeSwitchTimestamp:(NSString *)formatTime andFormatter:(NSDateFormatter *)formatter
{
    NSDate* date = [formatter dateFromString:formatTime];
    long long hourTimestamp = [[NSNumber numberWithDouble:[date timeIntervalSince1970]] longLongValue];
    return hourTimestamp;
}

- (NSDateFormatter *)hourDateformatter
{
    if (!_hourDateformatter) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        
        [formatter setDateFormat:@"YYYY-MM-dd HH"];
        NSTimeZone* timeZone = [NSTimeZone timeZoneWithName:@"Asia/Beijing"];
        [formatter setTimeZone:timeZone];
        _hourDateformatter = formatter;
    }
    return _hourDateformatter;
}



@end
