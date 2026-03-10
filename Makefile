APP_NAME    = TimeTracker
BUNDLE_ID   = com.wiseelf.timetracker
MIN_MACOS   = 13.0
BINARY      = .build/release/$(APP_NAME)
APP_DIR     = dist/$(APP_NAME).app
CONTENTS    = $(APP_DIR)/Contents
MACOS_DIR   = $(CONTENTS)/MacOS
RES_DIR     = $(CONTENTS)/Resources

# Use Developer ID if available, otherwise ad-hoc (-) signing
IDENTITY   ?= -

.PHONY: all build app sign clean

all: app

## 1. Compile release binary
build:
	swift build -c release

## 2. Assemble the .app bundle
app: build
	@echo "→ Assembling $(APP_NAME).app …"
	@rm -rf $(APP_DIR)
	@mkdir -p $(MACOS_DIR) $(RES_DIR)

	@cp $(BINARY) $(MACOS_DIR)/$(APP_NAME)

	@/usr/libexec/PlistBuddy -c "Add :CFBundleName             string '$(APP_NAME)'"           $(CONTENTS)/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable       string '$(APP_NAME)'"           $(CONTENTS)/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier       string '$(BUNDLE_ID)'"          $(CONTENTS)/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType      string 'APPL'"                  $(CONTENTS)/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string '1.0'"                 $(CONTENTS)/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleVersion          string '1'"                     $(CONTENTS)/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion   string '$(MIN_MACOS)'"          $(CONTENTS)/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :LSUIElement              bool   true"                    $(CONTENTS)/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable  bool   true"                    $(CONTENTS)/Info.plist 2>/dev/null || true

	@$(MAKE) --no-print-directory sign
	@echo "✓ Built: $(APP_DIR)"

## 3. Sign (ad-hoc by default; set IDENTITY=<Developer ID> for real signing)
sign:
	@echo "→ Signing with identity: $(IDENTITY)"
	@codesign --force --deep --sign "$(IDENTITY)" $(APP_DIR)

## 4. Package for sharing — creates dist/TimeTracker.dmg
dmg: app
	@echo "→ Creating DMG …"
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder dist/$(APP_NAME).app \
		-ov -format UDZO \
		dist/$(APP_NAME).dmg
	@echo "✓ Ready to share: dist/$(APP_NAME).dmg"

## 5. Clean
clean:
	@rm -rf .build dist
