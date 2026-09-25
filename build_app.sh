#!/bin/zsh
set -euo pipefail

APP_NAME="McClean"
APP_BUNDLE="${APP_NAME}.app"
BUILD_FLAGS=()

if [[ "${1:-}" == "--app-store" ]]; then
    echo "Building ${APP_NAME} in Mac App Store mode (-DAPP_STORE)..."
    BUILD_FLAGS=(-Xswiftc -DAPP_STORE)
else
    echo "Building ${APP_NAME} in Open Source / Direct release mode..."
fi

swift build -c release "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${BUILD_FLAGS[@]}" --show-bin-path)"

echo "Packaging ${APP_BUNDLE} from ${BIN_DIR}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"
touch "${APP_BUNDLE}"

if [[ "${1:-}" == "--app-store" ]]; then
    codesign --force --deep --entitlements "Resources/McClean.entitlements" --sign - "${APP_BUNDLE}" 2>/dev/null || true
else
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
fi

echo "Successfully built ${APP_BUNDLE}!"
