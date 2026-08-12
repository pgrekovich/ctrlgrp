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

.PHONY: build test app bundle universal release-app dmg install uninstall run clean

build:
	swift build -c release

test:
	swift test

# Assembles the bundle from whatever BINARY points at. Not called directly:
# use `app` for a local build or `release-app` for a universal one.
bundle:
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BINARY) $(APP)/Contents/MacOS/$(APP_NAME)
	sed -e 's/@BUNDLE_ID@/$(BUNDLE_ID)/g' -e 's/@VERSION@/$(VERSION)/g' \
		Resources/Info.plist.in > $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)
	@echo "built $(APP) $(VERSION)"

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
	@echo "built $(DMG)"

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
