#!/usr/bin/env bash
set -euo pipefail

# Build a normal development-signed IPA without invoking xcodebuild. This
# script still uses Apple's SDK and Swift compiler, but all staging, signing,
# and packaging happen here so the output is reproducible from Terminal.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="NappStore"
IPA_NAME="NappStore"
OUTPUT_DIR="${ROOT_DIR}/output"
BUILD_STAMP="$(date +%Y%m%d-%H%M%S)"
STAGE_DIR="${ROOT_DIR}/build/ipa-${BUILD_STAMP}"
PAYLOAD_DIR="${STAGE_DIR}/Payload"
APP_DIR="${PAYLOAD_DIR}/${APP_NAME}.app"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"

mkdir -p "${APP_DIR}" "${OUTPUT_DIR}"

SWIFT_FILES=()
while IFS= read -r file; do
    SWIFT_FILES+=("${file}")
done < <(rg --files "${ROOT_DIR}/Sources" -g '*.swift' | sort)
if [[ "${#SWIFT_FILES[@]}" -eq 0 ]]; then
    echo "Không tìm thấy mã nguồn Swift trong Sources" >&2
    exit 1
fi

echo "[1/4] Biên dịch ${#SWIFT_FILES[@]} file Swift bằng SDK iphoneos"
xcrun --sdk iphoneos swiftc \
    -target arm64-apple-ios16.0 \
    -sdk "${SDK_PATH}" \
    -module-name "${APP_NAME}" \
    -O \
    -parse-as-library \
    -framework UIKit \
    -framework SwiftUI \
    -framework Foundation \
    -framework CoreServices \
    -framework StoreKit \
    "${SWIFT_FILES[@]}" \
    -o "${APP_DIR}/${APP_NAME}"

echo "[2/4] Đặt metadata và icon"
cp "${ROOT_DIR}/Info.plist" "${APP_DIR}/Info.plist"
if [[ -f "${ROOT_DIR}/AppIcon.png" ]]; then
    cp "${ROOT_DIR}/AppIcon.png" "${APP_DIR}/AppIcon.png"
    cp "${ROOT_DIR}/AppIcon.png" "${APP_DIR}/AppIcon60x60@2x.png"
    cp "${ROOT_DIR}/AppIcon.png" "${APP_DIR}/AppIcon60x60@3x.png"
fi



echo "[3/4] Ký ad-hoc với entitlements TrollStore"
ENTITLEMENTS="${ROOT_DIR}/entitlements.plist"
if command -v ldid &>/dev/null; then
    ldid -S"${ENTITLEMENTS}" "${APP_DIR}/${APP_NAME}"
else
    codesign --force --deep --sign - \
        --entitlements "${ENTITLEMENTS}" \
        --timestamp=none "${APP_DIR}"
fi

echo "[4/4] Đóng gói TIPA"
TIPA_PATH="${OUTPUT_DIR}/${IPA_NAME}.tipa"
(cd "${STAGE_DIR}" && /usr/bin/zip -qr "${TIPA_PATH}" Payload)

echo "TIPA: ${TIPA_PATH}"
echo "Cài bằng TrollStore trên thiết bị."
