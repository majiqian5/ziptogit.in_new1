#pragma once

#import <Preferences/PSListItemsController.h>

// PSListItemsController subclass so the "频谱样式/配色方案" choice rows write
// through the plugin's single preference file instead of NSUserDefaults.
@interface AxsPlayerPulseListController : PSListItemsController
@end
