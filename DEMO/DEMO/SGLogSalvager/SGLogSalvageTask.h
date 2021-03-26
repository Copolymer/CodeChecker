//
//  SGLogSalvageTask.h
//  SogouInput
//  日志打捞任务
//  Created by kingsword on 2020/12/3.
//  Copyright © 2020 Sogou.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    SGLogSalvageTaskUploadTypeWIFI = 1,   //WIFI
    SGLogSalvageTaskUploadTypeALL         //WIFI+移动网络
} SGLogSalvageTaskUploadType;

typedef enum : NSUInteger {
    SGLogSalvageTaskStateIdle,
    SGLogSalvageTaskStateUploading,
    SGLogSalvageTaskStateFinished,
} SGLogSalvageTaskState;

@interface SGLogSalvageTask : NSObject

/// 任务ID，唯一标识符
@property (nonatomic, copy) NSString *taskID;

/// 创建时间
@property (nonatomic, strong) NSDate *createdTime;

/// 要打捞的日志的开始时间
@property (nonatomic, assign) CFAbsoluteTime startTime;

/// 要打捞的日志的结束时间
@property (nonatomic, assign) CFAbsoluteTime endTime;

/// 日志上传方式 1.WIFI 2.任意网络下
@property (nonatomic, assign) SGLogSalvageTaskUploadType uploadType;

//@property (nonatomic, copy) NSArray <NSString *> *extraFiles;

/// 任务状态：空闲，上传中，已完成
@property (nonatomic, assign) SGLogSalvageTaskState taskState;

/// 已经上传完的日志文件列表，避免本次没传完，下次续传的时候重复上传文件
@property (nonatomic, strong) NSMutableArray *uploadedLogFiles;

/// 通过json初始化一个task对象
/// @param jsonObject json字符串、data、字典均可
+ (instancetype)taskWithJsonObject:(id)jsonObject;

/// 任务是否有效，当任务创建时间距离当前时间超过4天，则任务无效
- (BOOL)isValid;

/// 上传日志
- (void)uploadLogs;

/// 更新当前任务已上传的文件列表
/// 当每次上传完一个文件后，都需要更新
/// @param logFile 已上传的文件
- (void)updateUploadedLogFile:(NSString *)logFile;

@end

NS_ASSUME_NONNULL_END
