DEBUG ?= 0
FINALPACKAGE ?= 1
ARCHS = arm64 arm64e

# Rootless and Roothide require iOS 15 or newer.
ifneq ($(filter rootless roothide,$(THEOS_PACKAGE_SCHEME)),)
TARGET = iphone:clang:16.5:16.0
else
TARGET = iphone:clang:16.5:16.0
endif
