import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { generate, readCatalog, update } from './generate_shared.mjs';

const design = { schemaVersion: 1, nested: { width: 24, extra: 'future token' } };
const copy = { schemaVersion: 1, defaultLocale: 'en', entries: { test: { en: '{count} $ "quote"', de: '{count} $ "Zitat"', note: 'preserved' } } };
test('generation preserves fields and escapes Dart interpolation', () => {
  const result = generate(design, copy);
  assert.equal(result, generate({ nested: design.nested, schemaVersion: 1 }, copy));
  assert.ok(result.includes('future token'));
  assert.ok(result.includes('preserved'));
  assert.ok(result.includes('\\$'));
  assert.ok(result.includes('\\"quote\\"'));
});
test('missing translations, mismatched placeholders and nonfinite numbers fail', () => {
  assert.throws(() => generate(design, { ...copy, entries: { test: { en: 'a' } } }));
  assert.throws(() => generate(design, { ...copy, entries: { test: { en: '{a}', de: '{b}' } } }));
  assert.throws(() => generate({ ...design, invalid: Infinity }, copy));
});
test('check detects stale output without modifying it', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'piko-catalog-'));
  const file = path.join(directory, 'catalog.dart');
  try {
    update(file, 'current', false);
    update(file, 'current', true);
    assert.throws(() => update(file, 'changed', true));
    assert.equal(fs.readFileSync(file, 'utf8'), 'current');
  } finally {
    fs.unlinkSync(file);
    fs.rmdirSync(directory);
  }
});
test('source validation rejects values JSON would silently normalize', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'piko-source-'));
  const file = path.join(directory, 'source.js');
  try {
    for (const expression of ['Infinity', 'NaN', 'undefined', '() => 1']) {
      fs.writeFileSync(file, `globalThis.CATALOG = {nested: {value: ${expression}}};`);
      assert.throws(() => readCatalog(file, 'CATALOG'));
    }
    fs.writeFileSync(file, 'globalThis.CATALOG = {nested: {value: 24}};');
    assert.deepEqual(readCatalog(file, 'CATALOG'), { nested: { value: 24 } });
  } finally {
    fs.unlinkSync(file);
    fs.rmdirSync(directory);
  }
});
