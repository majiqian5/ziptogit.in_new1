#import <UIKit/UIKit.h>
#import "AxsPlayerPulseConfig.h"
#import "AxsPlayerPulsePrivate.h"
#import "AxsPlayerPulsePreferences.h"
#import "AxsPlayerPulsePlayerStyler.h"
#import "AxsPlayerPulseNowPlaying.h"

// The player is laid out by several nested private views, each of which may
// reclaim its children's geometry after the parent. Re-assert our appearance
// after every system pass instead of trying to replace the native layout.

%hook MRUNowPlayingView

- (void)layoutSubviews {
    %orig;
    [AxsPlayerPulsePlayerStyler axs_playerpulse_applyToNowPlayingView:(UIView *)self];
}

%end

%hook MRUArtworkView

- (void)layoutSubviews {
    %orig;
    [AxsPlayerPulsePlayerStyler axs_playerpulse_applyArtworkCornerToView:(UIView *)self];
}

%end

%hook MRUNowPlayingLabelView

- (void)layoutSubviews {
    %orig;
    [AxsPlayerPulsePlayerStyler axs_playerpulse_applyLabelAppearanceToLabelView:(UIView *)self];
}

%end

%hook MRUTransportButton

- (void)layoutSubviews {
    %orig;
    [AxsPlayerPulsePlayerStyler axs_playerpulse_applyButtonScaleToButton:(UIView *)self];
}

%end

%hook MRUNowPlayingTransportControlsView

- (void)layoutSubviews {
    %orig;
    [AxsPlayerPulsePlayerStyler axs_playerpulse_applyTransportControlsLayout:(UIView *)self];
}

%end

// Screen off: the lock-screen player stays in the hierarchy, so stop the
// display link instead of drawing at full frame rate in the dark.
%hook SBBacklightController

- (void)setBacklightFactorPending:(float)value {
    %orig;
    if (value > 0.0f) {
        [AxsPlayerPulsePlayerStyler axs_playerpulse_refreshVisiblePlayers];
    } else {
        [AxsPlayerPulsePlayerStyler axs_playerpulse_stopAnimations];
    }
}

%end

static id AxsPlayerPulsePreferencesObserver;
static id AxsPlayerPulseNowPlayingObserver;

%ctor {
    @autoreleasepool {
        // Readers load a snapshot; they never write default preferences.
        [AxsPlayerPulseConfig axs_playerpulse_shared];
        [[AxsPlayerPulseNowPlaying axs_playerpulse_shared] axs_playerpulse_startObserving];

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        AxsPlayerPulsePreferencesObserver =
            [center addObserverForName:AxsPlayerPulsePreferencesChanged
                                object:nil
                                 queue:[NSOperationQueue mainQueue]
                            usingBlock:^(NSNotification *note) {
            [AxsPlayerPulsePlayerStyler axs_playerpulse_refreshVisiblePlayers];
        }];
        AxsPlayerPulseNowPlayingObserver =
            [center addObserverForName:AxsPlayerPulseNowPlayingDidChangeNotification
                                object:nil
                                 queue:[NSOperationQueue mainQueue]
                            usingBlock:^(NSNotification *note) {
            [AxsPlayerPulsePlayerStyler axs_playerpulse_refreshVisiblePlayers];
        }];
    }
}
