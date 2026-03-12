################################################################################
# Clipboard Manager – macOS build & install
################################################################################

APP_NAME   = ClipboardManager
BUNDLE     = $(APP_NAME).app
EXECUTABLE = $(APP_NAME)
BUILD_DIR  = .build/release
INSTALL_DIR = /Applications

.PHONY: all build app sign install clean run

## Default target: build the .app bundle
all: app

## Compile with Swift Package Manager (release mode)
build:
	swift build -c release

## Assemble a proper .app bundle from the SPM output
app: build
	@echo "→ Assembling $(BUNDLE)…"
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(BUNDLE)/Contents/MacOS"
	@mkdir -p "$(BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(EXECUTABLE)"       "$(BUNDLE)/Contents/MacOS/"
	@cp "Resources/Info.plist"             "$(BUNDLE)/Contents/"
	@cp "Resources/ClipboardManager.entitlements" "$(BUNDLE)/Contents/Resources/"
	@echo "→ Bundle created: $(BUNDLE)"

## Ad-hoc code sign (required to run on macOS 10.15+)
## For distribution, replace '-' with your Apple Developer certificate.
sign: app
	@echo "→ Code signing $(BUNDLE)…"
	@codesign \
		--force \
		--deep \
		--sign - \
		--entitlements "Resources/ClipboardManager.entitlements" \
		"$(BUNDLE)"
	@echo "→ Signed."

## Copy the signed bundle to /Applications
install: sign
	@echo "→ Installing to $(INSTALL_DIR)/$(BUNDLE)…"
	@cp -R "$(BUNDLE)" "$(INSTALL_DIR)/"
	@echo "→ Done. Launch from Applications or run: open $(INSTALL_DIR)/$(BUNDLE)"

## Build, sign, and launch immediately (handy during development)
run: sign
	@open "$(BUNDLE)"

## Remove build artifacts
clean:
	@rm -rf .build "$(BUNDLE)"
	@echo "→ Cleaned."
