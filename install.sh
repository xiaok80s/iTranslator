#!/bin/bash
# Builds iTranslator.app and installs it to ~/Applications
set -e
cd "$(dirname "$0")"
APP=build/iTranslator.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -o "$APP/Contents/MacOS/iTranslator" Sources/iTranslator/*.swift
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
swiftc -swift-version 5 -o build/make_icon tools/make_icon.swift
./build/make_icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
mkdir -p ~/Applications
rm -rf ~/Applications/iTranslator.app
cp -R "$APP" ~/Applications/
echo "Installed ~/Applications/iTranslator.app"
