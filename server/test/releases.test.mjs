import test from 'node:test';
import assert from 'node:assert/strict';
import {
  compareVersions,
  filterAssets,
  isUpdateAvailable,
  latestRelease,
  normalizeRelease,
  parseAssetName,
} from '../src/releases.mjs';

test('keeps the published platform and architecture names', () => {
  assert.deepEqual(parseAssetName('XY加密-Android-arm64-v8a.apk'), {
    name: 'XY加密-Android-arm64-v8a.apk',
    platform: 'android',
    arch: 'arm64-v8a',
    extension: 'apk',
  });
  assert.equal(parseAssetName('XY加密-Linux-arm64.pkg.tar.zst').platform, 'linux');
  assert.equal(parseAssetName('debug.apk'), null);
  const labelled = normalizeRelease({
    tag_name: 'v1.3.1',
    assets: [{ label: 'XY加密-Android-arm64-v8a.apk', name: 'XY.-Android-arm64-v8a.apk', browser_download_url: 'https://example.test/app.apk', state: 'uploaded' }],
  });
  assert.equal(labelled.assets[0].name, 'XY加密-Android-arm64-v8a.apk');
});

test('sorts stable and preview semver correctly', () => {
  assert.equal(compareVersions('1.4.0-preview.1', '1.4.0'), -1);
  assert.equal(compareVersions('1.4.1', '1.4.0-preview.9'), 1);
  const releases = [
    normalizeRelease({ tag_name: 'v1.3.1', assets: [] }),
    normalizeRelease({ tag_name: 'v1.4.0-preview.1', prerelease: true, assets: [] }),
    normalizeRelease({ tag_name: 'v1.4.0', assets: [] }),
  ];
  assert.equal(latestRelease(releases, 'stable').version, '1.4.0');
  assert.equal(latestRelease(releases, 'preview').version, '1.4.0-preview.1');
});

test('filters assets without inventing download URLs', () => {
  const release = normalizeRelease({
    tag_name: 'v1.4.0',
    assets: [
      { name: 'XY加密-Windows-amd64.exe', browser_download_url: 'https://example.test/win.exe', state: 'uploaded' },
      { name: 'XY加密-Linux-arm64.deb', browser_download_url: 'https://example.test/linux.deb', state: 'uploaded' },
      { name: 'notes.txt', browser_download_url: 'https://example.test/notes.txt', state: 'uploaded' },
    ],
  });
  assert.equal(filterAssets(release, { platform: 'windows', arch: 'amd64' }).length, 1);
  assert.equal(filterAssets(release, { platform: 'linux', arch: 'arm64' })[0].url, 'https://example.test/linux.deb');
});

test('detects version and build updates', () => {
  const release = normalizeRelease({ tag_name: 'v1.4.0', build: 190, assets: [] });
  assert.equal(isUpdateAvailable('1.3.1', 180, release), true);
  assert.equal(isUpdateAvailable('1.4.0', 190, release), false);
  assert.equal(isUpdateAvailable('1.4.0', 180, release), true);
});
