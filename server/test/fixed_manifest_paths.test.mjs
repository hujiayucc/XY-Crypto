import test from 'node:test';
import assert from 'node:assert/strict';
import {
  PREVIEW_MANIFEST_PATH,
  RELEASE_MANIFEST_PATH,
} from '../src/server.mjs';

test('server uses fixed container paths for release manifests', () => {
  assert.equal(RELEASE_MANIFEST_PATH, '/app/release.json');
  assert.equal(PREVIEW_MANIFEST_PATH, '/app/preview.json');
});
