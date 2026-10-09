#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR=${1:?bundle directory is required}
OUTPUT_DIR=${2:?output directory is required}
ARCH=${3:?architecture is required}
VERSION=${APP_VERSION:-1.3.1}
APP_NAME=xy-encrypt-app
PACKAGE_ROOT="${OUTPUT_DIR}/${APP_NAME}-package-root"
RPM_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "${PACKAGE_ROOT}" "${RPM_ROOT}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}" "${PACKAGE_ROOT}/opt/${APP_NAME}" \
  "${PACKAGE_ROOT}/usr/bin" "${PACKAGE_ROOT}/usr/share/applications" \
  "${PACKAGE_ROOT}/usr/share/icons"
cp -a "${BUNDLE_DIR}/." "${PACKAGE_ROOT}/opt/${APP_NAME}/"
ln -s "/opt/${APP_NAME}/xy_encrypt_app" "${PACKAGE_ROOT}/usr/bin/xy_encrypt_app"

if [ -f "${BUNDLE_DIR}/share/applications/com.hujiayucc.decode.desktop" ]; then
  install -Dm644 "${BUNDLE_DIR}/share/applications/com.hujiayucc.decode.desktop" \
    "${PACKAGE_ROOT}/usr/share/applications/com.hujiayucc.decode.desktop"
else
  cat > "${PACKAGE_ROOT}/usr/share/applications/com.hujiayucc.decode.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=XY加密
Comment=文本编码与加解密
Exec=xy_encrypt_app %u
MimeType=x-scheme-handler/xyd;
Icon=com.hujiayucc.decode
Categories=Utility;
Terminal=false
EOF
fi

for size in 16 32 48 64 96 128 192 256; do
  icon="${BUNDLE_DIR}/share/icons/hicolor/${size}x${size}/apps/com.hujiayucc.decode.png"
  if [ -f "${icon}" ]; then
    install -Dm644 "${icon}" \
      "${PACKAGE_ROOT}/usr/share/icons/hicolor/${size}x${size}/apps/com.hujiayucc.decode.png"
  fi
done

# Generic archives contain the runnable Flutter bundle directly.
tar -C "$(dirname "${BUNDLE_DIR}")" -czf \
  "${OUTPUT_DIR}/XY加密-Linux-${ARCH}.tar.gz" "$(basename "${BUNDLE_DIR}")"
tar -C "$(dirname "${BUNDLE_DIR}")" -cJf \
  "${OUTPUT_DIR}/XY加密-Linux-${ARCH}.tar.xz" "$(basename "${BUNDLE_DIR}")"

# Debian-family package.
bash packaging/linux/build-deb.sh "${BUNDLE_DIR}" "${OUTPUT_DIR}" "${ARCH}"

case "${ARCH}" in
  amd64) RPM_ARCH=x86_64; DEB_ARCH=amd64; ARCH_PKG_ARCH=x86_64 ;;
  arm64) RPM_ARCH=aarch64; DEB_ARCH=arm64; ARCH_PKG_ARCH=aarch64 ;;
  *) echo "Unsupported architecture: ${ARCH}" >&2; exit 2 ;;
esac

# RPM-family package. The staged tree avoids compiling native code in rpmbuild.
mkdir -p "${RPM_ROOT}/SOURCES/root" "${RPM_ROOT}/SPECS"
cp -a "${PACKAGE_ROOT}/." "${RPM_ROOT}/SOURCES/root/"
cat > "${RPM_ROOT}/SPECS/${APP_NAME}.spec" <<EOF
Name:           ${APP_NAME}
Version:        ${VERSION}
Release:        1
Summary:        XY加密：文本编码与加解密工具
License:        Proprietary
BuildArch:      ${RPM_ARCH}
Requires:       gtk3
Requires:       glib2
Requires:       libsecret

%description
XY加密支持在本地进行文本编码、加密、解密及分享内容导入。

%prep

%build

%install
mkdir -p %{buildroot}
cp -a %{_sourcedir}/root/. %{buildroot}/

%files
/opt/${APP_NAME}
/usr/bin/xy_encrypt_app
/usr/share/applications/com.hujiayucc.decode.desktop
/usr/share/icons
EOF
rpmbuild --define "_topdir ${RPM_ROOT}" --target "${RPM_ARCH}" \
  -bb "${RPM_ROOT}/SPECS/${APP_NAME}.spec" >/dev/null
cp "${RPM_ROOT}/RPMS/${RPM_ARCH}/"*.rpm "${OUTPUT_DIR}/XY加密-Linux-${ARCH}.rpm"

# Arch-family package. This is a valid pacman package archive with a standard .PKGINFO.
ARCH_ROOT="${OUTPUT_DIR}/${APP_NAME}-arch-root"
rm -rf "${ARCH_ROOT}"
mkdir -p "${ARCH_ROOT}"
cp -a "${PACKAGE_ROOT}/." "${ARCH_ROOT}/"
SIZE_KB=$(du -sk "${ARCH_ROOT}" | awk '{print $1}')
cat > "${ARCH_ROOT}/.PKGINFO" <<EOF
pkgname = ${APP_NAME}
pkgbase = ${APP_NAME}
pkgver = ${VERSION}-1
pkgdesc = XY加密：文本编码与加解密工具
url = https://github.com/hujiayucc/XY-Crypto
builddate = $(date +%s)
packager = XY Crypto CI
size = ${SIZE_KB}000
arch = ${ARCH_PKG_ARCH}
license = custom
depend = gtk3
depend = glib2
depend = libsecret
EOF
tar --zstd -C "${ARCH_ROOT}" -cf \
  "${OUTPUT_DIR}/XY加密-Linux-${ARCH}.pkg.tar.zst" .
rm -rf "${ARCH_ROOT}"

printf '%s\n' "Created Linux packages for ${ARCH}"
