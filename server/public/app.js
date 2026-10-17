const platformNames = { android: 'Android', windows: 'Windows', linux: 'Linux' };
let activeChannel = 'stable';

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => {
    if (char === '&') return '&amp;';
    if (char === '<') return '&lt;';
    if (char === '>') return '&gt;';
    if (char === '"') return '&#34;';
    return '&#39;';
  });
}

function groupAssets(assets) {
  const groups = new Map();
  for (const asset of assets ?? []) {
    if (!groups.has(asset.platform)) groups.set(asset.platform, []);
    groups.get(asset.platform).push(asset);
  }
  return groups;
}

function renderDownloads(release, target) {
  const element = document.querySelector(target);
  if (!element) return;
  const groups = groupAssets(release?.assets);
  if (!release || groups.size === 0) {
    element.innerHTML = '<div class="empty-card">当前通道暂无可用安装包，请稍后再试。</div>';
    return;
  }
  element.innerHTML = [...groups.entries()].map(([platform, assets]) => `<article class="download-card"><div><h3>${escapeHtml(platformNames[platform] ?? platform)}</h3><small>${escapeHtml(release.version)} · ${release.channel === 'preview' ? 'Preview' : '稳定版'}</small></div><div class="asset-list">${assets.map((asset) => `<a class="asset-link" href="${escapeHtml(asset.url)}" rel="noreferrer" title="${escapeHtml(asset.name)}">${escapeHtml(asset.name)}</a>`).join('')}</div></article>`).join('');
}

async function fetchLatest(channel) {
  const response = await fetch(`/api/releases?channel=${encodeURIComponent(channel)}`, { headers: { accept: 'application/json' } });
  if (!response.ok) throw new Error('release request failed');
  const data = await response.json();
  return data.releases?.[0] ?? null;
}

async function loadDownloads(channel = activeChannel) {
  const status = document.querySelector('#release-status');
  if (status) status.textContent = channel === 'preview' ? '正在读取 Preview 版本…' : '正在读取稳定版本…';
  try {
    const release = await fetchLatest(channel);
    renderDownloads(release, '#download-grid');
    if (status) status.textContent = release ? `${release.name} · ${release.assets.length} 个可用安装包` : '当前通道暂无发布版本';
  } catch {
    renderDownloads(null, '#download-grid');
    if (status) status.textContent = '版本服务暂时不可用，请稍后刷新重试。';
  }
}

// Version detection is intentionally client-only through /api/update.

document.querySelectorAll('.channel-button').forEach((button) => button.addEventListener('click', () => {
  document.querySelectorAll('.channel-button').forEach((item) => item.classList.remove('active'));
  button.classList.add('active');
  activeChannel = button.dataset.channel;
  loadDownloads(activeChannel);
}));
document.querySelector('#update-form')?.addEventListener('submit', checkUpdate);
loadDownloads();