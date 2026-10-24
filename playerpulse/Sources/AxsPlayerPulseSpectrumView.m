#import "AxsPlayerPulseSpectrumView.h"
#import "AxsPlayerPulseNowPlaying.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static double axs_playerpulse_fract(double value) {
    return value - floor(value);
}

static double axs_playerpulse_unit(double value) {
    return fmax(0.0, fmin(1.0, value));
}

@interface AxsPlayerPulseSpectrumView ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *levels;
@property (nonatomic, strong) NSArray<UIColor *> *barColors;
@property (nonatomic, strong) NSArray<UIColor *> *artworkColors;
@property (nonatomic, strong) AxsPlayerPulseStyle *style;
@property (nonatomic, strong) CAGradientLayer *barGradient;
@property (nonatomic, strong) CAGradientLayer *waveGradient;
@property (nonatomic, strong) CAShapeLayer *barMask;
@property (nonatomic, strong) CAShapeLayer *waveMask;
@property (nonatomic, strong) CAShapeLayer *waveLine;
@property (nonatomic, assign) NSInteger barCount;
@property (nonatomic, assign) NSInteger activeCount;
@property (nonatomic, assign) NSInteger renderStyle;
@property (nonatomic, assign) NSInteger theme;
@property (nonatomic, assign) CGFloat speed;
@property (nonatomic, assign) CFTimeInterval lastTick;
@property (nonatomic, assign) CFTimeInterval idlePhase;
@property (nonatomic, assign) NSUInteger seed;
@property (nonatomic, assign) NSUInteger tickCount;
- (void)axs_playerpulse_updateActiveCount;
- (void)axs_playerpulse_rebuildLevels;
- (void)axs_playerpulse_rebuildColors;
- (void)axs_playerpulse_render;
- (UIBezierPath *)axs_playerpulse_barPath;
- (UIBezierPath *)axs_playerpulse_wavePath;
- (void)axs_playerpulse_handleTick:(CADisplayLink *)link;
@end

@implementation AxsPlayerPulseSpectrumView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.isAccessibilityElement = NO;
        self.layer.allowsGroupOpacity = NO;

        _levels = [NSMutableArray array];
        _barColors = @[];
        _artworkColors = @[];
        _barCount = 0;
        _activeCount = 0;
        _speed = 1.0;

        _barGradient = [CAGradientLayer layer];
        _barGradient.startPoint = CGPointMake(0.0, 0.5);
        _barGradient.endPoint = CGPointMake(1.0, 0.5);
        _barMask = [CAShapeLayer layer];
        _barMask.fillColor = [UIColor blackColor].CGColor;
        _barMask.fillRule = kCAFillRuleNonZero;
        _barGradient.mask = _barMask;
        [self.layer addSublayer:_barGradient];

        _waveGradient = [CAGradientLayer layer];
        _waveGradient.startPoint = CGPointMake(0.0, 0.5);
        _waveGradient.endPoint = CGPointMake(1.0, 0.5);
        _waveMask = [CAShapeLayer layer];
        _waveMask.fillColor = [UIColor blackColor].CGColor;
        _waveGradient.mask = _waveMask;
        _waveGradient.hidden = YES;
        [self.layer addSublayer:_waveGradient];

        _waveLine = [CAShapeLayer layer];
        _waveLine.fillColor = [UIColor clearColor].CGColor;
        _waveLine.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35].CGColor;
        _waveLine.lineWidth = 1.0;
        _waveLine.lineJoin = kCALineJoinRound;
        _waveLine.lineCap = kCALineCapRound;
        _waveLine.hidden = YES;
        [self.layer addSublayer:_waveLine];
    }
    return self;
}

- (void)dealloc {
    [_displayLink invalidate];
}

- (void)axs_playerpulse_applyStyle:(AxsPlayerPulseStyle *)style {
    if (!style) return;
    self.style = style;
    self.speed = style.spectrumSpeed;
    self.renderStyle = style.spectrumStyle;
    self.theme = style.spectrumTheme;
    self.alpha = style.spectrumOpacity;

    if (style.spectrumBars != self.barCount) {
        self.barCount = style.spectrumBars;
        self.activeCount = 0;
        [self axs_playerpulse_updateActiveCount];
    }

    BOOL wave = style.spectrumStyle == AxsPlayerPulseSpectrumStyleWave;
    self.barGradient.hidden = wave;
    self.waveGradient.hidden = !wave;
    self.waveLine.hidden = !wave;

    [self axs_playerpulse_rebuildColors];
    [self axs_playerpulse_render];
}

- (void)axs_playerpulse_updateArtworkColors:(NSArray<UIColor *> *)artworkColors {
    self.artworkColors = artworkColors ?: @[];
    if (self.theme == AxsPlayerPulseSpectrumThemeArtwork) {
        [self axs_playerpulse_rebuildColors];
        [self axs_playerpulse_render];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    self.barGradient.frame = bounds;
    self.barMask.frame = bounds;
    self.waveGradient.frame = bounds;
    self.waveMask.frame = bounds;
    self.waveLine.frame = bounds;

    [self axs_playerpulse_updateActiveCount];
    [self axs_playerpulse_render];
}

- (void)axs_playerpulse_updateActiveCount {
    // Narrow players (Control Center tile) get fewer bars so bars keep a
    // readable width instead of overlapping.
    NSInteger cap = MAX(6, (NSInteger)(CGRectGetWidth(self.bounds) / 3.0));
    NSInteger target = self.barCount > 0 ? MIN(self.barCount, cap) : 0;
    if (target == self.activeCount) return;
    self.activeCount = target;
    [self axs_playerpulse_rebuildLevels];
    [self axs_playerpulse_rebuildColors];
    [self axs_playerpulse_render];
}

- (void)axs_playerpulse_rebuildLevels {
    [self.levels removeAllObjects];
    for (NSInteger index = 0; index < self.activeCount; index++) {
        [self.levels addObject:@(0.04)];
    }
}

- (void)axs_playerpulse_rebuildColors {
    if (!self.style || self.activeCount <= 0) return;

    NSMutableArray<UIColor *> *colors = [NSMutableArray arrayWithCapacity:self.activeCount];
    NSMutableArray *cgColors = [NSMutableArray arrayWithCapacity:self.activeCount];
    for (NSInteger index = 0; index < self.activeCount; index++) {
        UIColor *color = [self.style axs_playerpulse_spectrumColorAtIndex:index
                                                                   count:self.activeCount
                                                           artworkColors:self.artworkColors];
        color = color ?: [UIColor whiteColor];
        [colors addObject:color];
        [cgColors addObject:(__bridge id)color.CGColor];
    }
    self.barColors = colors;

    UIColor *lineColor = colors[colors.count / 2];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.barGradient.colors = cgColors;
    self.waveGradient.colors = cgColors;
    self.waveLine.strokeColor = [lineColor colorWithAlphaComponent:0.55].CGColor;
    [CATransaction commit];
}

- (void)axs_playerpulse_startAnimating {
    if (self.displayLink) return;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (NSInteger index = 0; index < self.levels.count; index++) {
            double value = 0.28 + 0.14 * sin(index * 0.9) + 0.10 * sin(index * 0.37);
            self.levels[index] = @(axs_playerpulse_unit(value));
        }
        [self axs_playerpulse_render];
        return;
    }
    self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                   selector:@selector(axs_playerpulse_handleTick:)];
    self.displayLink.preferredFramesPerSecond = 60;
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.lastTick = 0;
}

- (void)axs_playerpulse_stopAnimating {
    [self.displayLink invalidate];
    self.displayLink = nil;
    [self axs_playerpulse_render];
}

- (void)axs_playerpulse_handleTick:(CADisplayLink *)link {
    if (!self.window) {
        [self axs_playerpulse_stopAnimating];
        return;
    }

    CFTimeInterval now = link.targetTimestamp;
    CGFloat delta = self.lastTick > 0 ? (CGFloat)(now - self.lastTick) : (1.0 / 60.0);
    delta = fmax(0.0, fmin(0.05, delta));
    self.lastTick = now;
    self.tickCount++;

    AxsPlayerPulseNowPlaying *nowPlaying = [AxsPlayerPulseNowPlaying axs_playerpulse_shared];
    if (self.tickCount % 30 == 0) [nowPlaying axs_playerpulse_refreshIfNeeded];

    if (nowPlaying.seed != self.seed) {
        self.seed = nowPlaying.seed;
    }

    BOOL playing = nowPlaying.playing;
    NSInteger framesPerSecond = playing ? 60 : 20;
    if (self.displayLink.preferredFramesPerSecond != framesPerSecond) {
        self.displayLink.preferredFramesPerSecond = framesPerSecond;
    }
    double speed = MAX(0.1, (double)self.speed * (playing ? 1.0 : 0.32));
    double beat = 0.5 / speed;
    double elapsed = [nowPlaying axs_playerpulse_currentElapsed];
    double phase = axs_playerpulse_fract(elapsed / beat);

    NSInteger count = self.levels.count;
    for (NSInteger index = 0; index < count; index++) {
        double old = self.levels[index].doubleValue;
        double position = count > 1 ? (double)index / (double)(count - 1) : 0.0;
        double band = position < 0.34 ? 0.0 : (position < 0.68 ? 1.0 : 2.0);
        double jitter = 0.5 + 0.5 * sin(now * 0.7 + index * 1.7 + (double)(self.seed % 97));
        double target;

        if (playing) {
            if (band == 0.0) {
                target = 0.55 + 0.45 * sin(2.0 * M_PI * (phase + position * 0.25));
            } else if (band == 1.0) {
                target = 0.30 + 0.45 * sin(2.0 * M_PI * (phase * 1.5 + position * 0.8));
            } else {
                target = 0.22 + 0.38 * sin(2.0 * M_PI * (phase * 2.0 + position * 1.4));
            }
            target = 0.10 + 0.72 * target + 0.18 * jitter;
        } else {
            target = 0.05 + 0.055 * sin(now * 1.1 + index * 0.55);
        }
        target = axs_playerpulse_unit(target);

        // Fast attack, slower release: reads as a meter rather than a sine.
        double blend = target > old ? 0.55 : 0.28;
        self.levels[index] = @(old + (target - old) * blend);
    }

    [self axs_playerpulse_render];
}

- (void)axs_playerpulse_render {
    if (self.activeCount <= 0) return;

    UIBezierPath *bars = [self axs_playerpulse_barPath];
    UIBezierPath *top = [self axs_playerpulse_wavePath];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.barMask.path = bars.CGPath;
    if (top) {
        UIBezierPath *filled = [top copy];
        CGFloat width = CGRectGetWidth(self.bounds);
        CGFloat height = CGRectGetHeight(self.bounds);
        [filled addLineToPoint:CGPointMake(width, height)];
        [filled addLineToPoint:CGPointMake(0.0, height)];
        [filled closePath];
        self.waveMask.path = filled.CGPath;
        self.waveLine.path = top.CGPath;
    } else {
        self.waveMask.path = NULL;
        self.waveLine.path = NULL;
    }
    [CATransaction commit];
}

- (UIBezierPath *)axs_playerpulse_barPath {
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    NSInteger count = MIN(self.activeCount, self.levels.count);
    if (width <= 0.0 || height <= 0.0 || count <= 0) return nil;

    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat gap = MAX(1.0, width * 0.008);
    CGFloat barWidth = MAX(1.0, (width - gap * (count - 1)) / count);
    CGFloat radius = MIN(barWidth * 0.5, 2.0);

    for (NSInteger index = 0; index < count; index++) {
        double level = self.levels[index].doubleValue;
        CGFloat barHeight = MAX(2.0, (CGFloat)level * (height - 2.0));
        CGFloat x = index * (barWidth + gap);
        CGRect rect = CGRectMake(x, height - barHeight, barWidth, barHeight);
        [path appendPath:[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius]];
    }
    return path;
}

- (UIBezierPath *)axs_playerpulse_wavePath {
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    NSInteger count = MIN(self.activeCount, self.levels.count);
    if (width <= 0.0 || height <= 0.0 || count <= 0) return nil;

    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger index = 0; index < count; index++) {
        double level = self.levels[index].doubleValue;
        CGFloat x = count > 1 ? width * (CGFloat)index / (CGFloat)(count - 1) : width * 0.5;
        CGFloat y = height - 3.0 - (CGFloat)level * (height - 8.0);
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
    }

    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint first = points.firstObject.CGPointValue;
    [path moveToPoint:first];
    for (NSInteger index = 1; index < count; index++) {
        CGPoint previous = points[index - 1].CGPointValue;
        CGPoint current = points[index].CGPointValue;
        CGPoint control = CGPointMake((previous.x + current.x) * 0.5, previous.y);
        [path addQuadCurveToPoint:current controlPoint:control];
    }
    return path;
}

@end
