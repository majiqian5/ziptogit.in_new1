#import "AxsPlayerPulseSliderCell.h"
#import <UIKit/UIKit.h>
#import <math.h>

@interface AxsPlayerPulseSliderCell ()
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *valueLabel;
@end

@implementation AxsPlayerPulseSliderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier specifier:specifier];
    if (self) {
        _slider = [[UISlider alloc] initWithFrame:CGRectZero];
        [_slider addTarget:self action:@selector(axs_playerpulse_sliderMoved:)
          forControlEvents:UIControlEventValueChanged];
        [_slider addTarget:self action:@selector(axs_playerpulse_sliderCommitted:)
          forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self.contentView addSubview:_slider];
        _valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
        _valueLabel.textColor = [UIColor secondaryLabelColor];
        _valueLabel.textAlignment = NSTextAlignmentRight;
        _valueLabel.adjustsFontSizeToFitWidth = YES;
        _valueLabel.minimumScaleFactor = 0.6;
        [self.contentView addSubview:_valueLabel];
        self.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self axs_playerpulse_reloadState];
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    [self axs_playerpulse_reloadState];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.handler = nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    CGFloat height = CGRectGetHeight(self.contentView.bounds);
    CGFloat available = MAX(0.0, width - 32.0);
    CGFloat valueWidth = MIN(64.0, available * 0.28);
    CGFloat titleWidth = MIN(112.0, available * 0.32);
    CGFloat sliderX = 16.0 + titleWidth + 8.0;
    CGFloat valueX = MAX(sliderX, width - 16.0 - valueWidth);
    self.textLabel.frame = CGRectMake(16.0, 0, titleWidth, height);
    self.slider.frame = CGRectMake(sliderX, MAX(0.0, (height - 31.0) / 2.0),
                                  MAX(0.0, valueX - 8.0 - sliderX), 31.0);
    self.valueLabel.frame = CGRectMake(valueX, 0, valueWidth, height);
}

- (void)axs_playerpulse_reloadState {
    self.textLabel.text = self.specifier.name ?: @"";
    self.slider.accessibilityLabel = self.textLabel.text;
    double minimum = [[self.specifier propertyForKey:@"min"] doubleValue];
    double maximum = [[self.specifier propertyForKey:@"max"] doubleValue];
    if (!isfinite(minimum)) minimum = 0.0;
    if (!isfinite(maximum) || maximum <= minimum) maximum = minimum + 1.0;
    self.slider.minimumValue = minimum;
    self.slider.maximumValue = maximum;
    id initial = [self.specifier propertyForKey:@"default"];
    double value = self.handler ? [self.handler axs_playerpulse_sliderValueForSpecifier:self.specifier]
                               : [initial doubleValue];
    if (!isfinite(value)) value = minimum;
    self.slider.value = fmax(minimum, fmin(maximum, value));
    [self axs_playerpulse_updateLabel];
}

- (void)axs_playerpulse_updateLabel {
    double value = self.slider.value;
    NSString *format = [self.specifier propertyForKey:@"format"];
    NSString *number;
    if ([format isEqualToString:@"%.0f"]) {
        number = [NSString stringWithFormat:@"%.0f", value];
    } else if ([format isEqualToString:@"%.2f"]) {
        number = [NSString stringWithFormat:@"%.2f", value];
    } else {
        number = [NSString stringWithFormat:@"%.1f", value];
    }
    NSString *suffix = [self.specifier propertyForKey:@"suffix"];
    NSString *text = [suffix isKindOfClass:[NSString class]]
        ? [number stringByAppendingString:suffix] : number;
    self.valueLabel.text = text;
    self.slider.accessibilityValue = text;
}

- (void)axs_playerpulse_sliderMoved:(UISlider *)sender {
    [self axs_playerpulse_updateLabel];
    // VoiceOver adjustments do not necessarily emit touch-up events.
    if (UIAccessibilityIsVoiceOverRunning()) {
        [self axs_playerpulse_sliderCommitted:sender];
    }
}

- (void)axs_playerpulse_sliderCommitted:(UISlider *)sender {
    [self axs_playerpulse_updateLabel];
    [self.handler axs_playerpulse_setSliderValue:sender.value specifier:self.specifier];
}

@end
