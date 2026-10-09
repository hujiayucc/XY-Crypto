#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION=${1:?Flutter version is required}
DART_VERSION=${2:?Dart version is required}
FLUTTER_ROOT="${RUNNER_TEMP}/flutter-${FLUTTER_VERSION}-linux-arm64"
DART_ROOT=""
FLUTTER_BIN_DIR="${RUNNER_TEMP}/flutter-arm64-bin"

if [ ! -d "${FLUTTER_ROOT}/.git" ]; then
  rm -rf "${FLUTTER_ROOT}"
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_ROOT}"
fi

DART_BIN="$(command -v dart || true)"
if [ -z "${DART_BIN}" ]; then
  echo 'Dart ARM64 must be installed by dart-lang/setup-dart before this script.' >&2
  exit 2
fi

(
  cd "${FLUTTER_ROOT}/packages/flutter_tools"
  "${DART_BIN}" pub get --no-precompile
)

rm -rf "${FLUTTER_BIN_DIR}"
mkdir -p "${FLUTTER_BIN_DIR}"
cat > "${FLUTTER_BIN_DIR}/flutter" <<EOF
#!/usr/bin/env bash
export FLUTTER_ROOT="${FLUTTER_ROOT}"
exec "${DART_BIN}" \
  --packages="${FLUTTER_ROOT}/packages/flutter_tools/.dart_tool/package_config.json" \
  "${FLUTTER_ROOT}/packages/flutter_tools/bin/flutter_tools.dart" \
  --no-version-check --suppress-analytics "\$@"
EOF
chmod +x "${FLUTTER_BIN_DIR}/flutter"

export FLUTTER_ROOT
export PATH="${FLUTTER_BIN_DIR}:${PATH}"
printf 'FLUTTER_ROOT=%s\n' "${FLUTTER_ROOT}" >> "${GITHUB_ENV}"
printf '%s\n' "${FLUTTER_BIN_DIR}" >> "${GITHUB_PATH}"
"${FLUTTER_BIN_DIR}/flutter" precache --linux
"${FLUTTER_BIN_DIR}/flutter" --version
