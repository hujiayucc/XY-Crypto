#!/usr/bin/env bash
set -euo pipefail

# Prepare a temporary manual-signing configuration for a macOS CI runner.
: "${IOS_CERTIFICATE_BASE64:?IOS_CERTIFICATE_BASE64 is required}"
: "${IOS_CERTIFICATE_PASSWORD:?IOS_CERTIFICATE_PASSWORD is required}"
: "${IOS_PROVISIONING_PROFILE_BASE64:?IOS_PROVISIONING_PROFILE_BASE64 is required}"

workspace="${GITHUB_WORKSPACE:-$PWD}"
bundle_id="${IOS_BUNDLE_ID:-com.hujiayucc.decode}"
team_id="${IOS_TEAM_ID:-}"
export_method="${IOS_EXPORT_METHOD:-development}"
code_sign_identity="${IOS_CODE_SIGN_IDENTITY:-Apple Development}"
decode_base64() {
  if base64 --help 2>&1 | grep -q -- '--decode'; then
    base64 --decode
  else
    base64 -D
  fi
}

certificate_file="$(mktemp "${TMPDIR:-/tmp}/xy-signing.XXXXXX")"
profile_file="$(mktemp "${TMPDIR:-/tmp}/xy-profile.XXXXXX")"
profile_plist="$(mktemp "${TMPDIR:-/tmp}/xy-profile.XXXXXX")"
keychain_file="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/xy-ios-signing.keychain-db"
keychain_password="$(openssl rand -hex 32)"
trap 'rm -f "$certificate_file" "$profile_file" "$profile_plist"' EXIT

printf '%s' "$IOS_CERTIFICATE_BASE64" | decode_base64 > "$certificate_file"
printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | decode_base64 > "$profile_file"

security create-keychain -p "$keychain_password" "$keychain_file"
security set-keychain-settings -lut 21600 "$keychain_file"
security unlock-keychain -p "$keychain_password" "$keychain_file"
security import "$certificate_file" -k "$keychain_file" \
  -P "$IOS_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "$keychain_password" "$keychain_file"
security list-keychains -d user -s "$keychain_file"
security default-keychain -s "$keychain_file"
security find-identity -v -p codesigning "$keychain_file"

printf 'IOS_SIGNING_KEYCHAIN=%s\n' "$keychain_file" >> "${GITHUB_ENV:-/dev/null}"

security cms -D -i "$profile_file" -o "$profile_plist"


profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$profile_plist")"
profile_name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$profile_plist")"
profile_team="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$profile_plist")"
application_identifier="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$profile_plist")"

if [[ -z "$team_id" ]]; then
  team_id="$profile_team"
fi
if [[ "$team_id" != "$profile_team" ]]; then
  echo "IOS_TEAM_ID does not match the provisioning profile." >&2
  exit 1
fi
case "$application_identifier" in
  "$team_id.$bundle_id"|"$team_id".*) ;;
  *)
    echo "Provisioning profile does not cover bundle identifier $bundle_id." >&2
    exit 1
    ;;
esac

profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$profile_dir"
profile_install_path="$profile_dir/$profile_uuid.mobileprovision"
cp "$profile_file" "$profile_install_path"
printf 'IOS_SIGNING_PROFILE_PATH=%s\n' "$profile_install_path" >> "${GITHUB_ENV:-/dev/null}"

signing_config="$workspace/ios/Flutter/Signing.xcconfig"
export_options="$workspace/ios/ExportOptions.plist"
mkdir -p "$(dirname "$signing_config")"

cat > "$signing_config" <<EOF
// Generated in CI. Do not commit signing material.
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = $team_id
PRODUCT_BUNDLE_IDENTIFIER = $bundle_id
PROVISIONING_PROFILE_SPECIFIER = $profile_uuid
CODE_SIGN_IDENTITY = $code_sign_identity
CODE_SIGN_IDENTITY[sdk=iphoneos*] = $code_sign_identity
PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*] = $profile_uuid
EOF
EXPORT_OPTIONS_PATH="$export_options" \
EXPORT_METHOD="$export_method" \
EXPORT_TEAM_ID="$team_id" \
EXPORT_BUNDLE_ID="$bundle_id" \
EXPORT_PROFILE_NAME="$profile_name" \
python3 - <<'PY'
import os
import plistlib

options = {
    'method': os.environ['EXPORT_METHOD'],
    'signingStyle': 'manual',
    'teamID': os.environ['EXPORT_TEAM_ID'],
    'provisioningProfiles': {
        os.environ['EXPORT_BUNDLE_ID']: os.environ['EXPORT_PROFILE_NAME'],
    },
    'stripSwiftSymbols': True,
    'uploadBitcode': False,
}
with open(os.environ['EXPORT_OPTIONS_PATH'], 'wb') as output:
    plistlib.dump(options, output, fmt=plistlib.FMT_XML, sort_keys=False)
PY

printf 'Prepared iOS signing: team=%s bundle=%s profile=%s method=%s\n' \
  "$team_id" "$bundle_id" "$profile_name" "$export_method"
