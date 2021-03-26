//
//  SGLogSalvagerTypes.h
//  SogouInput
//
//  Created by Aesthetic on 2020/12/4.
//  Copyright © 2020 Sogou.Inc. All rights reserved.
//

#ifndef SGLogSalvagerTypes_h
#define SGLogSalvagerTypes_h

#import <Foundation/Foundation.h>
#import "SGLogSalvagerMacros.h"

//TODO:后续可读性层面进行优化

@interface LogSalvagerAttacher : NSObject

@property (nonatomic, copy) NSString *attacherName;

@property (nonatomic, copy) NSString *attacherContent;

@end

typedef LogSalvagerAttacher* (^AttacherBlock)(void);

@interface LogSalvagerAttachment : NSObject

@property (nonatomic, copy) NSString *attachmentName;

@property (nonatomic, copy) NSString *attachmentContent;

@end

NS_INLINE LogSalvagerAttachment* CustomAttachment(NSString *name, NSString *content) {
    LogSalvagerAttachment *attachment = [LogSalvagerAttachment new];
    attachment.attachmentName = name;
    attachment.attachmentContent = content;
    return attachment;
}

#pragma mark - SGLogSalvageLogType
typedef NS_ENUM(int, SGLogSalvageLogType) {
    SGLogSalvageLogTypeDefault = 100,
};


#pragma mark - SGLogSalvagerBusinessID
typedef NS_ENUM(NSUInteger, SGLogSalvagerBusinessID) {
    SGLogSalvagerBusinessIDDefault = 1000,
};


#pragma mark - SGLogSalvageUploadProcessBlock
typedef void(^SGLogSalvageUploadProcessBlock)(NSArray<NSString *> *uploadedLogFiles, BOOL allLogFilesUploaded);



#pragma mark - LOG_SALVAGER_ATTACHER
typedef AttacherBlock LOG_SALVAGER_ATTACHER;

//当前方法名拼接
#define LOG_SALVAGER_FUNCTION_ATTACHER _SGLogSalvagerFunctionAttacher
//当前文件行拼接
#define LOG_SALVAGER_LINE_ATTACHER     _SGLogSalvagerLineAttacher
//当前文件名拼接
#define LOG_SALVAGER_FILE_ATTACHER     _SGLogSalvagerFileAttacher
//当前环境拼接（包括方法名、文件行、文件名）
#define LOG_SALVAGER_CONTEXT_ATTACHER  _SGLogSalvagerContextAttacher



#pragma mark - SGLogSalvagerCustomAttachmentFunc

typedef LogSalvagerAttachment* SGLogSalvagerCustomAttachmentFunc;

//当前设置项拼接函数
NS_INLINE SGLogSalvagerCustomAttachmentFunc LogSalvagerSettingsAttachment(NSString *content) {
    return CustomAttachment(@"settings", content);
}

//当前剩余内存拼接函数
NS_INLINE SGLogSalvagerCustomAttachmentFunc LogSalvagerResidentMemoryAttachment(NSString *content) {
    return CustomAttachment(@"resident_memory", content);
}

//当前系统状态拼接函数
NS_INLINE SGLogSalvagerCustomAttachmentFunc LogSalvagerSystemStateAttachment(NSString *content) {
    return CustomAttachment(@"system_state", content);
}
#endif /* SGLogSalvagerTypes_h */
