#pragma once

#import <Foundation/Foundation.h>

@interface AxsPlayerPulseConfig : NSObject
+ (instancetype)axs_playerpulse_shared;
- (BOOL)axs_playerpulse_isEnabled;
- (id)axs_playerpulse_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)axs_playerpulse_reload;
@end
