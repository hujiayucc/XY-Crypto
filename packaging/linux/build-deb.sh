#!/usr/bin/env bash
set -eu

BUNDLE_DIR=${1:?bundle directory is required}
OUTPUT_DIR=${2:?output directory is required}
ARCH=${3:?Debian architecture is required}

APP_NAME=xy-encrypt-app
VERSION=1.3.1-1
PACKAGE_ROOT="${OUTPUT_DIR}/${APP_NAME}-${ARCH}-pkg"
DEB_PATH="${OUTPUT_DIR}/XY加密-Linux-${ARCH}.deb"

rm -rf "${PACKAGE_ROOT}" "${DEB_PATH}"
mkdir -p \
  "${PACKAGE_ROOT}/DEBIAN" \
  "${PACKAGE_ROOT}/opt/${APP_NAME}" \
  "${PACKAGE_ROOT}/usr/bin" \
  "${PACKAGE_ROOT}/usr/share/applications"

cp -a "${BUNDLE_DIR}/." "${PACKAGE_ROOT}/opt/${APP_NAME}/"
ln -s "/opt/${APP_NAME}/xy_encrypt_app" "${PACKAGE_ROOT}/usr/bin/xy_encrypt_app"

if [ -f "${BUNDLE_DIR}/share/applications/com.hujiayucc.decode.desktop" ]; then
  install -Dm644 \
    "${BUNDLE_DIR}/share/applications/com.hujiayucc.decode.desktop" \
    "${PACKAGE_ROOT}/usr/share/applications/com.hujiayucc.decode.desktop"
fi

for size in 16 32 48 64 96 128 192 256; do
  icon="${BUNDLE_DIR}/share/icons/hicolor/${size}x${size}/apps/com.hujiayucc.decode.png"
  if [ -f "${icon}" ]; then
    install -Dm644 "${icon}" \
      "${PACKAGE_ROOT}/usr/share/icons/hicolor/${size}x${size}/apps/com.hujiayucc.decode.png"
  fi
done

cat > "${PACKAGE_ROOT}/DEBIAN/control" <<EOF
Package: ${APP_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: XY加密 <hujiayucc@qq.com>
Depends: libgtk-3-0, libglib2.0-0, libsecret-1-0, libstdc++6, liblzma5
Description: XY加密：文本编码与加解密工具
 在本地进行文本编码、加密、解密及分享内容导入。
EOF

# dpkg-deb requires the metadata directory to be traversable by all users.
chmod 755 "${PACKAGE_ROOT}/DEBIAN"
chmod 644 "${PACKAGE_ROOT}/DEBIAN/control"
dpkg-deb --build --root-owner-group "${PACKAGE_ROOT}" "${DEB_PATH}" >/dev/null
rm -rf "${PACKAGE_ROOT}"
printf '%s\n' "Created ${DEB_PATH}"