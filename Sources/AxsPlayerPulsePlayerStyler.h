#pragma once

#import <UIKit/UIKit.h>

// Applies PlayerPulse's appearance to the MediaRemoteUI player. All entry
// points run on the main thread immediately after the system's own layout.
@interface AxsPlayerPulsePlayerStyler : NSObject

+ (void)axs_playerpulse_applyToNowPlayingView:(UIView *)view;
+ (void)axs_playerpulse_applyArtworkCornerToView:(UIView *)view;
+ (void)axs_playerpulse_applyLabelAppearanceToLabelView:(UIView *)view;
+ (void)axs_playerpulse_applyButtonScaleToButton:(UIView *)button;
+ (void)axs_playerpulse_applyTransportControlsLayout:(UIView *)view;
+ (void)axs_playerpulse_refreshVisiblePlayers;
+ (void)axs_playerpulse_stopAnimations;

@end
