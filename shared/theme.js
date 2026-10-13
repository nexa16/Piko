/* Compatibility adapter; edit design-config.js instead. */
globalThis.PIKO_THEME = Object.fromEntries(['name','primary','tint','bg','ink','muted','surface','onPrimary'].map(key=>[key,globalThis.PIKO_DESIGN.colors[key]]));
