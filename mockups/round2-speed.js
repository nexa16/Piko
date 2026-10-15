/* Round 2, SPEED-001..013: deterministic, ephemeral learning session; not FSRS. */
(function(root) {
  function create(ids, poolSize = 5) {
    if (!Number.isSafeInteger(poolSize) || poolSize < 1 || !ids.length || new Set(ids).size !== ids.length) throw Error('Invalid Speed selection');
    const pool = ids.slice(0, poolSize);
    return {size: poolSize, waiting: ids.slice(poolSize), pool, pass: {ids: pool.slice(), index: 0}, ordinal: 0,
      items: Object.fromEntries(ids.map(id => [id, {errors: 0, streak: 0, last: null, completed: false}])),
      completed: 0, total: ids.length, gamePending: false};
  }
  function current(round) { return round.pass.ids[round.pass.index] || null; }
  function needsGame(round) { return round.gamePending; }
  function finishGame(round) {
    if (!round.gamePending) return false;
    round.gamePending = false;
    return true;
  }
  function grade(round, correct) {
    if (needsGame(round)) throw Error('Complete the minigame before the next pass');
    const id = current(round); if (!id) throw Error('Round complete');
    const item = round.items[id]; round.ordinal++; item.last = round.ordinal;
    if (correct) item.streak++; else { item.errors++; item.streak = 0; }
    const finished = item.streak >= Math.min(item.errors + 1, 4);
    if (finished) {
      item.completed = true; round.completed++;
      const slot = round.pool.indexOf(id);
      if (round.waiting.length) round.pool[slot] = round.waiting.shift();
      else round.pool.splice(slot, 1);
    }
    // A pass is an immutable membership/order snapshot. A completed slot may be
    // replaced immediately, but the replacement is first asked next rotation.
    round.pass.index++;
    if (round.pass.index === round.pass.ids.length) {
      round.pass = {ids: round.pool.slice(), index: 0};
      round.gamePending = round.size > 1 && round.pool.length > 0 && round.pool.length < round.size && !round.waiting.length;
    }
    return {id, finished, reset: finished && item.errors > 0};
  }
  const api = {create, current, needsGame, finishGame, grade}; root.PikoR2Speed = api;
  if (typeof module !== 'undefined') module.exports = api;
})(globalThis);
