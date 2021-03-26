//
//  SGLogSalvagerMacros.h
//  DEMO
//
//  Created by Aesthetic on 2020/12/14.
//

#ifndef SGLogSalvagerMacros_h
#define SGLogSalvagerMacros_h

#define _SGLogSalvagerAttacher(name, content) \
^(void) {LogSalvagerAttacher *attacher = [LogSalvagerAttacher new]; attacher.attacherName = name; attacher.attacherContent = content; return attacher;}

#define LOG_SALVAGER_FUNCTION_FORMAT_STR [[NSString stringWithFormat:@"%s", __FUNCTION__] componentsSeparatedByString:@"_block_invoke"].count? [[[NSString stringWithFormat:@"%s", __FUNCTION__] componentsSeparatedByString:@"_block_invoke"] firstObject]:@"null"

#define _SGLogSalvagerFunctionAttacher \
_SGLogSalvagerAttacher(@"func", (LOG_SALVAGER_FUNCTION_FORMAT_STR))

#define _SGLogSalvagerLineAttacher \
_SGLogSalvagerAttacher(@"line", ([NSString stringWithFormat:@"%d", __LINE__]))

#define _SGLogSalvagerFileAttacher \
_SGLogSalvagerAttacher(@"file", ([NSString stringWithFormat:@"%s", __FILE__]))

#define _SGLogSalvagerContextAttacher \
_SGLogSalvagerAttacher(@"context", ([NSString stringWithFormat:@"{func=%@, line=%d, file=%s}", LOG_SALVAGER_FUNCTION_FORMAT_STR, __LINE__, __FILE__]))


#endif /* SGLogSalvagerMacros_h */
