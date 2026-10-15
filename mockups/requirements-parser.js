/* Read-only projection of canonical specs; no duplicate requirement registry. */
(function (root) {
  // Legacy bookmarks/metadata remain readable; canonical metadata uses Round: 1/2.
  function normalizeRound(value) {
    return ({First:'1', Second:'2'}[value] || value);
  }
  function parse(text, source = 'Functional', path = '') {
    const rows = []; let current = null, context = '', fence = false;
    for (const [index, line] of text.split(/\r?\n/).entries()) {
      if (/^\s*```/.test(line)) fence = !fence;
      if (!fence && /^#{1,6}\s/.test(line)) { context = line; current = null; continue; }
      const match = !fence && line.match(/^- \*\*([A-Z0-9]+(?:-[A-Z0-9]+)*-\d{3})(.*?)\*\*(.*)$/);
      if (match) {
        const metadata = match[2] + match[3];
        const tag = name => metadata.match(new RegExp('\\[' + name + ':\\s*([^\\]]+)\\]', 'i'))?.[1]?.trim();
        const explicit = metadata.match(/\[(Confirmed[^\]]*|Proposed|Open|Partly resolved|Partly superseded|Resolved[^\]]*|Superseded|Implementation detail)\]/i)?.[1];
        current = {
          id: match[1], source, path, line: index + 1,
          status: explicit || (match[1].startsWith('OPEN-') ? 'Open' : /confirmed/i.test(context) ? 'Confirmed' : 'Not specified'),
          round: normalizeRound(tag('Round') || tag('Release') || 'Undecided'),
          updated: normalizeRound(tag('Updated')), fix: normalizeRound(tag('Fix')),
          revision: Number(tag('Revision') || 1), implementation: tag('Implementation'),
          scope: tag('Scope') || 'Unclassified', flows: (tag('Flow') || '').split(',').map(x => x.trim()).filter(Boolean),
          body: match[3].replace(/\[(?:Scope|Flow|Round|Release|Updated|Fix|Revision|Implementation):[^\]]*\]/gi, '').replace(/^\s*:\s*/, '').trim()
        };
        rows.push(current);
      } else if (current) current.body += '\n' + line;
    }
    return rows.map(row => ({...row, body: row.body.trim()}));
  }
  function matchesRound(row, round) {
    return round === 'All' || [row.round, row.updated, row.fix].includes(normalizeRound(round));
  }
  const api = {parse, matchesRound, normalizeRound};
  root.PikoRequirements = api;
  if (typeof module !== 'undefined') module.exports = api;
})(globalThis);
