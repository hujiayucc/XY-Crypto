import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  filterAssets,
  isUpdateAvailable,
  latestRelease,
  loadReleases,
  normalizePlatform,
  selectChannel,
} from './releases.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const PUBLIC_DIR = path.join(ROOT, 'public');
const DEFAULT_MANIFEST = process.env.RELEASE_MANIFEST || '';
const REPO = process.env.RELEASE_REPO || '';
const TOKEN = process.env.GITHUB_TOKEN || '';
const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '127.0.0.1';
const CACHE_MS = 60_000;
let releaseCache = null;

const CONTENT_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.png': 'image/png',
};

function securityHeaders(contentType) {
  return {
    'content-type': contentType,
    'cache-control': contentType.startsWith('text/html') ? 'no-cache' : 'public, max-age=300',
    'x-content-type-options': 'nosniff',
    'referrer-policy': 'no-referrer',
    'x-frame-options': 'DENY',
    'permissions-policy': 'camera=(), microphone=(), geolocation=(), payment=()',
    'content-security-policy': "default-src 'self'; base-uri 'none'; frame-ancestors 'none'; object-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; form-action 'none'",
  };
}

function send(res, status, body, contentType = 'application/json; charset=utf-8') {
  res.writeHead(status, securityHeaders(contentType));
  if (res.req?.method === 'HEAD') return res.end();
  res.end(body);
}

function sendJson(res, status, body) {
  send(res, status, JSON.stringify(body), 'application/json; charset=utf-8');
}

function allowedQuery(url, allowed) {
  for (const key of url.searchParams.keys()) {
    if (!allowed.has(key)) return false;
  }
  return true;
}

async function getReleaseData() {
  const now = Date.now();
  if (releaseCache && releaseCache.expiresAt > now) return releaseCache.value;
  const value = await loadReleases({
    manifestPath: DEFAULT_MANIFEST || undefined,
    repo: REPO || undefined,
    token: TOKEN || undefined,
  });
  releaseCache = { expiresAt: now + CACHE_MS, value };
  return value;
}

function publicRelease(release, options = {}) {
  if (!release) return null;
  return {
    version: release.version,
    build: release.build,
    channel: release.channel,
    name: release.name,
    notes: release.notes,
    url: release.url,
    publishedAt: release.publishedAt,
    assets: filterAssets(release, options),
  };
}

async function handleApi(req, res, url) {
  if (url.pathname === '/api/health') {
    return sendJson(res, 200, {
      ok: true,
      service: 'xy-encrypt-server',
      releaseSource: DEFAULT_MANIFEST ? 'manifest' : REPO ? 'github' : 'unconfigured',
    });
  }
  if (url.pathname === '/api/releases') {
    if (!allowedQuery(url, new Set(['channel']))) return sendJson(res, 400, { error: '查询参数无效' });
    const channel = url.searchParams.get('channel') || 'stable';
    if (!['stable', 'preview'].includes(channel)) return sendJson(res, 400, { error: '版本通道无效' });
    const data = await getReleaseData();
    return sendJson(res, 200, {
      channel,
      source: data.source,
      releases: selectChannel(data.releases, channel).map((release) => publicRelease(release)),
    });
  }
  if (url.pathname === '/api/update') {
    const allowed = new Set(['channel', 'version', 'build', 'platform', 'arch']);
    if (!allowedQuery(url, allowed)) return sendJson(res, 400, { error: '查询参数无效' });
    const channel = url.searchParams.get('channel') || 'stable';
    const version = url.searchParams.get('version') || '0.0.0';
    const buildValue = url.searchParams.get('build');
    const build = buildValue == null ? null : Number(buildValue);
    if (!['stable', 'preview'].includes(channel) || (buildValue != null && !Number.isInteger(build))) {
      return sendJson(res, 400, { error: '更新参数无效' });
    }
    const platform = normalizePlatform(url.searchParams.get('platform'));
    const arch = url.searchParams.get('arch') || '';
    const data = await getReleaseData();
    const release = latestRelease(data.releases, channel);
    return sendJson(res, 200, {
      channel,
      current: { version, build },
      available: isUpdateAvailable(version, build, release),
      release: publicRelease(release, { platform, arch }),
    });
  }
  return false;
}

async function staticFile(pathname) {
  const requested = pathname === '/' ? 'index.html' : pathname === '/share' || pathname === '/share/' ? 'share.html' : pathname.replace(/^\//, '');
  if (requested.includes('..') || requested.includes('\\')) return null;
  const filePath = path.join(PUBLIC_DIR, requested);
  if (!filePath.startsWith(`${PUBLIC_DIR}${path.sep}`)) return null;
  try {
    const content = await fs.readFile(filePath);
    return { content, type: CONTENT_TYPES[path.extname(filePath).toLowerCase()] || 'application/octet-stream' };
  } catch {
    return null;
  }
}

export const server = http.createServer(async (req, res) => {
  if (!req.url || req.url.length > 4096) return sendJson(res, 414, { error: '请求地址过长' });
  if (!['GET', 'HEAD'].includes(req.method)) {
    res.setHeader('allow', 'GET, HEAD');
    return sendJson(res, 405, { error: '仅支持 GET 和 HEAD' });
  }
  let url;
  try {
    url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  } catch {
    return sendJson(res, 400, { error: '请求地址无效' });
  }
  try {
    if (url.pathname.startsWith('/api/')) {
      const handled = await handleApi(req, res, url);
      if (handled !== false) return;
    }
    const asset = await staticFile(url.pathname);
    if (!asset) return sendJson(res, 404, { error: '页面不存在' });
    res.writeHead(200, securityHeaders(asset.type));
    if (req.method === 'HEAD') return res.end();
    return res.end(asset.content);
  } catch {
    releaseCache = null;
    return sendJson(res, 502, { error: '版本服务暂时不可用' });
  }
});

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  server.listen(PORT, HOST, () => {
    process.stdout.write(`XY加密 server listening on ${HOST}:${PORT}\n`);
  });
}
