#pragma once

#import <UIKit/UIKit.h>

// Blurred album artwork shown behind the player content. Purely decorative and
// never intercepts touches.
@interface AxsPlayerPulseBackdropView : UIView

- (void)axs_playerpulse_applyArtwork:(UIImage *)artwork
             artworkKey:(NSUInteger)artworkKey
               opacity:(CGFloat)opacity
          cornerRadius:(CGFloat)cornerRadius;

@end
