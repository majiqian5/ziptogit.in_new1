#import "AxsPlayerPulseBackdropView.h"
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>

@interface AxsPlayerPulseBackdropView ()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) CAGradientLayer *shadeLayer;
@property (nonatomic, assign) NSUInteger artworkKey;
@property (nonatomic, assign) NSUInteger pendingKey;
+ (NSCache<NSNumber *, UIImage *> *)axs_playerpulse_blurCache;
+ (CIContext *)axs_playerpulse_imageContext;
+ (UIImage *)axs_playerpulse_blurredImage:(UIImage *)image;
@end

@implementation AxsPlayerPulseBackdropView

+ (NSCache<NSNumber *, UIImage *> *)axs_playerpulse_blurCache {
    static NSCache<NSNumber *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 6;
    });
    return cache;
}

+ (CIContext *)axs_playerpulse_imageContext {
    static CIContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
    });
    return context;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;

        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
        [self addSubview:_imageView];

        _shadeLayer = [CAGradientLayer layer];
        _shadeLayer.colors = @[(__bridge id)[UIColor colorWithWhite:0.0 alpha:0.12].CGColor,
                               (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.46].CGColor];
        _shadeLayer.locations = @[@0.0, @1.0];
        _shadeLayer.startPoint = CGPointMake(0.5, 0.0);
        _shadeLayer.endPoint = CGPointMake(0.5, 1.0);
        [self.layer addSublayer:_shadeLayer];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageView.frame = self.bounds;
    self.shadeLayer.frame = self.bounds;
}

- (void)axs_playerpulse_applyArtwork:(UIImage *)artwork
          artworkKey:(NSUInteger)artworkKey
            opacity:(CGFloat)opacity
       cornerRadius:(CGFloat)cornerRadius {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.imageView.alpha = opacity;
    self.shadeLayer.opacity = (float)MIN(1.0, MAX(0.0, opacity + 0.25));
    self.layer.cornerRadius = cornerRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = cornerRadius > 0.0;
    [CATransaction commit];

    if (!artwork || artworkKey == 0) {
        self.artworkKey = 0;
        self.pendingKey = 0;
        self.imageView.image = nil;
        return;
    }
    if (artworkKey == self.artworkKey && self.imageView.image) return;
    if (artworkKey == self.pendingKey) return;

    NSCache<NSNumber *, UIImage *> *cache = [AxsPlayerPulseBackdropView axs_playerpulse_blurCache];
    UIImage *cached = [cache objectForKey:@(artworkKey)];
    if (cached) {
        self.artworkKey = artworkKey;
        self.imageView.image = cached;
        return;
    }

    self.pendingKey = artworkKey;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        UIImage *blurred = [AxsPlayerPulseBackdropView axs_playerpulse_blurredImage:artwork] ?: artwork;
        if (blurred) [cache setObject:blurred forKey:@(artworkKey)];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.pendingKey != artworkKey) return;
            strongSelf.pendingKey = 0;
            strongSelf.artworkKey = artworkKey;
            strongSelf.imageView.image = blurred;
        });
    });
}

+ (UIImage *)axs_playerpulse_blurredImage:(UIImage *)image {
    CGImageRef source = image.CGImage;
    if (!source) return image;

    CGFloat width = CGImageGetWidth(source);
    CGFloat height = CGImageGetHeight(source);
    if (width <= 0 || height <= 0) return image;

    CGFloat scale = MIN(1.0, 260.0 / MAX(width, height));
    CIImage *input = [CIImage imageWithCGImage:source];
    CIImage *scaled = [input imageByApplyingTransform:
                       CGAffineTransformMakeScale(scale, scale)];
    CGRect extent = CGRectIntegral(scaled.extent);

    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setValue:scaled forKey:kCIInputImageKey];
    [filter setValue:@18.0 forKey:kCIInputRadiusKey];
    CIImage *output = [[filter outputImage] imageByCroppingToRect:extent];
    if (!output) return image;

    CGImageRef rendered = [[AxsPlayerPulseBackdropView axs_playerpulse_imageContext]
                           createCGImage:output fromRect:extent];
    if (!rendered) return image;
    UIImage *result = [UIImage imageWithCGImage:rendered scale:1.0
                                    orientation:UIImageOrientationUp];
    CGImageRelease(rendered);
    return result ?: image;
}

@end
