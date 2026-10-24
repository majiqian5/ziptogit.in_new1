#import "AxsPlayerPulseConfig.h"
#import "AxsPlayerPulsePreferences.h"

@interface AxsPlayerPulseConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void axs_playerpulse_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    AxsPlayerPulseConfig *config = (__bridge AxsPlayerPulseConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config axs_playerpulse_reload];
    });
}

@implementation AxsPlayerPulseConfig

+ (instancetype)axs_playerpulse_shared {
    static AxsPlayerPulseConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.axs.playerpulse.preferences", DISPATCH_QUEUE_SERIAL);
        [self axs_playerpulse_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, axs_playerpulse_preferencesDidChange,
            (__bridge CFStringRef)AxsPlayerPulsePreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self axs_playerpulse_reload]; });
    }
    return self;
}

- (void)axs_playerpulse_reload {
    self.snapshot = axs_playerpulse_readPreferences();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AxsPlayerPulsePreferencesChanged object:self];
    });
}

- (id)axs_playerpulse_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (BOOL)axs_playerpulse_isEnabled {
    id value = [self axs_playerpulse_valueForKey:@"enabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
