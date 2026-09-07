#!/usr/bin/env bash
set -e

APP_NAME="Fleet"
BUNDLE_DIR="$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building $APP_NAME for Release..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift build -c release

echo "📦 Creating macOS App Bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 실행 바이너리 복사
cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# 리소스 번들 복사 (SwiftTerm 등)
cp -r .build/release/*.bundle "$RESOURCES_DIR/" 2>/dev/null || true
if [ -f "StitchDesigns/AppIcon.icns" ]; then
    cp "StitchDesigns/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# 다국어 지원: SwiftPM 리소스 번들 내부의 *.lproj를 앱 번들 최상위로 끌어올려
# Bundle.main 기본 지역화 조회(SwiftUI Text 등)가 바로 찾을 수 있도록 함
for bundle_dir in "$RESOURCES_DIR"/*.bundle; do
    [ -d "$bundle_dir" ] || continue
    for lproj_dir in "$bundle_dir"/*.lproj; do
        [ -d "$lproj_dir" ] || continue
        lproj_name=$(basename "$lproj_dir")
        # zh-hans.lproj -> zh-Hans.lproj 로 표준 대소문자 보정
        case "$lproj_name" in
            zh-hans.lproj) lproj_name="zh-Hans.lproj" ;;
            zh-hant.lproj) lproj_name="zh-Hant.lproj" ;;
        esac
        mkdir -p "$RESOURCES_DIR/$lproj_name"
        cp -r "$lproj_dir"/. "$RESOURCES_DIR/$lproj_name/"
    done
done

# Info.plist 생성
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.workmanager.macos</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>ko</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>ko</string>
        <string>en</string>
        <string>ja</string>
        <string>zh-Hans</string>
    </array>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Fleet는 외부 터미널(Terminal.app, iTerm2 등)을 열어 AI 에이전트 작업을 자동 실행하기 위해 권한이 필요합니다.</string>
</dict>
</plist>
EOF

echo "✅ App bundle created successfully: $BUNDLE_DIR"
echo "🚀 To launch the app, run: open $BUNDLE_DIR"
