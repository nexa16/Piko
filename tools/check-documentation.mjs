import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const digest = b => crypto.createHash('sha256').update(b).digest('hex');
export function anchors(text) {
  const found = new Set([...text.matchAll(/<a\s+id="([^"]+)"/g)].map(m => m[1]));
  const counts = new Map();
  for (const m of text.matchAll(/^#{1,6}\s+(.+)$/gm)) {
    const base = m[1].toLowerCase().replace(/[`*_]/g, '').replace(/[^\p{L}\p{N}\s_-]/gu, '').replace(/ /g, '-');
    const n = counts.get(base) ?? 0; counts.set(base, n + 1);
    found.add(base + (n ? `-${n}` : ''));
  }
  return found;
}
export function validate(root, { checkSource = true } = {}) {
  const errors = [], fail = s => errors.push(s);
  const manifestPath = path.join(root, 'docs/build-manifest.json');
  let m;
  try { m = JSON.parse(fs.readFileSync(manifestPath)); } catch (e) { return [`Manifest: ${e.message}`]; }
  if (m.schemaVersion !== 1 || !m.build) return ['Unsupported/incomplete manifest'];
  const b = m.build;
  for (const k of ['id','packageId','versionName','versionCode','artifact','apkSha256','mode','signing','sourceCommit','builtOn','timeZone','toolchain'])
    if (b[k] === undefined || b[k] === '') fail(`Missing build.${k}`);
  if (!/^[0-9a-f]{64}$/.test(b.apkSha256 ?? '')) fail('Invalid APK checksum');
  if (!/^[0-9a-f]{40}$/.test(b.sourceCommit ?? '')) fail('Invalid source commit');
  if (b.id !== `sha256:${b.apkSha256}`) fail('Build ID must identify exact APK bytes');
  const homes = Object.values(m.documents ?? {});
  if (homes.length < 6 || new Set(homes).size !== homes.length) fail('Missing or duplicated documentation homes');
  const within = p => { const resolved = path.resolve(root,p); return resolved.startsWith(path.resolve(root)+path.sep); };
  const files = ['README.md','app/README.md',...homes];
  const currentImages = new Map();
  if (!m.screenshots?.length) fail('No ordinary-product screenshots');
  for (const s of m.screenshots ?? []) {
    if (currentImages.has(s.id)) fail(`Duplicate capture ID: ${s.id}`);
    currentImages.set(s.id,s);
    for (const k of ['path','sha256','buildId','classification','state','task','locale','device','pixelSize','logicalSize','textScale','orientation','capturedAt','fixture','alt'])
      if (s[k] === undefined || s[k] === '') fail(`${s.id}: missing ${k}`);
    if (s.buildId !== b.id) fail(`${s.id}: selected-build mismatch`);
    if (s.classification !== 'ordinary-product-emulator') fail(`${s.id}: gallery requires ordinary product captures`);
    if (!within(s.path ?? '') || !s.path?.startsWith('docs/images/')) { fail(`${s.id}: unsafe image path`); continue; }
    try {
      const data = fs.readFileSync(path.join(root,s.path));
      if (digest(data) !== s.sha256) fail(`${s.id}: image checksum mismatch`);
      if (data.toString('hex',0,8) !== '89504e470d0a1a0a') fail(`${s.id}: expected PNG`);
      else if (s.pixelSize?.[0] !== data.readUInt32BE(16) || s.pixelSize?.[1] !== data.readUInt32BE(20)) fail(`${s.id}: image dimensions mismatch`);
    } catch (e) { fail(`${s.id}: ${e.message}`); }
    if (!/^\d{4}-\d\d-\d\dT.*Z$/.test(s.capturedAt ?? '')) fail(`${s.id}: capture time must be UTC`);
    const [taskFile, taskAnchor] = (s.task ?? '').split('#');
    try {
      if (!within(taskFile) || !anchors(fs.readFileSync(path.join(root,taskFile),'utf8')).has(taskAnchor)) fail(`${s.id}: invalid task anchor`);
    } catch { fail(`${s.id}: missing task document`); }
  }
  const linkedImages = new Set();
  for (const file of files) {
    let text;
    try { text = fs.readFileSync(path.join(root,file),'utf8'); } catch { fail(`Missing document: ${file}`); continue; }
    if (/C:\\Users\\|C:\/Users\/|\.local\/(?!`)|file:\/\//i.test(text) && !['AGENTS.md'].includes(file)) fail(`${file}: private/machine-specific reference`);
    const links = [...text.matchAll(/(!?)\[([^\]]*)\]\(([^)\s]+)\)/g)];
    for (const tag of text.matchAll(/<img\b[^>]*>/g)) {
      const src = tag[0].match(/\bsrc="([^"]+)"/)?.[1];
      const alt = tag[0].match(/\balt="([^"]*)"/)?.[1] ?? '';
      if (!src) fail(`${file}: image without source`);
      else links.push([tag[0], '!', alt, src]);
    }
    for (const link of links) {
      const [, image, label, href] = link;
      if (image && !label.trim()) fail(`${file}: empty image alternative text`);
      if (/^https?:/.test(href)) {
        const source = href.match(/^https:\/\/github\.com\/nexa16\/Piko\/blob\/([^/]+)\/(.+)$/);
        if (source && checkSource) {
          if (source[1] !== b.sourceCommit) fail(`${file}: source reference uses a different commit`);
          try { execFileSync('git',['-c',`safe.directory=${root.replaceAll('\\','/')}`,'cat-file','-e',`${source[1]}:${source[2]}`],{cwd:root,stdio:'pipe'}); }
          catch { fail(`${file}: missing selected source ${source[2]}`); }
        }
        continue;
      }
      if (/^[a-z]+:/i.test(href)) { fail(`${file}: unsupported link ${href}`); continue; }
      const [rel, fragment] = href.split('#');
      const target = rel ? path.resolve(root,path.dirname(file),decodeURIComponent(rel)) : path.resolve(root,file);
      if (!within(path.relative(root,target)) || !fs.existsSync(target)) { fail(`${file}: missing/unsafe link ${href}`); continue; }
      if (fragment && target.endsWith('.md') && !anchors(fs.readFileSync(target,'utf8')).has(decodeURIComponent(fragment))) fail(`${file}: missing anchor ${href}`);
      if (image) {
        const repositoryPath=path.relative(root,target).replaceAll('\\','/'); linkedImages.add(repositoryPath);
        if (![...currentImages.values()].some(s=>s.path===repositoryPath)) fail(`${file}: image missing from manifest ${repositoryPath}`);
      }
    }
  }
  for (const s of currentImages.values()) if (!linkedImages.has(s.path)) fail(`Unreferenced screenshot: ${s.id}`);
  return errors;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const errors = validate(path.resolve(here,'..'));
  if (errors.length) { console.error(errors.join('\n')); process.exitCode=1; }
  else console.log('Documentation links, selected-source references, manifest and product images pass.');
}
