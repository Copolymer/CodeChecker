//
//  SGLogSalvageTask.m
//  SogouInput
//
//  Created by kingsword on 2020/12/3.
//  Copyright © 2020 Sogou.Inc. All rights reserved.
//

#import "SGLogSalvageTask.h"

@implementation SGLogSalvageTask
/// 通过json初始化一个task对象
/// @param jsonObject json字符串、data、字典均可
+ (instancetype)taskWithJsonObject:(id)jsonObject
{
    return [SGLogSalvageTask new];
}

/// 任务是否有效，当任务创建时间距离当前时间超过4天，则任务无效
- (BOOL)isValid
{
    return YES;
}

/// 上传日志
- (void)uploadLogs
{
    
}

/// 更新当前任务已上传的文件列表
/// 当每次上传完一个文件后，都需要更新
/// @param logFile 已上传的文件
- (void)updateUploadedLogFile:(NSString *)logFile
{
    
}

@end
