import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { server } from '../src/server.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
let base;

before(async () => {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => new Promise((resolve) => server.close(resolve)));

for (const [name, title] of [
  ['privacy_policy_zh.html', '隐私政策'],
  ['user_agreement_zh.html', '用户协议'],
]) {
  test(`serves ${name} without adding navigation links`, async () => {
    const url = `${base}/legal/${name}`;
    const expected = await readFile(path.join(root, 'server/public/legal', name), 'utf8');
    const response = await fetch(url);
    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type'), /^text\/html; charset=utf-8$/);
    assert.equal(await response.text(), expected);
    assert.match(expected, new RegExp(title));
    const head = await fetch(url, { method: 'HEAD' });
    assert.equal(head.status, 200);
    assert.equal(await head.text(), '');
    const homepage = await (await fetch(base)).text();
    assert.doesNotMatch(homepage, /\/legal\//);
  });
}
