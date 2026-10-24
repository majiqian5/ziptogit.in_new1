#pragma once

#import <Foundation/Foundation.h>

// Preference keys shared by the tweak and the PreferenceBundle. Defaults live
// in the bundle plist; consumers below repeat the same fallback values so a
// missing key never changes behaviour silently.
static NSString * const AxsPlayerPulseKeyEnabled = @"enabled";
static NSString * const AxsPlayerPulseKeySpectrumEnabled = @"spectrumEnabled";
static NSString * const AxsPlayerPulseKeySpectrumLockScreen = @"spectrumLockScreen";
static NSString * const AxsPlayerPulseKeySpectrumControlCenter = @"spectrumControlCenter";
static NSString * const AxsPlayerPulseKeySpectrumStyle = @"spectrumStyle";
static NSString * const AxsPlayerPulseKeySpectrumTheme = @"spectrumTheme";
static NSString * const AxsPlayerPulseKeySpectrumColor = @"spectrumColor";
static NSString * const AxsPlayerPulseKeySpectrumBars = @"spectrumBars";
static NSString * const AxsPlayerPulseKeySpectrumHeight = @"spectrumHeight";
static NSString * const AxsPlayerPulseKeySpectrumOpacity = @"spectrumOpacity";
static NSString * const AxsPlayerPulseKeySpectrumSpeed = @"spectrumSpeed";
static NSString * const AxsPlayerPulseKeyButtonScale = @"buttonScale";
static NSString * const AxsPlayerPulseKeyTitleColor = @"titleColor";
static NSString * const AxsPlayerPulseKeySubtitleColor = @"subtitleColor";
static NSString * const AxsPlayerPulseKeyTitleSize = @"titleSize";
static NSString * const AxsPlayerPulseKeySubtitleSize = @"subtitleSize";
static NSString * const AxsPlayerPulseKeyPlayerScale = @"playerScale";
static NSString * const AxsPlayerPulseKeyPlayerCorner = @"playerCorner";
static NSString * const AxsPlayerPulseKeyArtworkCorner = @"artworkCorner";
static NSString * const AxsPlayerPulseKeyArtworkBackdrop = @"artworkBackdrop";
static NSString * const AxsPlayerPulseKeyBackdropOpacity = @"backdropOpacity";

static inline NSArray<NSString *> *axs_playerpulse_config_keys(void) {
    return @[
        AxsPlayerPulseKeyEnabled,
        AxsPlayerPulseKeySpectrumEnabled,
        AxsPlayerPulseKeySpectrumLockScreen,
        AxsPlayerPulseKeySpectrumControlCenter,
        AxsPlayerPulseKeySpectrumStyle,
        AxsPlayerPulseKeySpectrumTheme,
        AxsPlayerPulseKeySpectrumColor,
        AxsPlayerPulseKeySpectrumBars,
        AxsPlayerPulseKeySpectrumHeight,
        AxsPlayerPulseKeySpectrumOpacity,
        AxsPlayerPulseKeySpectrumSpeed,
        AxsPlayerPulseKeyButtonScale,
        AxsPlayerPulseKeyTitleColor,
        AxsPlayerPulseKeySubtitleColor,
        AxsPlayerPulseKeyTitleSize,
        AxsPlayerPulseKeySubtitleSize,
        AxsPlayerPulseKeyPlayerScale,
        AxsPlayerPulseKeyPlayerCorner,
        AxsPlayerPulseKeyArtworkCorner,
        AxsPlayerPulseKeyArtworkBackdrop,
        AxsPlayerPulseKeyBackdropOpacity,
    ];
}

// Spectrum rendering styles.
typedef NS_ENUM(NSInteger, AxsPlayerPulseSpectrumStyle) {
    AxsPlayerPulseSpectrumStyleBars = 0,
    AxsPlayerPulseSpectrumStyleWave = 1,
};

// Colour presets. A single custom colour is used by the "single" theme.
typedef NS_ENUM(NSInteger, AxsPlayerPulseSpectrumTheme) {
    AxsPlayerPulseSpectrumThemeRainbow = 0,
    AxsPlayerPulseSpectrumThemeNeon = 1,
    AxsPlayerPulseSpectrumThemeAurora = 2,
    AxsPlayerPulseSpectrumThemeSingle = 3,
    AxsPlayerPulseSpectrumThemeArtwork = 4,
};
