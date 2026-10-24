#pragma once

#import <UIKit/UIKit.h>

// Posted on the main thread whenever playback state, elapsed time, track
// identity or artwork changes. Object is the shared provider.
FOUNDATION_EXPORT NSString * const AxsPlayerPulseNowPlayingDidChangeNotification;

@interface AxsPlayerPulseNowPlaying : NSObject

@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) double playbackRate;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly, strong) UIImage *artwork;
@property (nonatomic, readonly, copy) NSArray<UIColor *> *artworkColors;
@property (nonatomic, readonly) NSUInteger seed;
@property (nonatomic, readonly) NSUInteger artworkKey;

+ (instancetype)axs_playerpulse_shared;

// Registers MediaRemote change notifications and performs the first read.
- (void)axs_playerpulse_startObserving;

// Throttled read used from layout/display-link paths. Never blocks.
- (void)axs_playerpulse_refreshIfNeeded;
- (void)axs_playerpulse_refreshForce;

// Interpolated position, used by the spectrum beat clock.
- (NSTimeInterval)axs_playerpulse_currentElapsed;

@end
