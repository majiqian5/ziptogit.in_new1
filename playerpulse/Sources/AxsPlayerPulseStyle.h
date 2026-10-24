#pragma once

#import <UIKit/UIKit.h>
#import "AxsPlayerPulseDefaults.h"

// Immutable snapshot of the user's appearance preferences. Hooks rebuild this
// once per layout from AxsPlayerPulseConfig instead of reading files.
@interface AxsPlayerPulseStyle : NSObject

@property (nonatomic, readonly) BOOL enabled;

@property (nonatomic, readonly) BOOL spectrumEnabled;
@property (nonatomic, readonly) BOOL spectrumOnLockScreen;
@property (nonatomic, readonly) BOOL spectrumOnControlCenter;
@property (nonatomic, readonly) NSInteger spectrumStyle;
@property (nonatomic, readonly) NSInteger spectrumTheme;
@property (nonatomic, readonly) NSInteger spectrumBars;
@property (nonatomic, readonly) CGFloat spectrumHeight;
@property (nonatomic, readonly) CGFloat spectrumOpacity;
@property (nonatomic, readonly) CGFloat spectrumSpeed;
@property (nonatomic, readonly, strong) UIColor *spectrumColor;

@property (nonatomic, readonly) CGFloat buttonScale;

@property (nonatomic, readonly, strong) UIColor *titleColor;
@property (nonatomic, readonly, strong) UIColor *subtitleColor;
@property (nonatomic, readonly) CGFloat titleSize;
@property (nonatomic, readonly) CGFloat subtitleSize;

@property (nonatomic, readonly) CGFloat playerScale;
@property (nonatomic, readonly) CGFloat playerCorner;
@property (nonatomic, readonly) CGFloat artworkCorner;
@property (nonatomic, readonly) BOOL artworkBackdrop;
@property (nonatomic, readonly) CGFloat backdropOpacity;

+ (instancetype)axs_playerpulse_currentStyle;

// Resolves one bar's colour for the active preset. artworkColors may be nil.
- (UIColor *)axs_playerpulse_spectrumColorAtIndex:(NSInteger)index
                            count:(NSInteger)count
                    artworkColors:(NSArray<UIColor *> *)artworkColors;

@end

// Accepts #RGB, #RRGGBB and #RRGGBBAA (the leading # is optional). Returns
// fallback for empty or malformed input.
FOUNDATION_EXPORT UIColor *axs_playerpulse_color_from_hex(NSString *string, UIColor *fallback);

// Vertical hue blend used by the neon/aurora presets.
FOUNDATION_EXPORT UIColor *axs_playerpulse_blend_color(UIColor *from, UIColor *to, CGFloat progress);
