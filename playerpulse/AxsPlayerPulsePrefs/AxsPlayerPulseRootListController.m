#import "AxsPlayerPulseRootListController.h"
#import "AxsPlayerPulsePreferences.h"
#import "AxsPlayerPulseDefaults.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "AxsPlayerPulseSliderCell.h"
#import <math.h>

@interface AxsPlayerPulseRootListController () <AxsPlayerPulseSliderCellHandler>
- (void)axs_playerpulse_addButton:(NSString *)title action:(SEL)action to:(NSMutableArray *)items;
- (void)axs_playerpulse_resetDefaults:(id)sender;
- (void)axs_playerpulse_performReset;
- (void)axs_playerpulse_openURL:(NSURL *)url fallback:(NSURL *)fallback;
- (void)axs_playerpulse_openRepository:(id)sender;
- (void)axs_playerpulse_openTelegram:(id)sender;
- (void)axs_playerpulse_openQQ:(id)sender;
@end

@implementation AxsPlayerPulseRootListController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [[self loadSpecifiersFromPlistName:@"AxsPlayerPulseRoot"
                                                           target:self] mutableCopy];
        PSSpecifier *maintenance = [PSSpecifier preferenceSpecifierNamed:@"维护" target:self
                     set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [maintenance setProperty:@"恢复默认会清除所有自定义，包括启用开关。"
                         forKey:@"footerText"];
        [items addObject:maintenance];
        [self axs_playerpulse_addButton:@"恢复默认设置"
                                 action:@selector(axs_playerpulse_resetDefaults:)
                                     to:items];
        [items addObject:[PSSpecifier preferenceSpecifierNamed:@"关于我们" target:self
                     set:nil get:nil detail:nil cell:PSGroupCell edit:nil]];
        [self axs_playerpulse_addButton:@"Sileo 越狱源" action:@selector(axs_playerpulse_openRepository:) to:items];
        [self axs_playerpulse_addButton:@"TG分享频道" action:@selector(axs_playerpulse_openTelegram:) to:items];
        [self axs_playerpulse_addButton:@"QQ交流群组" action:@selector(axs_playerpulse_openQQ:) to:items];
        _specifiers = items;
    }
    return _specifiers;
}

- (void)axs_playerpulse_addButton:(NSString *)title action:(SEL)action to:(NSMutableArray *)items {
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:title target:self
                          set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    item.buttonAction = action;
    [items addObject:item];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return nil;
    return axs_playerpulse_readPreferences()[key] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return;
    NSError *error = nil;
    if (!axs_playerpulse_writePreference(key, value, &error)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置未保存"
            message:error.localizedDescription ?: @"请检查配置文件路径和写入权限。"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadSpecifiers];
    }
}

- (void)axs_playerpulse_openURL:(NSURL *)url fallback:(NSURL *)fallback {
    if (!url) return;
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        if (success) return;
        if (fallback) {
            [self axs_playerpulse_openURL:fallback fallback:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开链接"
                message:@"请确认已安装对应应用。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (void)axs_playerpulse_openRepository:(id)sender {
    NSString *source = @"https://axs66.github.io/pro";
    // Encode the entire URL as a path component, including its own delimiters.
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                              @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    NSString *encoded = [source stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    NSURL *primary = [NSURL URLWithString:[@"sileo://source/" stringByAppendingString:encoded]];
    [self axs_playerpulse_openURL:primary fallback:[NSURL URLWithString:source]];
}

- (void)axs_playerpulse_openTelegram:(id)sender {
    [self axs_playerpulse_openURL:[NSURL URLWithString:@"tg://resolve?domain=wxfx8"]
                   fallback:[NSURL URLWithString:@"https://t.me/wxfx8"]];
}

- (void)axs_playerpulse_openQQ:(id)sender {
    [self axs_playerpulse_openURL:[NSURL URLWithString:@"mqqapi://card/show_pslcard?src_type=internal&version=1&uin=678055716&card_type=group&source=qrcode"] fallback:nil];
}

- (void)axs_playerpulse_resetDefaults:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"恢复默认设置"
        message:@"将清除本插件的全部自定义并关闭插件，确定继续？"
        preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"恢复" style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [weakSelf axs_playerpulse_performReset];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)axs_playerpulse_performReset {
    NSError *firstError = nil;
    for (NSString *key in axs_playerpulse_config_keys()) {
        NSError *error = nil;
        if (!axs_playerpulse_writePreference(key, nil, &error) && !firstError) {
            firstError = error;
        }
    }
    [self reloadSpecifiers];

    NSString *title = firstError ? @"设置未完全清除" : @"已恢复默认设置";
    NSString *message = firstError.localizedDescription ?: @"插件已关闭，重新启用后生效。";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
        message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                              style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([PSListController instancesRespondToSelector:_cmd]) {
        [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    if ([cell isKindOfClass:[AxsPlayerPulseSliderCell class]]) {
        AxsPlayerPulseSliderCell *sliderCell = (AxsPlayerPulseSliderCell *)cell;
        sliderCell.handler = self;
        [sliderCell axs_playerpulse_reloadState];
    }
}

- (double)axs_playerpulse_sliderValueForSpecifier:(PSSpecifier *)specifier {
    id value = [self readPreferenceValue:specifier];
    return [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0.0;
}

- (void)axs_playerpulse_setSliderValue:(double)value specifier:(PSSpecifier *)specifier {
    double minimum = [[specifier propertyForKey:@"min"] doubleValue];
    double maximum = [[specifier propertyForKey:@"max"] doubleValue];
    if (!isfinite(minimum)) minimum = 0.0;
    if (!isfinite(maximum) || maximum <= minimum) maximum = minimum + 1.0;
    if (!isfinite(value)) value = minimum;
    [self setPreferenceValue:@(fmax(minimum, fmin(maximum, value))) specifier:specifier];
}

@end
