import 'ai_contract.dart';

/// Operation-local identifiers reduce repeated UUID overhead without changing
/// lexical text, category meaning, or the authoritative local snapshot.
final class AiWire {
  AiWire(AiRequest request) {
    final ids = <String>{
      for (final e in request.snapshot.entries) e.record.id,
      for (final g in request.snapshot.groups) ...[
        g.dimension.id,
        for (final v in g.values) v.id,
      ],
    };
    var n = 0;
    for (final id in ids) {
      final alias = '@${n++}';
      // Avoid ambiguity even for imported identifiers resembling aliases.
      if (ids.contains(alias)) continue;
      _out[id] = alias;
      _in[alias] = id;
    }
    body = _request(request.toJson());
  }
  final _out = <String, String>{}, _in = <String, String>{};
  late final Map<String, Object?> body;
  String _id(Object? id, Map<String, String> map) => map[id] ?? id as String;
  Object? _assignments(Object? raw, Map<String, String> map) {
    if (raw is Map) {
      return {
        for (final e in raw.entries)
          _id(e.key, map): [for (final v in e.value as Iterable) _id(v, map)],
      };
    }
    if (raw is List) {
      return [
        for (final a in raw)
          {
            ...a as Map<String, dynamic>,
            'groupId': _id(a['groupId'], map),
            'valueIds': [
              for (final v in a['valueIds'] as Iterable) _id(v, map),
            ],
          },
      ];
    }
    return raw;
  }

  Map<String, Object?> result(
    Map<String, Object?> raw, {
    bool outgoing = false,
  }) {
    final map = outgoing ? _out : _in;
    return {
      ...raw,
      if (raw['processedIds'] is List)
        'processedIds': [
          for (final id in raw['processedIds'] as List) _id(id, map),
        ],
      for (final key in ['groups', 'values', 'cards', 'edits'])
        if (raw[key] is List)
          key: [
            for (final item in raw[key] as List)
              {
                ...item as Map<String, dynamic>,
                // Saved IDs may be referenced, but proposal identities stay unchanged.
                if (item['groupId'] != null)
                  'groupId': _id(item['groupId'], map),
                if (item['entryId'] != null)
                  'entryId': _id(item['entryId'], map),
                if (item['assignments'] != null)
                  'assignments': _assignments(item['assignments'], map),
                if (item['field'] == 'assignments' && item['value'] != null)
                  'value': _assignments(item['value'], map),
              },
          ],
    };
  }

  Map<String, Object?> _request(Map<String, Object?> raw) {
    final context = raw['context'] as Map<String, Object?>;
    return {
      ...raw,
      'context': {
        ...context,
        'groups': [
          for (final g in context['groups'] as List)
            {
              ...g as Map<String, Object?>,
              'id': _id(g['id'], _out),
              'values': [
                for (final v in g['values'] as List)
                  {...v as Map<String, Object?>, 'id': _id(v['id'], _out)},
              ],
            },
        ],
        'entries': [
          for (final e in context['entries'] as List)
            {
              ...e as Map<String, Object?>,
              'id': _id(e['id'], _out),
              'assignments': _assignments(e['assignments'], _out),
            },
        ],
      },
      if (raw['targets'] is List)
        'targets': [for (final id in raw['targets'] as List) _id(id, _out)],
      if (raw['previous'] is Map)
        'previous': result(
          Map<String, Object?>.from(raw['previous'] as Map),
          outgoing: true,
        ),
      if (raw['followUp'] is Map)
        'followUp': {
          ...raw['followUp'] as Map<String, Object?>,
          if ((raw['followUp'] as Map)['result'] is Map)
            'result': result(
              Map<String, Object?>.from((raw['followUp'] as Map)['result']),
              outgoing: true,
            ),
        },
    };
  }
}
