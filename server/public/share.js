const platformNames = { android: 'Android', windows: 'Windows', linux: 'Linux', ios: 'iOS', macos: 'macOS' };
let appLink = '';

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => {
    if (char === '&') return '&amp;';
    if (char === '<') return '&lt;';
    if (char === '>') return '&gt;';
    if (char === '"') return '&#34;';
    return '&#39;';
  });
}

function decodeFragment() {
  const fragment = window.location.hash.slice(1);
  if (!fragment) return null;
  try {
    return decodeURIComponent(fragment);
  } catch {
    return fragment;
  }
}

function parseShare(uriText) {
  if (!uriText || !uriText.startsWith('xyd://')) return null;
  try {
    const uri = new URL(uriText);
    if (uri.protocol !== 'xyd:' || uri.hostname !== 'share') return null;
    const type = uri.searchParams.get('type');
    const text = uri.searchParams.get('text');
    if (!type || !text) return null;
    return { type, text, operation: uri.searchParams.get('op') };
  } catch {
    return null;
  }
}

function setState(data) {
  const status = document.querySelector('#share-status');
  const title = document.querySelector('#share-title');
  const detail = document.querySelector('#share-detail');
  if (!data) {
    status.textContent = '链接内容无效';
    status.style.background = '#f5d9d4';
    status.style.color = '#963e32';
    title.textContent = '没有找到可打开的分享';
    detail.textContent = '请确认你使用的是完整的 XY加密分享链接。';
    document.querySelector('#open-app').setAttribute('disabled', 'disabled');
    return;
  }
  status.textContent = '已准备就绪';
  title.textContent = data.operation === 'encrypt' ? '一段加密分享' : '一段 XY 加密分享';
  detail.textContent = `模式 ${data.type} · 内容保存在链接片段中`;
}

function renderDownloads(release) {
  const target = document.querySelector('#share-download-grid');
  const groups = new Map();
  for (const asset of release?.assets ?? []) {
    if (!groups.has(asset.platform)) groups.set(asset.platform, []);
    groups.get(asset.platform).push(asset);
  }
  if (!groups.size) {
    target.innerHTML = '<div class="empty-card">暂时没有可用安装包，请回到首页查看版本状态。</div>';
    return;
  }
  target.innerHTML = [...groups.entries()].map(([platform, assets]) => `<article class="download-card"><div><h3>${escapeHtml(platformNames[platform] ?? platform)}</h3><small>${escapeHtml(release.version)}</small></div><div class="asset-list">${assets.map((asset) => `<a class="asset-link" href="${escapeHtml(asset.url)}" rel="noreferrer">${escapeHtml(asset.arch)}</a>`).join('')}</div></article>`).join('');
}

function tryOpenApp() {
  if (!appLink) return;
  window.location.href = appLink;
  window.setTimeout(() => {
    const hint = document.querySelector('#share-hint');
    if (hint) hint.textContent = '应用没有响应？请从下方选择你的平台下载安装。';
  }, 1200);
}

async function loadRelease() {
  try {
    const response = await fetch('/api/releases?channel=stable', { headers: { accept: 'application/json' } });
    if (!response.ok) throw new Error('release request failed');
    renderDownloads((await response.json()).releases?.[0]);
  } catch {
    renderDownloads(null);
  }
}

const shareUri = decodeFragment();
const shareData = parseShare(shareUri);
appLink = shareData ? shareUri : '';
setState(shareData);
document.querySelector('#open-app')?.addEventListener('click', tryOpenApp);
loadRelease();
if (shareData) window.setTimeout(tryOpenApp, 500);