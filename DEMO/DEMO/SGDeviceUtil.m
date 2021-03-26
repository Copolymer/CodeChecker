//
//  SGDeviceUtil.m
//  DEMO
//
//  Created by Aesthetic on 2020/12/7.
//

#import "SGDeviceUtil.h"

@implementation SGDeviceUtil
+ (NSString *)buildVersion
{
    NSString* versionPlistPath = [[NSBundle mainBundle] pathForResource:@"version" ofType:@"plist"];
    NSDictionary *versionDict = [NSDictionary dictionaryWithContentsOfFile:versionPlistPath];
    NSString *version = [versionDict objectForKey:@"kBuildVersion"];
    NSString *versionCount = [versionDict objectForKey:@"kBuildVersionCount"];
    return [NSString stringWithFormat:@"%@-%@", versionCount, version];
}

+ (NSString *)uniqueIdentifier
{
    return @"";
}

+ (NSString *)IDFVIdentifier
{
    return @"";
}
@end
