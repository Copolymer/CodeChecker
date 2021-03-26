//
//  SGLogSalvager.h
//  SogouInput
//
//  Created by Aesthetic on 2020/12/4.
//  Copyright © 2020 Sogou.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SGLogSalvagerTypes.h"
#import "SGSalvageLogFormat.h"

@class SGLogSalvageTask;

NS_ASSUME_NONNULL_BEGIN

/**
 Sample Code:
    @implementation SampleClass
    - (void) sampleMethod  {
        SGLogSalvager *salvager = [SGLogSalvager new];
 
        //  实际输出：business_id=1000&&log=xxx&&func=-[SampleClass sampleMethod]
        [salvager log:@"xxx" withBusinessID:SGLogSalvagerBusinessIDDefault andAttacher:LOG_SALVAGER_FUNCTION_ATTACHER];
 
        // 实际输出：business_id=1000&&log=[log1, log2]
        [salvager log:@[@"log1", @"log2"] withBusinessID:(SGLogSalvagerBusinessIDDefault) andAttacher:LOG_SALVAGER_FUNCTION_ATTACHER and];
                    
        // 实际输出：business_id=1000&&log={log : xxx}&&settings=settings
        [salvager log:@{@"log":@"xxx"} withBusinessID:(SGLogSalvagerBusinessIDDefault) andAttacher:LOG_SALVAGER_FUNCTION_ATTACHER andCustomAttachments:LogSalvagerSettingsAttachment(@"settings"), nil];
    }
    @end
 */

@interface SGLogSalvager : NSObject

/// YES：在打印区打印并记录到本地， NO：只记录到本地
@property (nonatomic, assign) BOOL logInConsole;

/// 记录日志调用接口
/// @param log 日志（目前仅支持NSArray，NSString，NSDictionary，开发者可扩展）
/// @param businessID 业务ID
/// @param attacher 拼接器（用于外部获取调用环境信息，
/// 目前包括LOG_SALVAGER_FUNCTION_ATTACHER，LOG_SALVAGER_LINE_ATTACHER， LOG_SALVAGER_FILE_ATTACHER，LOG_SALVAGER_CONTEXT_ATTACHER四种）
- (void)log:(id<SGSalvageLogFormat>)log withBusinessID:(SGLogSalvagerBusinessID)businessID andAttacher:(nullable LOG_SALVAGER_ATTACHER)attacher;

//TODO:测一下该方法的性能
/// 记录日志调用接口
/// @param log  日志（目前仅支持NSArray，NSString，NSDictionary，开发者可扩展）
/// @param businessID 业务ID
/// @param attacher 拼接器（用于外部获取调用环境信息，
/// 目前包括LOG_SALVAGER_FUNCTION_ATTACHER，LOG_SALVAGER_LINE_ATTACHER， LOG_SALVAGER_FILE_ATTACHER，LOG_SALVAGER_CONTEXT_ATTACHER四种）
/// @param customAttachmentFunc 自定义拼接函数
- (void)log:(id<SGSalvageLogFormat>)log withBusinessID:(SGLogSalvagerBusinessID)businessID andAttacher:(nullable LOG_SALVAGER_ATTACHER)attacher andCustomAttachments:(nullable SGLogSalvagerCustomAttachmentFunc)customAttachmentFunc, ... NS_REQUIRES_NIL_TERMINATION;


/// 上传日志文件
/// @param task 上传任务
/// @param processBlock 文件上传调用
- (void)uploadLogFilesWithTask:(SGLogSalvageTask *)task withProcessBlock:(SGLogSalvageUploadProcessBlock)processBlock;


/// 删除过期日志文件（4天之前）
- (BOOL)deleteOutdatedLogFiles;

/// flush当前记录log文件到磁盘（该操作加入到log队列）
- (void)flush;

- (void)clearAllLogFiles;
- (void)removeAllOperation;
@end

NS_ASSUME_NONNULL_END
