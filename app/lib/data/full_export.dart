/// A portable report, deliberately separate from Collection import/restore.
abstract interface class FullExportService {
  Future<String> exportAll();
}

abstract final class FullExportFormat {
  static const format = 'piko.full-export';
  static const schemaVersion = 1;
}
