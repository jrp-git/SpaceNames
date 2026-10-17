#!/bin/zsh
# Builds a universal, ad-hoc signed SpaceNames.app into ./build
set -euo pipefail
cd "${0:A:h}"
APP=build/SpaceNames.app
rm -rf build && mkdir -p "$APP/Contents/MacOS"
for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos13.0 -import-objc-header Sources/Bridge.h \
    Sources/*.swift -o build/SpaceNames-$arch
done
lipo -create build/SpaceNames-arm64 build/SpaceNames-x86_64 -output "$APP/Contents/MacOS/SpaceNames"
rm build/SpaceNames-*
cp Info.plist "$APP/Contents/Info.plist"
# Sign with the local self-signed identity so the Accessibility approval survives rebuilds.
IDENTITY="SpaceNames Local Signing"
if security find-identity -v -p codesigning | grep -q "\"$IDENTITY\""; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  echo "warning: '$IDENTITY' not found; ad-hoc signing (Accessibility must be re-added after each build)"
  codesign --force --sign - "$APP"
fi
echo "Built $APP"
