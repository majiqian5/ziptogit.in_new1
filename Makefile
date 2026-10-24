DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include AxsPlayerPulseBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AxsPlayerPulse
AxsPlayerPulse_FILES = $(wildcard Hooks/*.xm Sources/*.m)
AxsPlayerPulse_CFLAGS = -fobjc-arc -I./Headers -I./Sources
AxsPlayerPulse_FRAMEWORKS = UIKit Foundation CoreFoundation CoreGraphics QuartzCore CoreImage
AxsPlayerPulse_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += AxsPlayerPulsePrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
