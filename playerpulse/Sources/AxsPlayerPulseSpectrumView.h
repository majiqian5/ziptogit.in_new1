#pragma once

#import <UIKit/UIKit.h>
#import "AxsPlayerPulseStyle.h"

// Decorative, non-interactive spectrum. It follows the now-playing playback
// clock so every bar moves on the beat, and idles while paused. Drawing is
// done with CALayer masks instead of drawRect: so the view stays cheap at
// 60 fps inside SpringBoard.
@interface AxsPlayerPulseSpectrumView : UIView

- (void)axs_playerpulse_applyStyle:(AxsPlayerPulseStyle *)style;
- (void)axs_playerpulse_updateArtworkColors:(NSArray<UIColor *> *)artworkColors;
- (void)axs_playerpulse_startAnimating;
- (void)axs_playerpulse_stopAnimating;

@end
