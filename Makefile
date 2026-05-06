APP_NAME  = StayAwake
BUILD_DIR = build
APP_DIR   = $(BUILD_DIR)/$(APP_NAME).app
SOURCES   = Sources/main.swift \
            Sources/AppDelegate.swift \
            Sources/SleepManager.swift \
            Sources/StatusBarManager.swift \
            Sources/LoginItemManager.swift \
            Sources/PreferencesWindowController.swift \
            Sources/Icons.swift

.PHONY: build clean install run

build:
	mkdir -p $(APP_DIR)/Contents/MacOS
	mkdir -p $(APP_DIR)/Contents/Resources
	swiftc $(SOURCES) \
		-o $(APP_DIR)/Contents/MacOS/$(APP_NAME) \
		-framework Cocoa \
		-framework ServiceManagement \
		-target arm64-apple-macosx13.0
	cp Resources/Info.plist $(APP_DIR)/Contents/
	codesign --force --deep --sign - $(APP_DIR)
	@echo "✓ Build complete: $(APP_DIR)"

clean:
	rm -rf $(BUILD_DIR)

install: build
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_DIR) /Applications/
	@echo "✓ Installed to /Applications/$(APP_NAME).app"

run: build
	open $(APP_DIR)
