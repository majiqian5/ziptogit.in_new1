#import "AxsPlayerPulsePlayerStyler.h"
#import "AxsPlayerPulseStyle.h"
#import "AxsPlayerPulseSpectrumView.h"
#import "AxsPlayerPulseBackdropView.h"
#import "AxsPlayerPulseNowPlaying.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface AxsPlayerPulsePlayerStyler ()
+ (void)axs_playerpulse_removeSpectrumFromView:(UIView *)view;
+ (void)axs_playerpulse_removeBackdropFromView:(UIView *)view;
+ (void)axs_playerpulse_restorePlayerTransform:(UIView *)view;
+ (void)axs_playerpulse_restoreArtworkViewsInPlayer:(UIView *)view;
+ (void)axs_playerpulse_restoreArtworkCornerOnView:(UIView *)view;
+ (void)axs_playerpulse_applyLabelsInView:(UIView *)view size:(CGFloat)size color:(UIColor *)color;
@end

static const void *AxsPlayerPulseSpectrumViewKey = &AxsPlayerPulseSpectrumViewKey;
static const void *AxsPlayerPulseBackdropViewKey = &AxsPlayerPulseBackdropViewKey;
static const void *AxsPlayerPulseAppliedScaleKey = &AxsPlayerPulseAppliedScaleKey;
static const void *AxsPlayerPulseOriginalCornerKey = &AxsPlayerPulseOriginalCornerKey;
static const void *AxsPlayerPulseOriginalMasksKey = &AxsPlayerPulseOriginalMasksKey;

static NSHashTable<UIView *> *axs_playerpulse_players(void) {
    static NSHashTable<UIView *> *table;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = [NSHashTable weakObjectsHashTable];
    });
    return table;
}

static UIView *axs_playerpulse_ivar_view(id object, const char *name) {
    if (!object) return nil;
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    if (!ivar) return nil;
    id value = object_getIvar(object, ivar);
    return [value isKindOfClass:[UIView class]] ? value : nil;
}

static BOOL axs_playerpulse_class_named(UIView *view, NSString *className) {
    return [NSStringFromClass(view.class) isEqualToString:className];
}

static UIView *axs_playerpulse_find_subview(UIView *root, NSString *className, NSInteger depth) {
    if (!root || depth < 0) return nil;
    for (UIView *subview in root.subviews) {
        if (axs_playerpulse_class_named(subview, className)) return subview;
    }
    for (UIView *subview in root.subviews) {
        UIView *match = axs_playerpulse_find_subview(subview, className, depth - 1);
        if (match) return match;
    }
    return nil;
}

static UIView *axs_playerpulse_now_playing_ancestor(UIView *view) {
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        if (axs_playerpulse_class_named(ancestor, @"MRUNowPlayingView")) return ancestor;
    }
    return nil;
}

static BOOL axs_playerpulse_inside_control_center(UIView *view) {
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        NSString *name = NSStringFromClass(ancestor.class);
        if ([name isEqualToString:@"MRUControlCenterView"] ||
            [name isEqualToString:@"CCUIContentModuleContentContainerView"] ||
            [name containsString:@"ControlCenter"]) {
            return YES;
        }
    }
    return NO;
}

static UIView *axs_playerpulse_artwork_view(UIView *nowPlayingView) {
    UIView *artwork = axs_playerpulse_ivar_view(nowPlayingView, "_artworkView");
    if (artwork) return artwork;
    return axs_playerpulse_find_subview(nowPlayingView, @"MRUArtworkView", 3);
}

@implementation AxsPlayerPulsePlayerStyler

+ (void)axs_playerpulse_applyToNowPlayingView:(UIView *)view {
    if (![view isKindOfClass:[UIView class]]) return;
    [axs_playerpulse_players() addObject:view];

    AxsPlayerPulseStyle *style = [AxsPlayerPulseStyle axs_playerpulse_currentStyle];
    BOOL inControlCenter = axs_playerpulse_inside_control_center(view);
    AxsPlayerPulseNowPlaying *nowPlaying = [AxsPlayerPulseNowPlaying axs_playerpulse_shared];

    if (!style.enabled) {
        [self axs_playerpulse_removeSpectrumFromView:view];
        [self axs_playerpulse_removeBackdropFromView:view];
        [self axs_playerpulse_restorePlayerTransform:view];
        [self axs_playerpulse_restoreArtworkViewsInPlayer:view];
        return;
    }

    UIView *artwork = axs_playerpulse_artwork_view(view);

    // Player scale is limited to the lock-screen player: the Control Center
    // tile shares geometry with its module container and must not be scaled.
    if (!inControlCenter) {
        NSNumber *applied = objc_getAssociatedObject(view, AxsPlayerPulseAppliedScaleKey);
        CGFloat scale = style.playerScale;
        if (fabs(scale - 1.0) > 0.002) {
            CGAffineTransform target = CGAffineTransformMakeScale(scale, scale);
            if (!CGAffineTransformEqualToTransform(view.transform, target)) {
                view.transform = target;
            }
            if (!applied || fabs(applied.doubleValue - scale) > 0.001) {
                objc_setAssociatedObject(view, AxsPlayerPulseAppliedScaleKey, @(scale),
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        } else if (applied) {
            view.transform = CGAffineTransformIdentity;
            objc_setAssociatedObject(view, AxsPlayerPulseAppliedScaleKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else {
        [self axs_playerpulse_restorePlayerTransform:view];
    }

    [self axs_playerpulse_applyArtworkCornerToView:artwork];

    // Blurred album backdrop sits below every native subview.
    if (style.artworkBackdrop) {
        AxsPlayerPulseBackdropView *backdrop =
            objc_getAssociatedObject(view, AxsPlayerPulseBackdropViewKey);
        if (!backdrop) {
            backdrop = [[AxsPlayerPulseBackdropView alloc] init];
            backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                        UIViewAutoresizingFlexibleHeight;
            [view insertSubview:backdrop atIndex:0];
            objc_setAssociatedObject(view, AxsPlayerPulseBackdropViewKey, backdrop,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        backdrop.frame = view.bounds;
        BOOL hasArtwork = nowPlaying.artwork != nil;
        backdrop.hidden = !hasArtwork;
        [backdrop axs_playerpulse_applyArtwork:nowPlaying.artwork
                    artworkKey:nowPlaying.artworkKey
                      opacity:style.backdropOpacity
                 cornerRadius:style.playerCorner];
    } else {
        [self axs_playerpulse_removeBackdropFromView:view];
    }

    BOOL showSpectrum = style.spectrumEnabled &&
                        (inControlCenter ? style.spectrumOnControlCenter
                                         : style.spectrumOnLockScreen);
    // Without artwork the only fallback geometry would sit on top of the
    // transport controls, so keep the spectrum out of the way instead.
    BOOL hasTrack = nowPlaying.artwork != nil;
    if (!showSpectrum) {
        [self axs_playerpulse_removeSpectrumFromView:view];
        return;
    }

    AxsPlayerPulseSpectrumView *spectrum =
        objc_getAssociatedObject(view, AxsPlayerPulseSpectrumViewKey);
    if (!spectrum) {
        spectrum = [[AxsPlayerPulseSpectrumView alloc] init];
        objc_setAssociatedObject(view, AxsPlayerPulseSpectrumViewKey, spectrum,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (spectrum.superview != view) {
        if (artwork && artwork.superview == view) {
            [view insertSubview:spectrum aboveSubview:artwork];
        } else {
            [view addSubview:spectrum];
        }
    }

    [spectrum axs_playerpulse_applyStyle:style];
    [spectrum axs_playerpulse_updateArtworkColors:nowPlaying.artworkColors];

    CGRect host = view.bounds;
    CGRect frame = CGRectZero;
    CGFloat corner = 0.0;
    if (artwork && !artwork.hidden && artwork.bounds.size.width > 6.0) {
        CGRect artworkFrame = [artwork convertRect:artwork.bounds toView:view];
        CGFloat height = MIN(style.spectrumHeight,
                             MAX(14.0, CGRectGetHeight(artworkFrame) * 0.55));
        frame = CGRectMake(CGRectGetMinX(artworkFrame),
                           CGRectGetMaxY(artworkFrame) - height,
                           CGRectGetWidth(artworkFrame), height);
        corner = style.artworkCorner > 0
            ? MIN(style.artworkCorner, CGRectGetHeight(artworkFrame) * 0.5)
            : MIN(10.0, CGRectGetHeight(artworkFrame) * 0.25);
    } else {
        CGFloat height = MIN(style.spectrumHeight,
                             MAX(14.0, CGRectGetHeight(host) * 0.4));
        frame = CGRectMake(12.0, CGRectGetMaxY(host) - height - 6.0,
                           MAX(0.0, CGRectGetWidth(host) - 24.0), height);
        corner = 6.0;
    }
    if (!CGRectEqualToRect(spectrum.frame, frame)) spectrum.frame = frame;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    spectrum.layer.cornerRadius = corner;
    spectrum.layer.cornerCurve = kCACornerCurveContinuous;
    spectrum.layer.masksToBounds = corner > 0.0;
    [CATransaction commit];

    spectrum.hidden = !hasTrack;
    if (hasTrack && view.window) {
        [spectrum axs_playerpulse_startAnimating];
    } else {
        [spectrum axs_playerpulse_stopAnimating];
    }
}

+ (void)axs_playerpulse_removeSpectrumFromView:(UIView *)view {
    AxsPlayerPulseSpectrumView *spectrum =
        objc_getAssociatedObject(view, AxsPlayerPulseSpectrumViewKey);
    if (!spectrum) return;
    [spectrum axs_playerpulse_stopAnimating];
    [spectrum removeFromSuperview];
    objc_setAssociatedObject(view, AxsPlayerPulseSpectrumViewKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)axs_playerpulse_removeBackdropFromView:(UIView *)view {
    UIView *backdrop = objc_getAssociatedObject(view, AxsPlayerPulseBackdropViewKey);
    if (!backdrop) return;
    [backdrop removeFromSuperview];
    objc_setAssociatedObject(view, AxsPlayerPulseBackdropViewKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)axs_playerpulse_restorePlayerTransform:(UIView *)view {
    NSNumber *applied = objc_getAssociatedObject(view, AxsPlayerPulseAppliedScaleKey);
    if (!applied) return;
    view.transform = CGAffineTransformIdentity;
    objc_setAssociatedObject(view, AxsPlayerPulseAppliedScaleKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)axs_playerpulse_restoreArtworkViewsInPlayer:(UIView *)view {
    [self axs_playerpulse_restoreArtworkCornerOnView:axs_playerpulse_artwork_view(view)];
    UIView *header = axs_playerpulse_ivar_view(view, "_headerView") ?:
                     axs_playerpulse_find_subview(view, @"MRUNowPlayingHeaderView", 2);
    [self axs_playerpulse_restoreArtworkCornerOnView:axs_playerpulse_ivar_view(header, "_artworkView")];
}

+ (void)axs_playerpulse_restoreArtworkCornerOnView:(UIView *)view {
    if (!view) return;
    NSNumber *corner = objc_getAssociatedObject(view, AxsPlayerPulseOriginalCornerKey);
    NSNumber *masks = objc_getAssociatedObject(view, AxsPlayerPulseOriginalMasksKey);
    if (!corner && !masks) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.layer.cornerRadius = corner ? corner.doubleValue : 0.0;
    view.layer.masksToBounds = masks ? masks.boolValue : NO;
    [CATransaction commit];
    objc_setAssociatedObject(view, AxsPlayerPulseOriginalCornerKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, AxsPlayerPulseOriginalMasksKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)axs_playerpulse_applyArtworkCornerToView:(UIView *)view {
    if (!view) return;
    UIView *player = axs_playerpulse_now_playing_ancestor(view);
    if (!player) return;

    AxsPlayerPulseStyle *style = [AxsPlayerPulseStyle axs_playerpulse_currentStyle];
    if (!style.enabled || style.artworkCorner <= 0.0) {
        [self axs_playerpulse_restoreArtworkCornerOnView:view];
        return;
    }

    if (!objc_getAssociatedObject(view, AxsPlayerPulseOriginalCornerKey)) {
        objc_setAssociatedObject(view, AxsPlayerPulseOriginalCornerKey,
                                 @(view.layer.cornerRadius),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, AxsPlayerPulseOriginalMasksKey,
                                 @(view.layer.masksToBounds),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGFloat radius = style.artworkCorner;
    if (CGRectGetWidth(view.bounds) > 0.0) {
        radius = MIN(radius, CGRectGetWidth(view.bounds) * 0.5);
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.layer.cornerRadius = radius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.masksToBounds = YES;
    [CATransaction commit];
}

+ (void)axs_playerpulse_applyLabelAppearanceToLabelView:(UIView *)view {
    if (!view) return;
    AxsPlayerPulseStyle *style = [AxsPlayerPulseStyle axs_playerpulse_currentStyle];
    if (!style.enabled) return;
    if (style.titleSize <= 0.0 && !style.titleColor &&
        style.subtitleSize <= 0.0 && !style.subtitleColor) {
        return;
    }

    UIView *titleView = axs_playerpulse_ivar_view(view, "_titleMarqueeView") ?:
                        axs_playerpulse_ivar_view(view, "_titleLabel");
    UIView *subtitleView = axs_playerpulse_ivar_view(view, "_subtitleMarqueeView") ?:
                           axs_playerpulse_ivar_view(view, "_subtitleLabel");
    if (!titleView && !subtitleView) return;

    [self axs_playerpulse_applyLabelsInView:titleView size:style.titleSize color:style.titleColor];
    [self axs_playerpulse_applyLabelsInView:subtitleView size:style.subtitleSize color:style.subtitleColor];
}

+ (void)axs_playerpulse_applyLabelsInView:(UIView *)view size:(CGFloat)size color:(UIColor *)color {
    if (!view) return;
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (size > 0.0 && fabs(label.font.pointSize - size) > 0.01) {
            UIFont *base = label.font ?: [UIFont systemFontOfSize:size];
            label.font = [base fontWithSize:size];
        }
        if (color && ![label.textColor isEqual:color]) label.textColor = color;
        return;
    }
    for (UIView *subview in view.subviews) {
        [self axs_playerpulse_applyLabelsInView:subview size:size color:color];
    }
}

+ (void)axs_playerpulse_applyButtonScaleToButton:(UIView *)button {
    if (!button) return;
    AxsPlayerPulseStyle *style = [AxsPlayerPulseStyle axs_playerpulse_currentStyle];
    CGFloat scale = style.enabled ? style.buttonScale : 1.0;
    CGAffineTransform transform = fabs(scale - 1.0) > 0.002
        ? CGAffineTransformMakeScale(scale, scale) : CGAffineTransformIdentity;

    if ([button isKindOfClass:[UIImageView class]] &&
        !CGAffineTransformEqualToTransform(button.transform, transform)) {
        button.transform = transform;
    }
    if ([button isKindOfClass:[UIButton class]]) {
        UIImageView *imageView = ((UIButton *)button).imageView;
        if (imageView && !CGAffineTransformEqualToTransform(imageView.transform, transform)) {
            imageView.transform = transform;
        }
    }
    for (UIView *subview in button.subviews) {
        if ([subview isKindOfClass:[UIImageView class]] &&
            !CGAffineTransformEqualToTransform(subview.transform, transform)) {
            subview.transform = transform;
        }
    }
}

+ (void)axs_playerpulse_applyTransportControlsLayout:(UIView *)view {
    if (!view) return;
    NSArray<NSString *> *ivarNames = @[@"_leftButton", @"_centerButton",
                                       @"_rightButton", @"_routingButton",
                                       @"_leadingButton"];
    for (NSString *name in ivarNames) {
        UIView *button = axs_playerpulse_ivar_view(view, name.UTF8String);
        if (button) [self axs_playerpulse_applyButtonScaleToButton:button];
    }
    for (UIView *subview in view.subviews) {
        if (axs_playerpulse_class_named(subview, @"MRUTransportButton")) {
            [self axs_playerpulse_applyButtonScaleToButton:subview];
        }
    }
}

+ (void)axs_playerpulse_refreshVisiblePlayers {
    NSArray<UIView *> *players = [axs_playerpulse_players() allObjects];
    for (UIView *player in players) {
        if (!player.window && !player.superview) continue;
        [self axs_playerpulse_applyToNowPlayingView:player];
    }
}

+ (void)axs_playerpulse_stopAnimations {
    for (UIView *player in [axs_playerpulse_players() allObjects]) {
        AxsPlayerPulseSpectrumView *spectrum =
            objc_getAssociatedObject(player, AxsPlayerPulseSpectrumViewKey);
        [spectrum axs_playerpulse_stopAnimating];
    }
}

@end
