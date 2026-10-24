include ../AxsPlayerPulseBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AxsPlayerPulsePrefs
AxsPlayerPulsePrefs_FILES = $(wildcard *.m)
AxsPlayerPulsePrefs_CFLAGS = -fobjc-arc -I../Sources
AxsPlayerPulsePrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
AxsPlayerPulsePrefs_PRIVATE_FRAMEWORKS = Preferences
AxsPlayerPulsePrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
