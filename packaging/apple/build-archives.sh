#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR=${1:-ci-dist}

# Name the archive after the Mach-O slices, not the runner's CPU architecture.
architecture_label() {
  local executable=$1 architectures
  architectures="$(lipo -archs "${executable}")"
  case "${architectures}" in
    arm64) printf '%s\n' arm64 ;;
    x86_64) printf '%s\n' x86_64 ;;
    'arm64 x86_64'|'x86_64 arm64') printf '%s\n' universal ;;
    *) echo "Unexpected Apple executable architectures: ${architectures}" >&2; return 1 ;;
  esac
}

mkdir -p "${OUTPUT_DIR}"
ios_app=$(find build/ios/iphoneos -maxdepth 1 -name '*.app' -print -quit 2>/dev/null || true)
if [ -z "${ios_app}" ]; then
  ios_app=$(find build/ios/archive -path '*/Products/Applications/*.app' -print -quit 2>/dev/null || true)
fi
mac_app=$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' -print -quit 2>/dev/null || true)
if [ -z "${ios_app}" ] || [ -z "${mac_app}" ]; then
  echo 'Both iOS and macOS app bundles are required.' >&2
  exit 1
fi

ios_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${ios_app}/Info.plist")
mac_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${mac_app}/Contents/Info.plist")
ios_arch=$(architecture_label "${ios_app}/${ios_executable}")
mac_arch=$(architecture_label "${mac_app}/Contents/MacOS/${mac_executable}")
ios_name="XY加密-iOS-${ios_arch}"
macos_name="XY加密-macOS-${mac_arch}"

if [ -n "${IOS_IPA_PATH:-}" ]; then
  if [ ! -f "${IOS_IPA_PATH}" ]; then
    echo "Signed iOS IPA not found: ${IOS_IPA_PATH}" >&2
    exit 1
  fi
  cp "${IOS_IPA_PATH}" "${OUTPUT_DIR}/${ios_name}.ipa"
  ios_file="${ios_name}.ipa"
else
  tar -C "$(dirname "${ios_app}")" -czf "${OUTPUT_DIR}/${ios_name}.tar.gz" "$(basename "${ios_app}")"
  ios_file="${ios_name}.tar.gz"
fi
ditto -c -k --sequesterRsrc --keepParent "${mac_app}" "${OUTPUT_DIR}/${macos_name}.zip"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  printf 'ios_name=%s\nios_file=%s\nmacos_name=%s\n' \
    "${ios_name}" "${ios_file}" "${macos_name}" >> "${GITHUB_OUTPUT}"
fi
printf 'Created %s and %s.zip\n' "${ios_file}" "${macos_name}"
