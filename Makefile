TARGET := iphone:clang:latest:16.0
ARCHS := arm64 arm64e

THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = NappStore

NappStore_FILES = $(shell find Sources -name '*.swift')
NappStore_FRAMEWORKS = UIKit SwiftUI Foundation CoreServices StoreKit
# The development IPA is produced by build_ipa.sh. Keep this legacy Theos
# target free of private entitlements so an accidental `make` cannot produce
# the invalid no-sandbox/platform-application signature.
NappStore_CODESIGN_FLAGS =


include $(THEOS_MAKE_PATH)/application.mk
