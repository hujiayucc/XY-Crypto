# iOS IPA CI signing

The repository now has two iOS automation paths:

- `.github/workflows/ios-ipa.yml` builds one signed IPA on demand.
- `.github/workflows/release.yml` and `.github/workflows/ci.yml` use the same signing materials when they are present. Without them, the existing unsigned iOS archive is kept as a fallback.

Apple account registration, identity verification, two-factor authentication, and membership enrollment stay as an account-owner step. After the Apple signing files exist, GitHub Actions performs the repeatable build, signing, verification, and artifact upload.

## GitHub configuration

Add these repository Secrets:

- `IOS_CERTIFICATE_BASE64`: base64 of a password-protected `.p12` containing the Apple signing certificate and private key.
- `IOS_CERTIFICATE_PASSWORD`: password for that `.p12`.
- `IOS_PROVISIONING_PROFILE_BASE64`: base64 of the matching `.mobileprovision`.

Add these repository Variables:

- `IOS_BUNDLE_ID`: `com.hujiayucc.decode`.
- `IOS_TEAM_ID`: the Apple Team ID. The workflow also reads it from the profile when this variable is empty.
- `IOS_CODE_SIGN_IDENTITY`: `Apple Development` for a free Personal Team or development build; use `Apple Distribution` for a distribution certificate.
- `IOS_EXPORT_METHOD`: normally `development` for the existing release workflow. The dedicated IPA workflow lets its manual input override this value.

Keep the certificate, private key, profile, and password out of the repository. The workflow creates an ephemeral keychain, deletes it at the end of the job, and removes generated `Signing.xcconfig` and `ExportOptions.plist` files.

## Paid Apple Developer Program

For a paid team, the signing files can be created without macOS:

1. Register `com.hujiayucc.decode` under Certificates, Identifiers & Profiles.
2. Generate a certificate-signing request and upload it to Apple Developer.
3. Download the Apple certificate as a `.cer` file.
4. Create a development, ad-hoc, or App Store provisioning profile that matches the bundle ID and team.
5. Convert the certificate and the private key into a password-protected `.p12`.
6. Base64-encode the `.p12` and `.mobileprovision`, then place the values in the three Secrets above.

Example Linux conversion commands:

```text
openssl genrsa -out ios-signing.key 2048
openssl req -new -key ios-signing.key -out ios-signing.csr -subj "/CN=XY Crypto iOS signing"
openssl x509 -inform DER -in ios_development.cer -out ios_development.pem
openssl pkcs12 -export -inkey ios-signing.key -in ios_development.pem -out ios_development.p12 -name "Apple Development"
base64 -w 0 ios_development.p12 > ios_development.p12.b64
base64 -w 0 XY_Crypto.mobileprovision > XY_Crypto.mobileprovision.b64
```

On systems whose `base64` has no `-w` option, use its single-line/base64 output mode and remove line breaks before putting the value into a Secret.

## Free Personal Team

A free Apple Account can use a Personal Team for device testing. Apple manages its App IDs, certificates, devices, and provisioning profiles through Xcode, and these profiles normally expire after 7 days. The dedicated workflow uses `development`; `ad-hoc` and `app-store` require the corresponding paid distribution capability.

The free account enrollment and the first Personal Team signing material still require an interactive Apple/Xcode setup. Once the `.p12` and `.mobileprovision` are exported, this repository workflow can rebuild the IPA on a macOS runner. Refresh the two files when Apple expires the Personal Team profile.

## Running the workflow

Open Actions, select `XY Crypto iOS IPA`, choose `development`, and select `Run workflow`. The verified artifact is named:

`XY加密-iOS-arm64.ipa`

The normal Release and Preview workflows also publish an IPA when the signing Secrets are available. The generated manifest therefore contains the `.ipa` filename instead of the unsigned `.tar.gz` filename.
