/// Reflows a metric without isolating the final label word. Callers retain the
/// original localized wording in their complete accessibility description.
String keepMetricTailTogether(String label) {
  final lastSpace = label.lastIndexOf(' ');
  return lastSpace < 0
      ? label
      : label.replaceRange(lastSpace, lastSpace + 1, '\u00a0');
}
