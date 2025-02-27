#!/bin/bash
set -euo pipefail

# Required environment variables:
# APP_PATH: Path to your .app bundle
# DMG_PATH: Path to your .dmg file
# P12_PATH: Path to your .p12 certificate file
# P12_PASSWORD: Password for the .p12 file
# API_KEY_ID: App Store Connect API Key ID
# API_KEY_ISSUER_ID: App Store Connect API Key Issuer ID
# API_KEY_PATH: Path to the API key file (.p8)

# Create temporary keychain
KEYCHAIN_NAME="notary-keychain"
KEYCHAIN_PASSWORD="temp-password"

# Create and configure keychain
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

# Import certificate
security import "$P12_PATH" -k "$KEYCHAIN_NAME" -P "$P12_PASSWORD" -T /usr/bin/codesign

# Configure keychain for access
security set-keychain-settings -t 3600 -l "$KEYCHAIN_NAME"
security list-keychains -d user -s "$KEYCHAIN_NAME" $(security list-keychains -d user | tr -d '"')

# Very important: Allow codesign to access the keys without user input
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

# Sign the .app bundle
codesign --force --options runtime --sign "Developer ID Application" --deep --keychain "$KEYCHAIN_NAME" "$APP_PATH"

create-dmg "$DMG_PATH" "$APP_PATH"
# Create DMG and sign it
# Assuming DMG is already created
codesign --force --options runtime --sign "Developer ID Application" --keychain "$KEYCHAIN_NAME" "$DMG_PATH"

# Notarize the DMG
echo "Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --key "$API_KEY_PATH" \
    --key-id "$API_KEY_ID" \
    --issuer "$API_KEY_ISSUER_ID" \
    --wait

# Staple the notarization ticket
xcrun stapler staple "$DMG_PATH"

# Clean up keychain
security delete-keychain "$KEYCHAIN_NAME"

echo "Notarization and stapling complete!"
