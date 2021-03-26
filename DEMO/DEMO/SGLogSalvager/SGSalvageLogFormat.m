//
//  SGSalvageLogFormat.m
//  SogouInput
//
//  Created by Aesthetic on 2020/12/4.
//  Copyright © 2020 Sogou.Inc. All rights reserved.
//

#import "SGSalvageLogFormat.h"
#import <YYModel.h>

@implementation NSString (SGLogSalvager)
- (NSString *)salvageLogFormat
{
    return [self description];
}
@end


@implementation NSArray (SGLogSalvager)
- (NSString *)salvageLogFormat
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingFragmentsAllowed error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
@end


@implementation NSDictionary (SGLogSalvager)
- (NSString *)salvageLogFormat
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingFragmentsAllowed error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
@end
