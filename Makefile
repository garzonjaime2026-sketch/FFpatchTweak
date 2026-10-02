
TARGET := iphone:clang:latest:15.0
ARCHS := arm64

INSTALL_TARGET_PROCESSES := blackios

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := FFPatchTweak

FFPatchTweak_FILES := Ajuste.xm
FFPatchTweak_FRAMEWORKS := UIKit Foundation UniformTypeIdentifiers
FFPatchTweak_PRIVATE_FRAMEWORKS := MobileContainerManager
FFPatchTweak_CFLAGS := -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
