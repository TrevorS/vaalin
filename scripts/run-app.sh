#!/bin/bash
# ABOUTME: Script to build and run Vaalin as a proper macOS .app bundle

set -e

echo "🔨 Building Vaalin..."

# Build using xcodebuild
xcodebuild \
  -scheme Vaalin \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build/xcode \
  build

echo "✅ Build complete!"
echo "📦 Creating .app bundle structure..."

# Create .app bundle structure
APP_DIR=".build/xcode/Build/Products/Debug/Vaalin.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp .build/xcode/Build/Products/Debug/Vaalin "$APP_DIR/Contents/MacOS/"

# Copy resource bundle
cp -R .build/xcode/Build/Products/Debug/Vaalin_Vaalin.bundle "$APP_DIR/Contents/Resources/"

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Vaalin</string>
	<key>CFBundleIdentifier</key>
	<string>org.trevorstrieber.vaalin</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Vaalin</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.games</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
</dict>
</plist>
EOF

echo "✅ .app bundle created!"
echo "🚀 Launching Vaalin.app..."

# Open the built app
open "$APP_DIR"

echo "✨ Vaalin is running!"
