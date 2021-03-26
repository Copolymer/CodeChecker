//
//  ViewController.m
//  DEMO
//
//  Created by Aesthetic on 2020/11/13.
//

#import "ViewController.h"
#import "SGLogSalvager.h"
#import <AVFoundation/AVFoundation.h>
#import "SGLogSalvageTask.h"
#import <clogan_core.h>
#import "TYStatistics.h"
#include <string.h>
#include <stdlib.h>
#import "Son.h"
#import "fishhook.h"
#include <dlfcn.h>

@interface ViewController ()
@property (nonatomic, strong) SGLogSalvager *salvager;

@property (nonatomic, strong) SGLogSalvageTask *task;

@property (weak, nonatomic) IBOutlet UILabel *showLabel;
@property (nonatomic, strong) dispatch_queue_t salvagerLogQueue;

@end


int new_clogan_open(char *name)
{
    printf("new_clogan_open");
    return 1;
}

static int (*orig_clogan_open)(char *name);


@implementation ViewController
+ (void)load
{
    struct rcd_rebinding Binds[1];
    
    Binds[0] = (struct rcd_rebinding){"clogan_open", new_clogan_open, (void *)&orig_clogan_open};
    
    rcd_rebind_symbols(Binds, 1);
    
}

- (IBAction)flush:(id)sender {
//    [_salvager flush];
//    [_salvager removeAllOperation];
    [self.showLabel setText:@""];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _salvager = [SGLogSalvager new];
    _salvager.logInConsole = YES;
    
//    _task = [SGLogSalvageTask new];
//
//    _task.taskID = @"1234";
//
//    _task.startTime = 1607374800;
//    _task.endTime = 1607569200;

//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//
//        [self.salvager uploadLogFilesWithTask:self.task withProcessBlock:^(NSArray<NSString *> *uploadedLogFiles, BOOL allLogFilesUploaded) {
//            NSLog(@"uploadedFiles:%@, allLogFilesUploaded:%d", uploadedLogFiles, allLogFilesUploaded);
//        }];
//
//    });
    
    NSError *error = [NSError errorWithDomain:NSMachErrorDomain code:100 userInfo:nil];
    [_salvager log:@"333" withBusinessID:(SGLogSalvagerBusinessIDDefault) andAttacher:LOG_SALVAGER_FUNCTION_ATTACHER];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self encodeURLParam:@"fejoajfehfuia"];

}

- (NSString *)encodeURLParam:(NSString *)param
{
    void *PC = __builtin_return_address(0);
    
    Dl_info info;
    dladdr(PC, &info);
     
    NSLog(@"name:%s, %p, %p, %s", info.dli_fname, info.dli_fbase, info.dli_saddr, info.dli_sname);
    
    self.showLabel.text = [NSString stringWithFormat:@"%s", info.dli_sname];
    
    
    if (!param) {
        return nil;
    }
    
    CFStringRef encodeParaCf = CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)param, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
        
    if (encodeParaCf == NULL) {
        return nil;
    }
    
    NSString *encodeParam = (__bridge NSString *)encodeParaCf;
//    NSLog(@"%ld", (long)CFGetRetainCount(encodeParaCf));
    
//    NSString *encodeParam = (NSString *)CFBridgingRelease(encodeParaCf);
    CFRelease(encodeParaCf);
//    NSLog(@"%ld", (long)CFGetRetainCount(encodeParaCf));

    return encodeParam;
}

- (void)run
{
    
//        [_salvager log:@"3333" withBusinessID:SGLogSalvagerBusinessIDDefault andAttacher:LOG_SALVAGER_FUNCTION_ATTACHER];
//        [_salvager log:@"2333" withBusinessID:SGLogSalvagerBusinessIDDefault andAttacher:LOG_SALVAGER_FUNCTION_ATTACHER];
//        dispatch_async(self.salvagerLogQueue, ^{
//        });
}

- (dispatch_queue_t)salvagerLogQueue
{
    if (!_salvagerLogQueue) {
        _salvagerLogQueue = dispatch_queue_create("com.sogou.queue", DISPATCH_QUEUE_SERIAL);
    }
    return _salvagerLogQueue;
}


@end
