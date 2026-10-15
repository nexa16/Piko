/* Round 2, IMPORT-JSON-001/002: sample-data interchange, never production storage. */
(function (root) {
  const directions = ['targetToNative', 'nativeToTarget'];
  const clone = value => JSON.parse(JSON.stringify(value));
  const normalized = value => value.trim().normalize('NFC');
  const key = value => normalized(value).toLowerCase().normalize('NFC');
  const pairKey = entry => JSON.stringify([key(entry.targetText), key(entry.nativeText)]);
  const uuid = value => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  function freshLearning(now = new Date().toISOString()) {
    return Object.fromEntries(directions.map(direction => [direction, {
      id: null, formatVersion: 1, generation: 0, reviewRevision: 0,
      card: {cardId: null, state: 1, step: 0, stability: null, difficulty: null, due: now, lastReview: null},
      reviews: [], retry: null, speedCompleted: false
    }]));
  }
  function envelope(collection) {
    return {format: 'piko-vocabulary', schemaVersion: 1, exportedAt: new Date().toISOString(),
      scheduler: {library: 'fsrs', version: '2.0.1', cardFormatVersion: 1},
      collections: [clone(collection)]};
  }
  function analyze(text, destination, allCollections, groups = ['targetText', 'nativeText', 'categoryAssignments'], newId = () => crypto.randomUUID()) {
    const errors = [], counts = {new: 0, updated: 0, unchanged: 0, errors: 0};
    const fail = (code, row = 0) => { errors.push({code, row}); };
    let document;
    try { if (typeof text !== 'string' || new TextEncoder().encode(text).length > 1000000) throw Error(); document = JSON.parse(text); } catch { fail('r2.jsonInvalid'); }
    if (!document || document.format !== 'piko-vocabulary' || document.schemaVersion !== 1 || !Array.isArray(document.collections) || document.collections.length !== 1) {
      if (!errors.length) fail('r2.jsonInvalid');
      return {errors, counts: {...counts, errors: errors.length}, next: null};
    }
    const incoming = document.collections[0];
    if (incoming?.targetLanguage !== destination.targetLanguage || incoming?.nativeLanguage !== destination.nativeLanguage) fail('json.languages');
    if (!Array.isArray(incoming?.entries)) fail('r2.jsonInvalid');
    if (errors.length) return {errors, counts: {...counts, errors: errors.length}, next: null};
    if (!Array.isArray(groups) || !groups.length || groups.some(g=>!['targetText','nativeText','categoryAssignments'].includes(g))) fail('r2.jsonGroupsRequired');
    if (errors.length) return {errors, counts: {...counts, errors: errors.length}, next: null};
    const next = clone(destination), definitions = incoming.categoryDimensions || [];
    if (!Array.isArray(definitions)) fail('r2.jsonCategory');
    const selected = new Set(groups), entries = new Map(next.entries.map(e => [e.id.toLowerCase(), e]));
    const foreign = new Set(allCollections.filter(c => c.id !== destination.id).flatMap(c => c.entries.map(e => e.id.toLowerCase())));
    const seen = new Set(), definitionIds = new Set();
    const foreignCategoryIds = new Set(allCollections.filter(c => c.id !== destination.id).flatMap(c => c.categoryDimensions.flatMap(d => [d.id, ...d.values.map(v => v.id)])));
    let keptCategoryMetadata = false;
    if (Array.isArray(definitions)) for (const d of definitions) {
      if (!uuid(d?.id) || definitionIds.has(d.id) || typeof d.name !== 'string' || !d.name.trim() || !['single','multiple'].includes(d.mode) || !Array.isArray(d.values)) { fail('r2.jsonCategory'); continue; }
      definitionIds.add(d.id);
      for (const v of d.values) {
        if (!uuid(v?.id) || definitionIds.has(v.id) || typeof v.name !== 'string' || !v.name.trim()) fail('r2.jsonCategory');
        else definitionIds.add(v.id);
      }
    }
    if (errors.length) return {errors, counts: {...counts, errors: errors.length}, next: null};
    function resolveAssignments(assignments, row) {
      if (!Array.isArray(assignments)) { fail('r2.jsonCategory', row); return []; }
      const used = new Set();
      for (const a of assignments) {
        if (!uuid(a?.dimensionId) || used.has(a.dimensionId) || !Array.isArray(a.valueIds) || new Set(a.valueIds).size !== a.valueIds.length) { fail('r2.jsonCategory', row); continue; }
        used.add(a.dimensionId);
        let target = next.categoryDimensions.find(d => d.id === a.dimensionId);
        const source = Array.isArray(definitions) && definitions.find(d => d.id === a.dimensionId);
        if (!target) {
          if (!source || foreignCategoryIds.has(a.dimensionId) || next.categoryDimensions.some(d => d.values.some(v=>v.id===a.dimensionId) || key(d.name) === key(source.name))) { fail('r2.jsonCategory', row); continue; }
          target = {id: source.id, name: normalized(source.name), mode: source.mode, values: []};
          next.categoryDimensions.push(target);
        } else if (source && (source.name !== target.name || source.mode !== target.mode)) keptCategoryMetadata = true;
        if (target.mode === 'single' && a.valueIds.length > 1) fail('r2.jsonCategory', row);
        for (const id of a.valueIds) {
          const value = target.values.find(v => v.id === id), proposed = source?.values?.find(v => v.id === id);
          if (value) { if (proposed && proposed.name !== value.name) keptCategoryMetadata = true; continue; }
          if (!uuid(id) || !proposed || foreignCategoryIds.has(id) || next.categoryDimensions.some(d => d.id === id || d.values.some(v => v.id === id)) || target.values.some(v => key(v.name) === key(proposed.name))) { fail('r2.jsonCategory', row); continue; }
          target.values.push({id, name: normalized(proposed.name)});
        }
      }
      return clone(assignments);
    }
    if (Array.isArray(incoming.entries)) incoming.entries.forEach((record, index) => {
      const row = index + 1;
      if (!record || typeof record !== 'object' || Array.isArray(record)) { fail('r2.jsonInvalid', row); return; }
      const id = record.id === undefined ? newId() : record.id;
      if (!uuid(id) || seen.has(id.toLowerCase()) || foreign.has(id.toLowerCase())) { fail('r2.jsonIdentity', row); return; }
      seen.add(id.toLowerCase());
      const existing = entries.get(id.toLowerCase()), candidate = existing ? clone(existing) : {id, categoryAssignments: [], learning: freshLearning()};
      const before = existing && JSON.stringify([existing.targetText, existing.nativeText, existing.categoryAssignments]);
      for (const field of ['targetText', 'nativeText']) {
        if (!existing || selected.has(field)) {
          if (record[field] !== undefined) {
            if (typeof record[field] !== 'string' || !record[field].trim()) fail('r2.jsonText', row);
            else candidate[field] = normalized(record[field]);
          } else if (!existing) fail('r2.jsonText', row);
        }
      }
      if (selected.has('categoryAssignments') && record.categoryAssignments !== undefined) candidate.categoryAssignments = resolveAssignments(record.categoryAssignments, row);
      if (!candidate.targetText || !candidate.nativeText) return;
      if (existing) {
        const changed = before !== JSON.stringify([candidate.targetText, candidate.nativeText, candidate.categoryAssignments]);
        counts[changed ? 'updated' : 'unchanged']++;
        Object.assign(existing, candidate);
      } else { next.entries.push(candidate); entries.set(id.toLowerCase(), candidate); counts.new++; }
    });
    const pairs = new Set();
    for (const entry of next.entries) { const signature = pairKey(entry); if (pairs.has(signature)) fail('r2.jsonDuplicate'); pairs.add(signature); }
    counts.errors = errors.length;
    return {counts, errors, keptCategoryMetadata, next: errors.length ? null : next};
  }
  const api = {envelope, analyze, freshLearning, pairKey, key, directions};
  root.PikoR2Json = api;
  if (typeof module !== 'undefined') module.exports = api;
})(globalThis);
