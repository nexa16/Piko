import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/statistics_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';
import 'statistics_binding.dart';
import 'statistics_calendar.dart';
import 'statistics_widgets.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.binding});
  final StatisticsBinding binding;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  bool speed = false, calendar = false, help = false;
  DateTime? month;
  @override
  void initState() {
    super.initState();
    // Opening the page refreshes the date even if the runtime was kept alive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.binding.refresh();
    });
  }

  Widget gap([String token = 'spacing.4']) =>
      SizedBox(height: pikoDesign.dimension(token));
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PikoPage(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: pikoDesign.dimension(
              'components.statistics.contentWidth',
            ),
          ),
          child: ListenableBuilder(
            listenable: widget.binding,
            builder: (context, _) {
              final copy = PikoCopyScope.of(context);
              final snapshot = widget.binding.snapshot;
              final ready = widget.binding.ready;
              final currentMonth = snapshot == null
                  ? null
                  : DateTime.utc(snapshot.today.year, snapshot.today.month);
              // A backwards clock change hides future calendar months, while the
              // user's chosen month remains stored for a later valid projection.
              final shownMonth =
                  month == null ||
                      (currentMonth != null && month!.isAfter(currentMonth))
                  ? currentMonth
                  : month;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PikoHeading(
                    title: copy.text('statistics.title'),
                    subtitle: copy.text('statistics.subtitle'),
                    leading: PikoButton(
                      label: copy.text('home.collections'),
                      icon: const PikoIcon(PikoIconName.arrowLeft),
                      variant: PikoButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  gap('spacing.6'),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: pikoDesign.color('tint'),
                      borderRadius: BorderRadius.circular(
                        pikoDesign.dimension('radii.card'),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        pikoDesign.dimension('spacing.1'),
                      ),
                      child: PikoAnchorRegion(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final value in [false, true])
                              Expanded(
                                child: Semantics(
                                  selected: value == speed,
                                  child: PikoButton(
                                    key: ValueKey(
                                      value
                                          ? 'statistics-speed-mode'
                                          : 'statistics-regular-mode',
                                    ),
                                    label: copy.text(
                                      value
                                          ? 'statistics.speed'
                                          : 'statistics.normal',
                                    ),
                                    variant: speed == value
                                        ? PikoButtonVariant.reviewPrimary
                                        : PikoButtonVariant.ghost,
                                    onPressed: () =>
                                        setState(() => speed = value),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  StatisticsStatus(binding: widget.binding),
                  if (snapshot != null) ...[
                    gap(),
                    if (speed)
                      _speed(context, snapshot)
                    else ...[
                      StatisticsSummary(snapshot: snapshot, current: ready),
                      if (ready &&
                          snapshot.todayCounts.regular == 0 &&
                          snapshot.streak > 0) ...[
                        gap(),
                        const StatisticsReminder(),
                      ],
                      gap(),
                      StatisticsSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(copy.text('statistics.average')),
                            Text(
                              snapshot.average == null
                                  ? '—'
                                  : NumberFormat(
                                      '0.#',
                                      copy.locale,
                                    ).format(snapshot.average),
                              key: const ValueKey('statistics-average'),
                              semanticsLabel: snapshot.average == null
                                  ? copy.text('statistics.noAverage')
                                  : null,
                              style: TextStyle(
                                fontSize: pikoDesign.dimension(
                                  'components.statistics.averageSize',
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              copy.text('statistics.window'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (!snapshot.activity.entries.any(
                        (entry) =>
                            entry.key.compareTo(snapshot.today) <= 0 &&
                            entry.value.regular > 0,
                      )) ...[
                        gap(),
                        Text(copy.text('statistics.nothingBody')),
                      ],
                      gap('components.sectionHeading.topMargin'),
                      StatisticsSectionHeading(copy.text('statistics.history')),
                      gap(),
                      if (calendar)
                        StatisticsCalendar(
                          snapshot: snapshot,
                          month: shownMonth!,
                          ready: ready,
                          onMonth: (value) {
                            if (widget.binding.ready) {
                              setState(() => month = value);
                            }
                          },
                        )
                      else
                        StatisticsRecent(snapshot: snapshot),
                      gap(),
                      Text(
                        copy.text('statistics.calendarNote'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      gap(),
                      PikoButton(
                        key: const ValueKey('statistics-calendar-toggle'),
                        label: copy.text(
                          calendar
                              ? 'statistics.recent'
                              : 'statistics.calendar',
                        ),
                        variant: PikoButtonVariant.tint,
                        onPressed: ready
                            ? () => setState(() => calendar = !calendar)
                            : null,
                      ),
                    ],
                    gap('spacing.6'),
                    Text(
                      copy.text('statistics.coverage', {
                        'date': statisticsDate(context, snapshot.startDate),
                      }),
                      key: const ValueKey('statistics-coverage'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  gap(),
                  PikoAnchorRegion(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        expanded: help,
                        child: PikoButton(
                          key: const ValueKey('statistics-help'),
                          label: copy.text('statistics.rules'),
                          variant: PikoButtonVariant.ghost,
                          onPressed: () => setState(() => help = !help),
                        ),
                      ),
                    ),
                  ),
                  if (help) ...[
                    Text(copy.text('statistics.rulesBody')),
                    gap(),
                    Text(copy.text('statistics.coverageHelp')),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _speed(BuildContext context, StatisticsSnapshot snapshot) {
    final copy = PikoCopyScope.of(context);
    final count = snapshot.day(snapshot.today).counts?.speed;
    return StatisticsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatisticsSectionHeading(copy.text('statistics.speedTitle')),
          gap(),
          Text(
            count == null
                ? '—'
                : MaterialLocalizations.of(context).formatDecimal(count),
            key: const ValueKey('statistics-speed-today'),
            semanticsLabel: count == null
                ? copy.text('statistics.unavailable')
                : null,
            style: TextStyle(
              fontSize: pikoDesign.dimension('components.statistics.todaySize'),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(copy.text('statistics.completed')),
          gap(),
          Text(copy.text('statistics.speedBody')),
        ],
      ),
    );
  }
}
