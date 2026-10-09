#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION=${1:?Flutter version is required}
DART_VERSION=${2:?Dart version is required}
FLUTTER_ROOT="${RUNNER_TEMP}/flutter-${FLUTTER_VERSION}-linux-arm64"
if [ ! -d "${FLUTTER_ROOT}/.git" ]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_ROOT}"
fi
DART_BIN="$(command -v dart)"
DART_BIN="$(readlink -f "${DART_BIN}")"
DART_ROOT="$(dirname "$(dirname "${DART_BIN}")")"
DART_INFO="$("${DART_BIN}" --version 2>&1)"
if [[ "${DART_INFO}" != *"${DART_VERSION}"* || "${DART_INFO}" != *linux_arm64* ]]; then
  echo "Expected Dart ${DART_VERSION} linux_arm64; got ${DART_INFO}" >&2
  exit 2
fi

# Both pub and the CMake backend require the SDK at this standard location.
mkdir -p "${FLUTTER_ROOT}/bin/cache"
if [ ! -e "${FLUTTER_ROOT}/bin/cache/dart-sdk" ]; then
  ln -s "${DART_ROOT}" "${FLUTTER_ROOT}/bin/cache/dart-sdk"
fi
cp "${FLUTTER_ROOT}/bin/internal/engine.version" "${FLUTTER_ROOT}/bin/cache/engine.stamp"
cp "${FLUTTER_ROOT}/bin/internal/engine.version" "${FLUTTER_ROOT}/bin/cache/engine-dart-sdk.stamp"
: > "${FLUTTER_ROOT}/bin/cache/engine.realm"
export FLUTTER_ROOT
(
  cd "${FLUTTER_ROOT}/packages/flutter_tools"
  "${DART_BIN}" pub get --no-precompile
)

# The CMake backend calls this absolute path instead of resolving Flutter on PATH.
cat > "${FLUTTER_ROOT}/bin/flutter" <<EOF
#!/usr/bin/env bash
export FLUTTER_ROOT="${FLUTTER_ROOT}"
exec "${DART_BIN}" \\
  --packages="${FLUTTER_ROOT}/packages/flutter_tools/.dart_tool/package_config.json" \\
  "${FLUTTER_ROOT}/packages/flutter_tools/bin/flutter_tools.dart" \\
  --no-version-check --suppress-analytics "\$@"
EOF
chmod +x "${FLUTTER_ROOT}/bin/flutter"
export PATH="${FLUTTER_ROOT}/bin:${PATH}"
printf 'FLUTTER_ROOT=%s\n' "${FLUTTER_ROOT}" >> "${GITHUB_ENV}"
printf '%s\n' "${FLUTTER_ROOT}/bin" >> "${GITHUB_PATH}"
"${FLUTTER_ROOT}/bin/flutter" precache --linux
"${FLUTTER_ROOT}/bin/flutter" --version
