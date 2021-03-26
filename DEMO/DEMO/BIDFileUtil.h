//
//  BIDFileUtil.h
//  AutoTestPlatform
//
//  Created by Aesthetic on 2018/9/19.
//  Copyright © 2018年 Aesthetic. All rights reserved.
//

#import <Foundation/Foundation.h>


#define BIDFetchUpScreen                   @"BIDFetchUpScreen"
#define BIDUpScreenInfo                    @"BIDUpScreenInfo"

#define ATIPHONETESTFINISH      @"ATiPhoneTestFinish"

#define TYPE_RESTART    1
#define TYPE_CONTINUE   0

/**快速打印结果*/
void KSLog(NSString *log, ...);
/**快速存储结果*/
FOUNDATION_EXPORT void NYLog(NSString * log, NSString *path);

FOUNDATION_EXPORT void DebugLog(NSString *format, ...)NS_FORMAT_FUNCTION(1,2) NS_NO_TAIL_CALL;

@interface BIDFileUtil : NSObject

/**获取文件路径*/
+ (NSString *)getDocumentsDir;

+ (NSString *)getScriptDir;

+ (NSString *)getTaskFilePath;

+ (NSString *)getChangeDir;

+ (NSString *)getResultDir;
+ (NSString *)resultDir;

/**创建文件-写文件-移除文件*/
+ (BOOL)createFileIfNotExist:(NSString *)path;

+ (BOOL)createFolderIfNotExist:(NSString *)path;

+ (BOOL)writeFileAtEnd:(NSString *)path result:(NSString *)res;

+ (BOOL)removeAllElements:(NSString *)path;
@end
