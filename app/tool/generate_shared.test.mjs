import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import { generate, readCatalog, update, updateIcons } from './generate_shared.mjs';

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

test('generated icon copies preserve bytes and reject missing, changed or extra output', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'piko-icons-'));
  const source = path.join(directory, 'source');
  const destination = path.join(directory, 'generated');
  fs.mkdirSync(source);
  fs.writeFileSync(path.join(source, 'x.svg'), '<svg stroke-width="2">\r\n</svg>\n');
  fs.writeFileSync(path.join(source, 'LICENSE.txt'), 'ISC\r\nMIT\n');
  try {
    assert.throws(() => updateIcons(source, destination, true));
    updateIcons(source, destination, false);
    updateIcons(source, destination, true);
    for (const name of ['x.svg', 'LICENSE.txt']) {
      assert.deepEqual(fs.readFileSync(path.join(source, name)), fs.readFileSync(path.join(destination, name)));
    }
    fs.writeFileSync(path.join(destination, 'x.svg'), 'changed');
    assert.throws(() => updateIcons(source, destination, true));
    updateIcons(source, destination, false);
    fs.writeFileSync(path.join(destination, 'extra.svg'), 'extra');
    assert.throws(() => updateIcons(source, destination, true));
  } finally {
    for (const folder of [source, destination]) {
      for (const name of fs.readdirSync(folder)) fs.unlinkSync(path.join(folder, name));
      fs.rmdirSync(folder);
    }
    fs.rmdirSync(directory);
  }
});

test('browser heading margin adapts the canonical token', () => {
  const config = readCatalog(new URL('../../shared/design-config.js', import.meta.url), 'PIKO_DESIGN');
  config.components.headings.titleMargin = 11;
  const properties = new Map();
  const context = vm.createContext({
    PIKO_DESIGN: config,
    document: {documentElement: {style: {setProperty: (name, value) => properties.set(name, value)}, dataset: {}}},
  });
  vm.runInContext(fs.readFileSync(new URL('../../shared/design-runtime.js', import.meta.url), 'utf8'), context);
  assert.equal(properties.get('--heading-title-margin'), '11px');
  assert.ok(fs.readFileSync(new URL('../../shared/components.css', import.meta.url), 'utf8').includes('margin:var(--heading-title-margin) 0'));
  assert.ok(!fs.readFileSync(new URL('../../shared/components.css', import.meta.url), 'utf8').includes('margin:7px 0'));
});

test('browser empty description adapts only its canonical line-height token', () => {
  const config = readCatalog(new URL('../../shared/design-config.js', import.meta.url), 'PIKO_DESIGN');
  config.components.emptyState.descriptionLineHeight = 1.9;
  const properties = new Map();
  const context = vm.createContext({PIKO_DESIGN: config,
    document: {documentElement: {style: {setProperty: (name, value) => properties.set(name, value)}, dataset: {}}}});
  vm.runInContext(fs.readFileSync(new URL('../../shared/design-runtime.js', import.meta.url), 'utf8'), context);
  assert.equal(properties.get('--empty-description-line-height'), '1.9');
  assert.ok(fs.readFileSync(new URL('../../shared/components.css', import.meta.url), 'utf8').includes('line-height:var(--empty-description-line-height)'));
  assert.ok(fs.readFileSync(new URL('../../mockups/mockup.js', import.meta.url), 'utf8').includes('class="meta empty-description"'));
});

test('browser cover adapts effective language badge geometry and font tokens', () => {
  const config = readCatalog(new URL('../../shared/design-config.js', import.meta.url), 'PIKO_DESIGN');
  config.components.languageBadge = {size:46,radius:10,fontSize:17,weight:700,letterSpacingEm:0.05};
  const properties = new Map();
  const context = vm.createContext({PIKO_DESIGN: config,
    document: {documentElement: {style: {setProperty: (name, value) => properties.set(name, value)}, dataset: {}}}});
  vm.runInContext(fs.readFileSync(new URL('../../shared/design-runtime.js', import.meta.url), 'utf8'), context);
  for (const [key, value] of [['size','46px'],['radius','10px'],['font-size','17px'],['weight','700'],['letter-spacing','0.05em']]) {
    assert.equal(properties.get('--language-badge-'+key), value);
  }
  const css = fs.readFileSync(new URL('../../shared/components.css', import.meta.url), 'utf8');
  assert.ok(css.includes('width:var(--language-badge-size)'));
  assert.ok(css.includes('font-weight:var(--language-badge-weight)'));
  assert.ok(!css.includes('.cover{height:48px'));
});
