APP_NAME    := ctrlgrp
BUNDLE_ID   := com.pgrekovich.ctrlgrp
VERSION     := 0.1.0
BUILD_DIR   := .build/release
APP         := $(APP_NAME).app
INSTALL_DIR := /Applications

.PHONY: build test app install uninstall run clean

build:
	swift build -c release

test:
	swift test

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BUILD_DIR)/$(APP_NAME) $(APP)/Contents/MacOS/$(APP_NAME)
	sed -e 's/@BUNDLE_ID@/$(BUNDLE_ID)/g' -e 's/@VERSION@/$(VERSION)/g' \
		Resources/Info.plist.in > $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)
	@echo "built $(APP)"

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
	rm -rf .build $(APP)
