#import "AxsPlayerPulseStyle.h"
#import "AxsPlayerPulseConfig.h"
#import <math.h>

@interface AxsPlayerPulseStyle ()
- (BOOL)axs_playerpulse_boolForKey:(NSString *)key fallback:(BOOL)fallback;
- (double)axs_playerpulse_doubleForKey:(NSString *)key fallback:(double)fallback
               minimum:(double)minimum maximum:(double)maximum;
- (NSString *)axs_playerpulse_stringForKey:(NSString *)key fallback:(NSString *)fallback;
@end

static double axs_playerpulse_clamp(double value, double minimum, double maximum) {
    if (!isfinite(value)) return minimum;
    return fmax(minimum, fmin(maximum, value));
}

UIColor *axs_playerpulse_color_from_hex(NSString *string, UIColor *fallback) {
    if (![string isKindOfClass:[NSString class]]) return fallback;
    NSString *trimmed = [string stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return fallback;
    if ([trimmed hasPrefix:@"#"]) trimmed = [trimmed substringFromIndex:1];
    if (trimmed.length != 3 && trimmed.length != 6 && trimmed.length != 8) return fallback;

    unsigned long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:trimmed];
    if (![scanner scanHexLongLong:&value] || !scanner.isAtEnd) return fallback;

    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0;
    if (trimmed.length == 3) {
        red = ((value >> 8) & 0xF) / 15.0;
        green = ((value >> 4) & 0xF) / 15.0;
        blue = (value & 0xF) / 15.0;
    } else if (trimmed.length == 6) {
        red = ((value >> 16) & 0xFF) / 255.0;
        green = ((value >> 8) & 0xFF) / 255.0;
        blue = (value & 0xFF) / 255.0;
    } else {
        red = ((value >> 24) & 0xFF) / 255.0;
        green = ((value >> 16) & 0xFF) / 255.0;
        blue = ((value >> 8) & 0xFF) / 255.0;
        alpha = (value & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

UIColor *axs_playerpulse_blend_color(UIColor *from, UIColor *to, CGFloat progress) {
    if (!from) return to;
    if (!to) return from;
    CGFloat p = axs_playerpulse_clamp(progress, 0.0, 1.0);
    CGFloat fr = 0, fg = 0, fb = 0, fa = 1;
    CGFloat tr = 0, tg = 0, tb = 0, ta = 1;
    if (![from getRed:&fr green:&fg blue:&fb alpha:&fa]) {
        CGFloat white = 0;
        if ([from getWhite:&white alpha:&fa]) { fr = fg = fb = white; }
    }
    if (![to getRed:&tr green:&tg blue:&tb alpha:&ta]) {
        CGFloat white = 0;
        if ([to getWhite:&white alpha:&ta]) { tr = tg = tb = white; }
    }
    return [UIColor colorWithRed:fr + (tr - fr) * p
                           green:fg + (tg - fg) * p
                            blue:fb + (tb - fb) * p
                           alpha:fa + (ta - fa) * p];
}

@implementation AxsPlayerPulseStyle

+ (instancetype)axs_playerpulse_currentStyle {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    AxsPlayerPulseConfig *config = [AxsPlayerPulseConfig axs_playerpulse_shared];
    _enabled = [config axs_playerpulse_isEnabled];

    _spectrumEnabled = [self axs_playerpulse_boolForKey:AxsPlayerPulseKeySpectrumEnabled fallback:YES];
    _spectrumOnLockScreen = [self axs_playerpulse_boolForKey:AxsPlayerPulseKeySpectrumLockScreen fallback:YES];
    _spectrumOnControlCenter = [self axs_playerpulse_boolForKey:AxsPlayerPulseKeySpectrumControlCenter fallback:YES];
    _spectrumStyle = (NSInteger)lrint([self axs_playerpulse_doubleForKey:AxsPlayerPulseKeySpectrumStyle
                                               fallback:0.0 minimum:0.0 maximum:1.0]);
    _spectrumTheme = (NSInteger)lrint([self axs_playerpulse_doubleForKey:AxsPlayerPulseKeySpectrumTheme
                                               fallback:0.0 minimum:0.0 maximum:4.0]);
    _spectrumBars = (NSInteger)lrint([self axs_playerpulse_doubleForKey:AxsPlayerPulseKeySpectrumBars
                                              fallback:28.0 minimum:12.0 maximum:48.0]);
    _spectrumHeight = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeySpectrumHeight
                               fallback:42.0 minimum:16.0 maximum:90.0];
    _spectrumOpacity = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeySpectrumOpacity
                                fallback:0.90 minimum:0.2 maximum:1.0];
    _spectrumSpeed = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeySpectrumSpeed
                              fallback:1.0 minimum:0.5 maximum:2.0];

    NSString *spectrumHex = [self axs_playerpulse_stringForKey:AxsPlayerPulseKeySpectrumColor fallback:@"#7CE7FF"];
    _spectrumColor = axs_playerpulse_color_from_hex(spectrumHex,
        [UIColor colorWithRed:0.486 green:0.906 blue:1.0 alpha:1.0]);

    _buttonScale = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeyButtonScale
                            fallback:1.0 minimum:0.6 maximum:1.5];

    _titleColor = axs_playerpulse_color_from_hex(
        [self axs_playerpulse_stringForKey:AxsPlayerPulseKeyTitleColor fallback:@""], nil);
    _subtitleColor = axs_playerpulse_color_from_hex(
        [self axs_playerpulse_stringForKey:AxsPlayerPulseKeySubtitleColor fallback:@""], nil);
    _titleSize = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeyTitleSize
                          fallback:0.0 minimum:0.0 maximum:24.0];
    _subtitleSize = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeySubtitleSize
                             fallback:0.0 minimum:0.0 maximum:20.0];

    _playerScale = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeyPlayerScale
                            fallback:1.0 minimum:0.8 maximum:1.15];
    _playerCorner = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeyPlayerCorner
                             fallback:18.0 minimum:0.0 maximum:40.0];
    _artworkCorner = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeyArtworkCorner
                              fallback:12.0 minimum:0.0 maximum:40.0];
    _artworkBackdrop = [self axs_playerpulse_boolForKey:AxsPlayerPulseKeyArtworkBackdrop fallback:YES];
    _backdropOpacity = [self axs_playerpulse_doubleForKey:AxsPlayerPulseKeyBackdropOpacity
                                fallback:0.55 minimum:0.0 maximum:1.0];

    return self;
}

- (BOOL)axs_playerpulse_boolForKey:(NSString *)key fallback:(BOOL)fallback {
    id value = [[AxsPlayerPulseConfig axs_playerpulse_shared]
                axs_playerpulse_valueForKey:key defaultValue:@(fallback)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : fallback;
}

- (double)axs_playerpulse_doubleForKey:(NSString *)key fallback:(double)fallback
               minimum:(double)minimum maximum:(double)maximum {
    id value = [[AxsPlayerPulseConfig axs_playerpulse_shared]
                axs_playerpulse_valueForKey:key defaultValue:@(fallback)];
    double result = [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : fallback;
    return axs_playerpulse_clamp(result, minimum, maximum);
}

- (NSString *)axs_playerpulse_stringForKey:(NSString *)key fallback:(NSString *)fallback {
    id value = [[AxsPlayerPulseConfig axs_playerpulse_shared]
                axs_playerpulse_valueForKey:key defaultValue:fallback];
    return [value isKindOfClass:[NSString class]] ? value : fallback;
}

- (UIColor *)axs_playerpulse_spectrumColorAtIndex:(NSInteger)index
                            count:(NSInteger)count
                    artworkColors:(NSArray<UIColor *> *)artworkColors {
    NSInteger total = MAX(1, count);
    CGFloat position = total > 1 ? (CGFloat)index / (CGFloat)(total - 1) : 0.0;

    switch (self.spectrumTheme) {
        case AxsPlayerPulseSpectrumThemeNeon: {
            UIColor *cyan = [UIColor colorWithRed:0.20 green:0.94 blue:1.00 alpha:1.0];
            UIColor *magenta = [UIColor colorWithRed:1.00 green:0.24 blue:0.73 alpha:1.0];
            UIColor *amber = [UIColor colorWithRed:1.00 green:0.83 blue:0.30 alpha:1.0];
            if (position < 0.5) {
                return axs_playerpulse_blend_color(cyan, magenta, position * 2.0);
            }
            return axs_playerpulse_blend_color(magenta, amber, (position - 0.5) * 2.0);
        }
        case AxsPlayerPulseSpectrumThemeAurora: {
            UIColor *teal = [UIColor colorWithRed:0.24 green:0.90 blue:0.72 alpha:1.0];
            UIColor *violet = [UIColor colorWithRed:0.52 green:0.46 blue:1.00 alpha:1.0];
            UIColor *rose = [UIColor colorWithRed:1.00 green:0.46 blue:0.78 alpha:1.0];
            if (position < 0.5) {
                return axs_playerpulse_blend_color(teal, violet, position * 2.0);
            }
            return axs_playerpulse_blend_color(violet, rose, (position - 0.5) * 2.0);
        }
        case AxsPlayerPulseSpectrumThemeSingle:
            return [self.spectrumColor colorWithAlphaComponent:0.95];
        case AxsPlayerPulseSpectrumThemeArtwork: {
            if (artworkColors.count >= 2) {
                CGFloat scaled = position * (artworkColors.count - 1);
                NSInteger lower = (NSInteger)floor(scaled);
                NSInteger upper = MIN((NSInteger)artworkColors.count - 1, lower + 1);
                return axs_playerpulse_blend_color(artworkColors[lower], artworkColors[upper],
                                               scaled - lower);
            }
            if (artworkColors.count == 1) return artworkColors.firstObject;
            // No artwork yet: fall through to the rainbow palette.
            break;
        }
        default:
            break;
    }

    // Rainbow: skip the wrap back to red so the ends stay distinguishable.
    CGFloat hue = 0.02 + position * 0.82;
    return [UIColor colorWithHue:hue saturation:0.78 brightness:1.0 alpha:1.0];
}

@end
