//
//  SGDeviceUtil.h
//  DEMO
//
//  Created by Aesthetic on 2020/12/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SGDeviceUtil : NSObject
+ (NSString *)buildVersion;

+ (NSString *)uniqueIdentifier;

+ (NSString *)IDFVIdentifier;
@end

NS_ASSUME_NONNULL_END
