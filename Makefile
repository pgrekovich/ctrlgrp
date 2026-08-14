APP_NAME    := ctrlgrp
BUNDLE_ID   := com.pgrekovich.ctrlgrp
# Overridable so the release workflow can stamp the git tag into the bundle
# instead of this file drifting out of sync with what was actually shipped.
VERSION     ?= 0.1.0
BUILD_DIR   := .build/release
UNIVERSAL   := .build/universal
APP         := $(APP_NAME).app
DMG         := $(APP_NAME)-$(VERSION).dmg
INSTALL_DIR := /Applications
# Which binary the bundle is assembled from. `app` uses the native build,
# `release-app` overrides it with the universal one.
BINARY      ?= $(BUILD_DIR)/$(APP_NAME)

# "-" is ad-hoc: fine for local development, quarantined when downloaded.
# Releases pass the Developer ID identity instead, which also turns on the
# hardened runtime and a secure timestamp, both required for notarization.
SIGN_IDENTITY ?= -
ifeq ($(SIGN_IDENTITY),-)
SIGN_FLAGS :=
else
SIGN_FLAGS := --options runtime --timestamp
endif

# The notarytool keychain profile to submit with. Created once, locally via
# `xcrun notarytool store-credentials`, in CI by the release workflow.
NOTARY_PROFILE ?= ctrlgrp-notary

.PHONY: build test app bundle universal release-app dmg notarize icns install uninstall run clean

build:
	swift build -c release

test:
	swift test

# Assembles the bundle from whatever BINARY points at. Not called directly:
# use `app` for a local build or `release-app` for a universal one.
bundle:
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BINARY) $(APP)/Contents/MacOS/$(APP_NAME)
	cp Resources/$(APP_NAME).icns Resources/menubar.png $(APP)/Contents/Resources/
	sed -e 's/@BUNDLE_ID@/$(BUNDLE_ID)/g' -e 's/@VERSION@/$(VERSION)/g' \
		Resources/Info.plist.in > $(APP)/Contents/Info.plist
	codesign --force $(SIGN_FLAGS) --sign "$(SIGN_IDENTITY)" $(APP)
	@echo "built $(APP) $(VERSION)"

# Regenerates the committed icns from the SVGs. Needs rsvg-convert (brew
# install librsvg), which CI does not have, so the icns is committed rather
# than built per release. 16px gets its own simplified artwork: at that size
# the selection brackets and the digit merge into mush, so the small variant
# drops the brackets and enlarges the digit.
icns:
	rm -rf .build/icon.iconset
	mkdir -p .build/icon.iconset
	rsvg-convert -w 16   -h 16   design/icon-small.svg -o .build/icon.iconset/icon_16x16.png
	rsvg-convert -w 32   -h 32   icon.svg -o .build/icon.iconset/icon_16x16@2x.png
	rsvg-convert -w 32   -h 32   icon.svg -o .build/icon.iconset/icon_32x32.png
	rsvg-convert -w 64   -h 64   icon.svg -o .build/icon.iconset/icon_32x32@2x.png
	rsvg-convert -w 128  -h 128  icon.svg -o .build/icon.iconset/icon_128x128.png
	rsvg-convert -w 256  -h 256  icon.svg -o .build/icon.iconset/icon_128x128@2x.png
	rsvg-convert -w 256  -h 256  icon.svg -o .build/icon.iconset/icon_256x256.png
	rsvg-convert -w 512  -h 512  icon.svg -o .build/icon.iconset/icon_256x256@2x.png
	rsvg-convert -w 512  -h 512  icon.svg -o .build/icon.iconset/icon_512x512.png
	rsvg-convert -w 1024 -h 1024 icon.svg -o .build/icon.iconset/icon_512x512@2x.png
	iconutil -c icns .build/icon.iconset -o Resources/$(APP_NAME).icns
	rsvg-convert -w 36 -h 36 design/menubar.svg -o Resources/menubar.png
	@echo "built Resources/$(APP_NAME).icns"

app: build
	@$(MAKE) bundle BINARY=$(BUILD_DIR)/$(APP_NAME)

# Two single-arch passes joined with lipo, rather than one
# `swift build --arch arm64 --arch x86_64`: the multi-arch form needs xcbuild
# from a full Xcode install, and this project builds with Command Line Tools
# alone. This way a release can be cut on any Mac.
universal:
	swift build -c release --arch arm64
	swift build -c release --arch x86_64
	mkdir -p $(UNIVERSAL)
	lipo -create -output $(UNIVERSAL)/$(APP_NAME) \
		.build/arm64-apple-macosx/release/$(APP_NAME) \
		.build/x86_64-apple-macosx/release/$(APP_NAME)
	@lipo -info $(UNIVERSAL)/$(APP_NAME)

release-app: universal
	@$(MAKE) bundle BINARY=$(UNIVERSAL)/$(APP_NAME)

# The disk image opens on a window holding the app and a link to
# /Applications, so installing is the drag everyone already knows.
dmg: release-app
	rm -rf $(DMG) .build/dmg
	mkdir -p .build/dmg
	cp -R $(APP) .build/dmg/
	ln -s /Applications .build/dmg/Applications
	hdiutil create -volname "$(APP_NAME) $(VERSION)" -srcfolder .build/dmg \
		-ov -format UDZO $(DMG) >/dev/null
ifneq ($(SIGN_IDENTITY),-)
	codesign --force --timestamp --sign "$(SIGN_IDENTITY)" $(DMG)
endif
	@echo "built $(DMG)"

# Submits the disk image to Apple, waits for the verdict, and staples the
# ticket so Gatekeeper can verify offline. Fails loudly on rejection.
notarize:
	xcrun notarytool submit $(DMG) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(DMG)
	spctl --assess --type open --context context:primary-signature -vv $(DMG)

# Runs the bundled binary in the foreground so logs land in the terminal.
run: app
	./$(APP)/Contents/MacOS/$(APP_NAME)

install: app
	rm -rf $(INSTALL_DIR)/$(APP)
	cp -R $(APP) $(INSTALL_DIR)/
	@echo "installed $(INSTALL_DIR)/$(APP)"

uninstall:
	rm -rf $(INSTALL_DIR)/$(APP)

clean:
	rm -rf .build $(APP) $(APP_NAME)-*.dmg
