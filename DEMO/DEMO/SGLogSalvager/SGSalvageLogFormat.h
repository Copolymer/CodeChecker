//
//  SGSalvageLogFormat.h
//  SogouInput
//
//  Created by Aesthetic on 2020/12/4.
//  Copyright © 2020 Sogou.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SGSalvageLogFormat <NSObject>

@required
- (NSString *)salvageLogFormat;

@end

@interface NSString (SGLogSalvager)<SGSalvageLogFormat>

@end

@interface NSArray (SGLogSalvager)<SGSalvageLogFormat>

@end

@interface NSDictionary (SGLogSalvager)<SGSalvageLogFormat>

@end


NS_ASSUME_NONNULL_END
