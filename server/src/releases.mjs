import fs from 'node:fs/promises';

const ASSET_RE = /^XY加密-(Android|Windows|Linux|iOS|macOS)-(.+)\.(apk|exe|zip|deb|rpm|pkg\.tar\.zst|tar\.gz|tar\.xz|dmg|ipa)$/i;
const VERSION_RE = /^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$/;

export function parseVersion(value) {
  const match = String(value ?? '').trim().match(VERSION_RE);
  if (!match) return null;
  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
    prerelease: match[4] ?? '',
    value: `${Number(match[1])}.${Number(match[2])}.${Number(match[3])}${match[4] ? `-${match[4]}` : ''}`,
  };
}

export function compareVersions(left, right) {
  const a = parseVersion(left) ?? { major: 0, minor: 0, patch: 0, prerelease: '' };
  const b = parseVersion(right) ?? { major: 0, minor: 0, patch: 0, prerelease: '' };
  for (const key of ['major', 'minor', 'patch']) {
    if (a[key] !== b[key]) return a[key] > b[key] ? 1 : -1;
  }
  if (!a.prerelease && b.prerelease) return 1;
  if (a.prerelease && !b.prerelease) return -1;
  if (a.prerelease === b.prerelease) return 0;
  const aa = a.prerelease.split('.');
  const bb = b.prerelease.split('.');
  for (let index = 0; index < Math.max(aa.length, bb.length); index += 1) {
    if (aa[index] === undefined) return -1;
    if (bb[index] === undefined) return 1;
    if (aa[index] === bb[index]) continue;
    const an = /^\d+$/.test(aa[index]);
    const bn = /^\d+$/.test(bb[index]);
    if (an && bn) return Number(aa[index]) > Number(bb[index]) ? 1 : -1;
    if (an !== bn) return an ? -1 : 1;
    return aa[index] > bb[index] ? 1 : -1;
  }
  return 0;
}

export function parseAssetName(name) {
  const match = String(name ?? '').match(ASSET_RE);
  if (!match) return null;
  return {
    name: match[0],
    platform: normalizePlatform(match[1]),
    arch: match[2].toLowerCase(),
    extension: match[3].toLowerCase(),
  };
}

export function normalizePlatform(value) {
  const normalized = String(value ?? '').toLowerCase().replaceAll('-', '');
  if (normalized === 'android') return 'android';
  if (normalized === 'windows' || normalized === 'win') return 'windows';
  if (normalized === 'linux') return 'linux';
  if (normalized === 'ios') return 'ios';
  if (normalized === 'macos' || normalized === 'mac') return 'macos';
  return normalized;
}

function normalizeAsset(asset) {
  const name = asset?.label ?? asset?.name;
  const parsed = parseAssetName(name);
  if (!parsed || (asset?.state && asset.state !== 'uploaded')) return null;

  const url = asset.browser_download_url ?? asset.download_url ?? asset.url;
  if (typeof url !== 'string' || !/^https?:\/\//i.test(url)) return null;
  return {
    ...parsed,
    url,
    size: Number.isFinite(asset.size) ? asset.size : null,
  };
}

export function normalizeRelease(release) {
  const version = parseVersion(release.version ?? release.tag_name ?? release.tag);
  if (!version) return null;
  const assets = (release.assets ?? []).map(normalizeAsset).filter(Boolean);
  const prerelease = Boolean(release.prerelease) || Boolean(version.prerelease);
  return {
    version: version.value,
    build: release.build != null && Number.isInteger(Number(release.build)) ? Number(release.build) : null,

    prerelease,
    channel: prerelease ? 'preview' : 'stable',
    name: String(release.name ?? `XY加密 ${version.value}`),
    notes: String(release.body ?? release.notes ?? ''),
    url: typeof release.html_url === 'string' ? release.html_url : null,
    publishedAt: release.published_at ?? release.publishedAt ?? null,
    assets,
  };
}

export function selectChannel(releases, channel = 'stable') {
  const wanted = channel === 'preview' ? 'preview' : 'stable';
  return releases
    .filter((release) => release.channel === wanted)
    .sort((left, right) => compareVersions(right.version, left.version));
}

export function latestRelease(releases, channel = 'stable') {
  return selectChannel(releases, channel)[0] ?? null;
}

export function filterAssets(release, { platform, arch } = {}) {
  if (!release) return [];
  const wantedPlatform = normalizePlatform(platform);
  const wantedArch = String(arch ?? '').toLowerCase();
  return release.assets.filter((asset) => {
    if (wantedPlatform && asset.platform !== wantedPlatform) return false;
    if (!wantedArch) return true;
    return asset.arch === wantedArch || asset.arch === 'all' || asset.arch === 'universal';
  });
}

export function isUpdateAvailable(currentVersion, currentBuild, release) {
  if (!release) return false;
  const versionResult = compareVersions(release.version, currentVersion);
  if (versionResult > 0) return true;
  if (versionResult < 0) return false;
  if (currentBuild == null || release.build == null) return false;
  return release.build > Number(currentBuild);
}

export async function readManifest(manifestPath, { forcePrerelease = false } = {}) {
  const raw = await fs.readFile(manifestPath, 'utf8');
  const parsed = JSON.parse(raw);
  const entries = Array.isArray(parsed) ? parsed : parsed.releases;
  if (!Array.isArray(entries)) throw new Error('发布清单格式无效');
  return entries
    .map((entry) => normalizeRelease(forcePrerelease ? { ...entry, prerelease: true } : entry))
    .filter(Boolean);
}

async function readGitHubReleases(repo, token, fetchImpl = fetch) {
  const response = await fetchImpl(`https://api.github.com/repos/${repo}/releases?per_page=30`, {
    headers: {
      accept: 'application/vnd.github+json',
      'user-agent': 'xy-encrypt-server',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!response.ok) throw new Error(`GitHub releases responded ${response.status}`);
  const entries = await response.json();
  return entries
    .filter((entry) => !entry.draft)
    .map(normalizeRelease)
    .filter(Boolean);
}

export async function loadReleases({ manifestPath, previewManifestPath, repo, token, fetchImpl } = {}) {
  if (manifestPath || previewManifestPath) {
    const [stable, preview] = await Promise.all([
      manifestPath ? readManifest(manifestPath) : [],
      previewManifestPath ? readManifest(previewManifestPath, { forcePrerelease: true }) : [],
    ]);
    return { releases: [...stable, ...preview], source: 'manifest' };
  }
  if (repo) return { releases: await readGitHubReleases(repo, token, fetchImpl), source: 'github' };
  return { releases: [], source: 'unconfigured' };
}
