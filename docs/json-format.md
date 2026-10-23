# Current Collection JSON

Collection import and export use `format: "piko-vocabulary"`, `schemaVersion: 5` and exactly one Collection. Import changes vocabulary in an existing destination; it does not create a Collection, replace its languages or restore imported learning. Export, the in-app template and import share this current contract. Older versions are rejected with a version error.

Collection export includes its saved A1–C2 `level` as informational metadata. Import preserves the destination Collection's level. Deleted vocabulary in Trash and its recovery snapshots are excluded from both Collection export and the full export report; export is not a backup of Trash.

## Language fields

Each Collection's `targetLanguage` and `nativeLanguage` is an object:

```json
{"kind":"catalog","id":"pt-BR"}
```

Use an exact catalog ID selected in the app, including `pt`, `pt-BR`, `pt-PT`, `es-ES`, `es-MX`, `arz`, `arabic-levantine`, `zh`, `zh-Hans` or `zh-Hant`. These choices remain distinct. `zh` means generic Mandarin; the script options label written forms without converting or validating text. The full stable directory is [shared/languages.js](../shared/languages.js).

```json
{"kind":"custom","id":"custom:6d9df1e6-dc36-426b-a604-d980bfac058f","name":"  Unser Dialekt!  "}
```

Custom IDs are UUIDs prefixed with `custom:`. Keep the exact saved name. Across installations, two custom names match after NFC/lowercase and removal of characters other than Unicode letters and numbers. This comparison never rewrites the destination label or reclassifies it as a catalog language. Catalog names resolve only during initial custom-name selection, against labels in the active interface language. There is no automatic translation, abbreviation expansion or fuzzy matching.

## Manual conversion of older files

Work on a copy and retain the original export. These are field edits for a current importer, not an automatic converter:

1. For versions 1–4, set `schemaVersion` to `5` and replace both string language codes with explicit catalog objects. For example, `"targetLanguage":"fr"` becomes `"targetLanguage":{"kind":"catalog","id":"fr"}` and `"nativeLanguage":"de"` becomes `"nativeLanguage":{"kind":"catalog","id":"de"}`. Select the matching destination languages in the app first. Do not replace an unknown code with a guessed catalog identity.
2. A version-2 scalar `"example":{"targetText":"Une pomme.","nativeText":"Ein Apfel."}` becomes `"examples":[{"targetText":"Une pomme.","nativeText":"Ein Apfel."}]`. Null becomes `"examples":null`. Versions 3–4 already use ordered `examples` arrays. An omitted optional field remains omitted.
3. Keep vocabulary/category UUIDs for updates to the same owner. For a copy whose entry UUIDs already belong to another local Collection, remove those vocabulary IDs to request fresh identities; never change ownership implicitly.
4. Keep `hint` objects (`text`, optional `visibility` as `always`/`hidden`) and boolean `active` when supplied. An omitted field or unselected content group preserves existing content. Selected null/empty examples clears examples; selected null Hint clears Hint. New words need both texts and receive fresh learning. Exported `addedAt` and learning/history remain informational on import.
5. Check the complete result for duplicate target/native/Hint tuples, then review the in-app analysis and selected groups before confirming. A different example or visibility does not distinguish a duplicate; separate meanings need different Hints. Validation failure writes nothing.

## Full export

The separate `piko.full-export` report keeps envelope `schemaVersion: 1` and now declares `collectionSchemaVersion: 5`. Every Collection uses the same payload as single-Collection export. Statistics stays separate. This envelope is rejected by Collection import and provides no full-app restore.
