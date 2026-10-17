#!/bin/zsh
# Builds SpaceNames.app and wraps it in an installer package (and a zip) in ./build
set -euo pipefail
cd "${0:A:h}"
./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
STAGE=build/pkgroot
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R build/SpaceNames.app "$STAGE/"

# Always install to /Applications, even if another copy exists elsewhere.
pkgbuild --analyze --root "$STAGE" build/components.plist >/dev/null
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' build/components.plist

pkgbuild --root "$STAGE" \
  --component-plist build/components.plist \
  --identifier com.jrp.SpaceNames.pkg \
  --version "$VERSION" \
  --install-location /Applications \
  "build/SpaceNames-$VERSION.pkg"

ditto -c -k --keepParent build/SpaceNames.app "build/SpaceNames-$VERSION.zip"
rm -rf "$STAGE" build/components.plist
echo "Packaged build/SpaceNames-$VERSION.pkg and build/SpaceNames-$VERSION.zip"
