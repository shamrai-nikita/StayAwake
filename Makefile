APP_NAME  = StayAwake
BUILD_DIR = build
APP_DIR   = $(BUILD_DIR)/$(APP_NAME).app
SUDOERS_FILE = /etc/sudoers.d/stayawake
SOURCES   = Sources/main.swift \
            Sources/AppDelegate.swift \
            Sources/SleepManager.swift \
            Sources/StatusBarManager.swift \
            Sources/LoginItemManager.swift \
            Sources/PreferencesWindowController.swift \
            Sources/Icons.swift

.PHONY: build clean install install-helper uninstall-helper run

build:
	mkdir -p $(APP_DIR)/Contents/MacOS
	mkdir -p $(APP_DIR)/Contents/Resources
	swiftc $(SOURCES) \
		-o $(APP_DIR)/Contents/MacOS/$(APP_NAME) \
		-framework Cocoa \
		-framework ServiceManagement \
		-framework LocalAuthentication \
		-target arm64-apple-macosx13.0
	cp Resources/Info.plist $(APP_DIR)/Contents/
	codesign --force --deep --sign - $(APP_DIR)
	@echo "✓ Build complete: $(APP_DIR)"

clean:
	rm -rf $(BUILD_DIR)

install: build install-helper
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_DIR) /Applications/
	@echo "✓ Installed to /Applications/$(APP_NAME).app"

install-helper:
	@echo "Installing Touch ID helper (passwordless pmset rule)…"
	@echo "$$USER ALL=(ALL) NOPASSWD: /usr/bin/pmset" | sudo tee $(SUDOERS_FILE) > /dev/null
	@sudo chmod 0440 $(SUDOERS_FILE)
	@sudo visudo -c -f $(SUDOERS_FILE)
	@echo "✓ Helper installed at $(SUDOERS_FILE)"

uninstall-helper:
	sudo rm -f $(SUDOERS_FILE)
	@echo "✓ Helper removed"

run: build
	open $(APP_DIR)
