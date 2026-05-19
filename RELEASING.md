# Releasing AutoQuit

AutoQuit is distributed outside the Mac App Store as a Developer ID signed and notarized macOS app.

## One-time Apple setup

1. Create or download a **Developer ID Application** certificate.
   - Apple Developer: https://developer.apple.com/account/resources/certificates/list
   - If creating it on the website, choose `Developer ID Application` and upload a certificate signing request from Keychain Access.
   - Install the downloaded certificate in the login keychain.

2. Create an app-specific password for notarization.
   - Apple Account: https://account.apple.com/account/manage
   - Sign-In and Security -> App-Specific Passwords.

3. Store notarization credentials in the local keychain.

   ```bash
   xcrun notarytool store-credentials autoquit-notary \
     --apple-id "YOUR_APPLE_ID_EMAIL" \
     --team-id "35BT7G59BF" \
     --password "YOUR_APP_SPECIFIC_PASSWORD"
   ```

## Local release

Run from the repo root:

```bash
just release 1.0.0
```

The release script will:

- build `AutoQuit.app` with XcodeGen/Xcode,
- sign it with the installed `Developer ID Application` identity,
- submit the app to Apple notarization,
- staple the notarization ticket to the app,
- create a zip for automation/Homebrew,
- create a signed DMG for the normal drag-to-Applications install flow,
- notarize and staple the DMG,
- verify with `codesign`, `stapler`, and `spctl`,
- write `dist/AutoQuit-v<version>.dmg`, `dist/AutoQuit-v<version>-macos.zip`, and `.sha256` files.

If you use a different notarytool profile name:

```bash
NOTARYTOOL_PROFILE=my-profile just release 1.0.0
```

If multiple Developer ID certificates are installed:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Example Name (TEAMID)" just release 1.0.0
```
