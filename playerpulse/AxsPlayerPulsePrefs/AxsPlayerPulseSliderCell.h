#pragma once

#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#include <math.h>

@protocol AxsPlayerPulseSliderCellHandler <NSObject>
- (double)axs_playerpulse_sliderValueForSpecifier:(PSSpecifier *)specifier;
- (void)axs_playerpulse_setSliderValue:(double)value specifier:(PSSpecifier *)specifier;
@end

@interface AxsPlayerPulseSliderCell : PSTableCell
@property (nonatomic, weak) id<AxsPlayerPulseSliderCellHandler> handler;
- (void)axs_playerpulse_reloadState;
@end
