#!/bin/sh
# Builds a release at build/release: Peek Pro signed with Developer ID and
# notarized, in a signed and notarized DMG (make-dmg.sh). Needs a Developer ID
# Application certificate and a notarytool profile, NOTARY_PROFILE (peek-pro by
# default).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
project=$root/Peek\ Pro.xcodeproj
out=$root/build/release
profile=${NOTARY_PROFILE:-peek-pro}

# A DMG that no commit matches could not be tagged.
if [ -n "$(git -C "$root" status --porcelain)" ]; then
    echo "error: uncommitted changes; a release is built from a commit" >&2
    exit 1
fi

team=$(xcodebuild -project "$project" -scheme "Peek Pro" -configuration Release -showBuildSettings 2>/dev/null |
    awk '$1 == "DEVELOPMENT_TEAM" { print $3; exit }')
identity=$(security find-identity -v -p codesigning |
    awk -v team="($team)\"" '/"Developer ID Application: / && index($0, team) { print $2; exit }')
if [ -z "$identity" ]; then
    echo "error: no Developer ID Application certificate for team $team;" \
        "create one in Xcode → Settings → Accounts → Manage Certificates" >&2
    exit 1
fi
if ! xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1; then
    echo "error: no notary profile $profile; run" \
        "xcrun notarytool store-credentials $profile --apple-id <Apple ID> --team-id $team" >&2
    exit 1
fi

notarize() {
    log=$out/notary-$(basename "$1").log
    xcrun notarytool submit "$1" --keychain-profile "$profile" --wait | tee "$log"
    if ! grep -q '^ *status: Accepted' "$log"; then
        id=$(awk '$1 == "id:" { print $2; exit }' "$log")
        if [ -n "$id" ]; then
            xcrun notarytool log "$id" --keychain-profile "$profile" >&2 || true
        fi
        echo "error: Apple did not notarize $(basename "$1")" >&2
        exit 1
    fi
}

rm -rf "$out"
mkdir -p "$out"

xcodebuild archive -quiet -project "$project" -scheme "Peek Pro" -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$out/Peek Pro.xcarchive" -allowProvisioningUpdates

cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$team</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -quiet -archivePath "$out/Peek Pro.xcarchive" -exportPath "$out/export" \
    -exportOptionsPlist "$out/ExportOptions.plist" -allowProvisioningUpdates

app=$out/export/Peek\ Pro.app
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$app/Contents/Info.plist")
dmg=$out/Peek-Pro-$version.dmg

# The app is notarized on its own first, so that it opens offline once copied out of the DMG.
ditto -c -k --keepParent "$app" "$out/Peek Pro.zip"
notarize "$out/Peek Pro.zip"
xcrun stapler staple "$app"

"$root/scripts/make-dmg.sh" "$app" "$dmg"
codesign --sign "$identity" --timestamp "$dmg"
notarize "$dmg"
xcrun stapler staple "$dmg"

spctl --assess --type execute -v "$app"
spctl --assess --type open --context context:primary-signature -v "$dmg"

echo
echo "Peek Pro $version from $(git -C "$root" rev-parse --short HEAD): $dmg"
shasum -a 256 "$dmg"
