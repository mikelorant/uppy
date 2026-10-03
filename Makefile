.DEFAULT_GOAL := app

SWIFT := swift
CLT_TOOLSET := $(shell if [ "$$(xcode-select -p)" = /Library/Developer/CommandLineTools ]; then printf '%s' '--toolset Scripts/clt-toolset.json'; fi)
SWIFT_FLAGS ?= $(CLT_TOOLSET) -Xswiftc -warnings-as-errors -Xlinker -fatal_warnings
APP_DIR := .build/app/Uppy.app
CHECK_APP := .build/checks/UppyChecks.app
ICON := Bundle/Contents/Resources/Uppy.icns

.PHONY: app build debug test test-core test-ui test-app test-tooling icon format lint verify universal run clean

build:
	$(SWIFT) build $(SWIFT_FLAGS) -c release --product Uppy

universal:
	@if [ "$$(xcode-select -p)" = /Library/Developer/CommandLineTools ]; then printf '%s\n' 'Universal builds require full Xcode with Intel compatibility libraries.' >&2; exit 1; fi
	$(MAKE) app SWIFT_FLAGS="$(SWIFT_FLAGS) --arch arm64 --arch x86_64"
	lipo -verify_arch arm64 x86_64 "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"

debug:
	$(SWIFT) build $(SWIFT_FLAGS) --product Uppy

format:
	$(SWIFT) format format --in-place --recursive Package.swift Sources Tests

lint:
	$(SWIFT) format lint --strict --recursive Package.swift Sources Tests

verify:
	bash Scripts/verify.sh

test:
	$(MAKE) test-tooling
	$(MAKE) test-core
	$(MAKE) test-ui
	$(MAKE) test-app

test-tooling:
	bash -n Scripts/build-icon.sh Scripts/verify.sh
	/usr/bin/python3 Scripts/test-tooling.py

test-core:
	$(SWIFT) run $(SWIFT_FLAGS) UppyChecks

test-ui:
	$(SWIFT) run $(SWIFT_FLAGS) UppyUIChecks

icon: $(ICON)

$(ICON): Assets/Logo.png Scripts/build-icon.sh
	bash Scripts/build-icon.sh

test-app: icon
	$(SWIFT) build $(SWIFT_FLAGS) --product UppyChecks
	rm -rf "$(CHECK_APP)"
	mkdir -p "$(CHECK_APP)/Contents/MacOS" "$(CHECK_APP)/Contents/Resources"
	cp Bundle/Contents/Info.plist "$(CHECK_APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable UppyChecks' "$(CHECK_APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.uppy.regression-checks' "$(CHECK_APP)/Contents/Info.plist"
	cp "$$( $(SWIFT) build $(SWIFT_FLAGS) --show-bin-path )/UppyChecks" "$(CHECK_APP)/Contents/MacOS/UppyChecks"
	cp "$(ICON)" "$(CHECK_APP)/Contents/Resources/Uppy.icns"
	codesign --force --sign - "$(CHECK_APP)"
	codesign --verify --strict "$(CHECK_APP)"
	"$(CHECK_APP)/Contents/MacOS/UppyChecks" --packaged

app: build icon
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp Bundle/Contents/Info.plist "$(APP_DIR)/Contents/Info.plist"
	cp "$$( $(SWIFT) build $(SWIFT_FLAGS) -c release --show-bin-path )/Uppy" "$(APP_DIR)/Contents/MacOS/Uppy"
	cp "$(ICON)" "$(APP_DIR)/Contents/Resources/Uppy.icns"
	chmod +x "$(APP_DIR)/Contents/MacOS/Uppy"
	codesign --force --sign - "$(APP_DIR)"
	codesign --verify --strict "$(APP_DIR)"
	@echo 'Built: $(APP_DIR)'

run: app
	open "$(APP_DIR)"

clean:
	$(SWIFT) package clean
	rm -rf "$(APP_DIR)" "$(CHECK_APP)" .build/icons
