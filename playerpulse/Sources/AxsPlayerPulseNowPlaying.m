#import "AxsPlayerPulseNowPlaying.h"
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>

NSString * const AxsPlayerPulseNowPlayingDidChangeNotification =
    @"com.axs.playerpulse.nowplaying-changed";

// MediaRemote is resolved dynamically: the private framework is present on
// iOS, but its headers/tbd are not guaranteed in every Theos SDK.
typedef void (*axs_playerpulse_get_info_t)(dispatch_queue_t queue,
                                            void (^handler)(CFDictionaryRef information));
typedef void (*axs_playerpulse_register_t)(dispatch_queue_t queue);

static const CFStringRef AxsPlayerPulseNowPlayingInfoChanged =
    CFSTR("kMRMediaRemoteNowPlayingInfoDidChangeNotification");
static const CFStringRef AxsPlayerPulsePlaybackStateChanged =
    CFSTR("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification");

@interface AxsPlayerPulseNowPlaying ()
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) double playbackRate;
@property (nonatomic, assign) NSTimeInterval elapsed;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) CFTimeInterval elapsedStamp;
@property (nonatomic, strong) UIImage *artwork;
@property (nonatomic, copy) NSArray<UIColor *> *artworkColors;
@property (nonatomic, assign) NSUInteger seed;
@property (nonatomic, assign) NSUInteger artworkKey;
@property (nonatomic, assign) BOOL observing;
@property (nonatomic, assign) CFTimeInterval lastRequest;
@property (nonatomic, assign) BOOL requestInFlight;
@property (nonatomic, strong) NSTimer *pollTimer;
- (void)axs_playerpulse_requestNowPlayingInfo;
- (void)axs_playerpulse_consumeNowPlayingInfo:(NSDictionary *)info;
- (void)axs_playerpulse_extractColorsFromImage:(UIImage *)image key:(NSUInteger)key;
- (void)axs_playerpulse_notifyChange;
+ (NSArray<UIColor *> *)axs_playerpulse_paletteForImage:(UIImage *)image;
@end

static void axs_playerpulse_now_playing_external_change(CFNotificationCenterRef center, void *observer,
                                                   CFStringRef name, const void *object,
                                                   CFDictionaryRef userInfo) {
    AxsPlayerPulseNowPlaying *provider = (__bridge AxsPlayerPulseNowPlaying *)observer;
    dispatch_async(dispatch_get_main_queue(), ^{
        [provider axs_playerpulse_refreshForce];
    });
}

static axs_playerpulse_get_info_t axs_playerpulse_get_info_function(void) {
    static axs_playerpulse_get_info_t function;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        function = (axs_playerpulse_get_info_t)dlsym(RTLD_DEFAULT,
                                                       "MRMediaRemoteGetNowPlayingInfo");
    });
    return function;
}

static axs_playerpulse_register_t axs_playerpulse_register_function(void) {
    static axs_playerpulse_register_t function;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        function = (axs_playerpulse_register_t)dlsym(RTLD_DEFAULT,
                    "MRMediaRemoteRegisterForNowPlayingNotifications");
    });
    return function;
}

@implementation AxsPlayerPulseNowPlaying

+ (instancetype)axs_playerpulse_shared {
    static AxsPlayerPulseNowPlaying *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)axs_playerpulse_startObserving {
    if (self.observing) {
        [self axs_playerpulse_refreshForce];
        return;
    }
    self.observing = YES;

    axs_playerpulse_register_t registerFunction = axs_playerpulse_register_function();
    if (registerFunction) registerFunction(dispatch_get_main_queue());

    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, (__bridge const void *)self,
        axs_playerpulse_now_playing_external_change, AxsPlayerPulseNowPlayingInfoChanged,
        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, (__bridge const void *)self,
        axs_playerpulse_now_playing_external_change, AxsPlayerPulsePlaybackStateChanged,
        NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    __weak typeof(self) weakSelf = self;
    self.pollTimer = [NSTimer timerWithTimeInterval:5.0 repeats:YES block:^(NSTimer *timer) {
        [weakSelf axs_playerpulse_refreshIfNeeded];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];

    [self axs_playerpulse_refreshForce];
}

- (void)axs_playerpulse_refreshIfNeeded {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastRequest < 1.0) return;
    [self axs_playerpulse_requestNowPlayingInfo];
}

- (void)axs_playerpulse_refreshForce {
    self.lastRequest = 0;
    [self axs_playerpulse_requestNowPlayingInfo];
}

- (void)axs_playerpulse_requestNowPlayingInfo {
    if (self.requestInFlight) return;
    axs_playerpulse_get_info_function getInfo = axs_playerpulse_get_info_function();
    if (!getInfo) return;

    self.requestInFlight = YES;
    self.lastRequest = CACurrentMediaTime();

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.requestInFlight) strongSelf.requestInFlight = NO;
    });
    getInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.requestInFlight = NO;
        if (information) {
            [strongSelf axs_playerpulse_consumeNowPlayingInfo:(__bridge NSDictionary *)information];
        }
    });
}

- (void)axs_playerpulse_consumeNowPlayingInfo:(NSDictionary *)info {
    if (![info isKindOfClass:[NSDictionary class]]) return;

    NSNumber *rate = info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
    NSNumber *elapsed = info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"];
    NSNumber *duration = info[@"kMRMediaRemoteNowPlayingInfoDuration"];
    NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
    NSString *artist = info[@"kMRMediaRemoteNowPlayingInfoArtist"];
    NSString *album = info[@"kMRMediaRemoteNowPlayingInfoAlbum"];
    NSData *artworkData = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];

    double newRate = [rate isKindOfClass:[NSNumber class]] ? rate.doubleValue : 0.0;
    NSTimeInterval newElapsed = [elapsed isKindOfClass:[NSNumber class]] ? elapsed.doubleValue : 0.0;
    NSTimeInterval newDuration = [duration isKindOfClass:[NSNumber class]] ? duration.doubleValue : 0.0;

    self.playbackRate = newRate;
    self.isPlaying = newRate > 0.05;
    self.elapsed = newElapsed;
    self.duration = newDuration;
    self.elapsedStamp = CACurrentMediaTime();

    NSString *identity = [NSString stringWithFormat:@"%@|%@|%@|%.0f",
                          title ?: @"", artist ?: @"", album ?: @"", newDuration];
    self.seed = identity.hash;

    if ([artworkData isKindOfClass:[NSData class]] && artworkData.length > 0) {
        NSUInteger key = artworkData.hash;
        if (key != self.artworkKey || !self.artwork) {
            self.artworkKey = key;
            UIImage *image = [UIImage imageWithData:artworkData];
            self.artwork = image;
            self.artworkColors = @[];
            if (image) [self axs_playerpulse_extractColorsFromImage:image key:key];
        }
    } else if (self.artworkKey != 0) {
        self.artworkKey = 0;
        self.artwork = nil;
        self.artworkColors = @[];
    }

    [self axs_playerpulse_notifyChange];
}

- (void)axs_playerpulse_extractColorsFromImage:(UIImage *)image key:(NSUInteger)key {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSArray<UIColor *> *colors = [AxsPlayerPulseNowPlaying axs_playerpulse_paletteForImage:image];
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.artworkKey != key) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.artworkColors = colors;
            [strongSelf axs_playerpulse_notifyChange];
        });
    });
}

- (void)axs_playerpulse_notifyChange {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AxsPlayerPulseNowPlayingDidChangeNotification object:self];
}

- (NSTimeInterval)axs_playerpulse_currentElapsed {
    NSTimeInterval base = self.elapsed;
    if (self.isPlaying && self.playbackRate > 0.01) {
        base += (CACurrentMediaTime() - self.elapsedStamp) * self.playbackRate;
    }
    if (self.duration > 1.0 && base > self.duration) {
        base = fmod(base, self.duration);
    }
    return MAX(0.0, base);
}

// Average artwork colour plus two harmonised companions. Kept on a background
// queue; the CI context is thread-safe and reused.
+ (NSArray<UIColor *> *)axs_playerpulse_paletteForImage:(UIImage *)image {
    if (!image) return @[];
    CIImage *input = nil;
    if (image.CGImage) {
        input = [[CIImage alloc] initWithCGImage:image.CGImage];
    } else if (image.CIImage) {
        input = image.CIImage;
    }
    if (!input) return @[];

    static CIContext *context;
    static CGColorSpaceRef colorSpace;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
        colorSpace = CGColorSpaceCreateDeviceRGB();
    });

    CIFilter *average = [CIFilter filterWithName:@"CIAreaAverage"
                                  keysAndValues:kCIInputImageKey, input,
                        kCIInputExtentKey, [CIVector vectorWithCGRect:input.extent], nil];
    CIImage *output = average.outputImage;
    if (!output) return @[];

    unsigned char rgba[4] = {0, 0, 0, 0};
    [context render:output toBitmap:rgba rowBytes:4
             bounds:CGRectMake(0, 0, 1, 1) format:kCIFormatRGBA8
         colorSpace:colorSpace];

    CGFloat red = rgba[0] / 255.0, green = rgba[1] / 255.0, blue = rgba[2] / 255.0;
    UIColor *base = [UIColor colorWithRed:red green:green blue:blue alpha:1.0];

    CGFloat hue = 0, saturation = 0, brightness = 0, alpha = 1;
    if (![base getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        hue = 0.55; saturation = 0.6; brightness = 0.9;
    }
    saturation = MAX(0.45, MIN(1.0, saturation * 1.25));
    brightness = MAX(0.55, MIN(1.0, brightness * 1.15));

    UIColor *primary = [UIColor colorWithHue:hue saturation:saturation
                                  brightness:brightness alpha:1.0];
    UIColor *secondary = [UIColor colorWithHue:fmod(hue + 0.10, 1.0)
                                     saturation:MAX(0.4, saturation * 0.9)
                                     brightness:MIN(1.0, brightness * 1.05) alpha:1.0];
    UIColor *tertiary = [UIColor colorWithHue:fmod(hue + 0.20, 1.0)
                                    saturation:MAX(0.35, saturation * 0.8)
                                    brightness:MIN(1.0, brightness * 0.95) alpha:1.0];
    return @[primary, secondary, tertiary];
}

@end
