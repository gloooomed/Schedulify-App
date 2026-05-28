# ─────────────────────────────────────────────────────────────────────────────
# Makefile — Schedulify build targets
#
# All targets read dart_defines.json — never .env.
#
# Usage:
#   make ios                  # run on booted iOS simulator
#   make ios-device ID=<uuid> # run on specific iOS device/simulator
#   make ios-build            # build IPA (no codesign)
#   make ios-release          # build signed IPA
#   make android              # run on connected Android device/emulator
#   make android-build        # build release APK
#   make android-aab          # build release App Bundle
#   make clean                # flutter clean
# ─────────────────────────────────────────────────────────────────────────────

DEFINES        := --dart-define-from-file=dart_defines.json
DEFINES_FILE   := dart_defines.json
SIMULATOR_ID   ?= 4D7F12CB-EBB0-4C12-A0C3-F4236C523D04   # iPhone 17 (update as needed)
ID             ?= $(SIMULATOR_ID)

.PHONY: check-defines ios ios-device ios-build ios-release android android-build android-aab clean

# ── Guard: ensure dart_defines.json exists ───────────────────────────────────
check-defines:
	@if [ ! -f "$(DEFINES_FILE)" ]; then \
		echo ""; \
		echo "  ❌  $(DEFINES_FILE) not found. Copy from template:"; \
		echo "      cp .env.example dart_defines.json"; \
		echo ""; \
		exit 1; \
	fi

# ── iOS ───────────────────────────────────────────────────────────────────────

## Run on the default booted iOS simulator
ios: check-defines
	flutter run -d $(SIMULATOR_ID) $(DEFINES)

## Run on a specific device/simulator — usage: make ios-device ID=<uuid>
ios-device: check-defines
	flutter run -d $(ID) $(DEFINES)

## Build unsigned IPA (CI / no Apple account required)
ios-build: check-defines
	flutter build ipa $(DEFINES) --no-codesign
	@echo ""
	@echo "  ✅  IPA → build/ios/ipa/"

## Build signed IPA (requires valid provisioning profile)
ios-release: check-defines
	flutter build ipa $(DEFINES)
	@echo ""
	@echo "  ✅  Signed IPA → build/ios/ipa/"

# ── Android ───────────────────────────────────────────────────────────────────

## Run on connected Android device / emulator
android: check-defines
	flutter run $(DEFINES)

## Build release APK
android-build: check-defines
	flutter build apk --release $(DEFINES)
	@echo ""
	@echo "  ✅  APK → build/app/outputs/flutter-apk/"

## Build release App Bundle (Play Store)
android-aab: check-defines
	flutter build appbundle --release $(DEFINES)
	@echo ""
	@echo "  ✅  AAB → build/app/outputs/bundle/release/"

# ── Misc ─────────────────────────────────────────────────────────────────────
clean:
	flutter clean
