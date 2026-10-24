#pragma once

#import <UIKit/UIKit.h>

// MediaRemoteUI types confirmed against the iOS 16.5 hierarchy. Only the
// containers PlayerPulse touches are declared; concrete ivars are read
// defensively with object_getIvar plus class-name fallbacks.

@interface MRUNowPlayingView : UIView
@end

@interface MRUNowPlayingHeaderView : UIView
@end

@interface MRUNowPlayingLabelView : UIView
@end

@interface MRUNowPlayingTransportControlsView : UIView
@end

@interface MRUTransportButton : UIControl
@end

@interface MRUArtworkView : UIView
@end

@interface MRUNowPlayingViewController : UIViewController
@end

@interface SBBacklightController : NSObject
@end
