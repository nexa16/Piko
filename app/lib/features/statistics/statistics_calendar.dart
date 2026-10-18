import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/learning_day.dart';
import '../../data/statistics_repository.dart';
import '../../shared/copy_scope.dart';
import 'statistics_action.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../ui/piko_theme.dart';

String statisticsDate(BuildContext context, LearningDate date) =>
    DateFormat.yMMMd(PikoCopyScope.of(context).locale).format(date.civilUtc);

String statisticsDayLabel(BuildContext context, StatisticsDay day) {
  final copy = PikoCopyScope.of(context);
  return copy.text('statistics.dayLabel', {
    'date': DateFormat.yMMMMEEEEd(copy.locale).format(day.date.civilUtc),
    'value': day.counts == null
        ? '—'
        : MaterialLocalizations.of(context).formatDecimal(day.counts!.regular),
    'coverage': copy.text(switch (day.coverage) {
      StatisticsCoverage.partial => 'statistics.partial',
      StatisticsCoverage.unavailable => 'statistics.unavailable',
      StatisticsCoverage.future => 'statistics.future',
      StatisticsCoverage.complete => 'statistics.recorded',
    }),
  });
}

class StatisticsRecent extends StatelessWidget {
  const StatisticsRecent({super.key, required this.snapshot});
  final StatisticsSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final days = [
      for (var ago = 0; ago < 7; ago++)
        if (snapshot.today.civilUtc.difference(DateTime.utc(1)).inDays >= ago)
          snapshot.day(snapshot.today.shifted(-ago)),
    ];
    final largest = days.fold<int>(
      1,
      (max, day) => math.max(max, day.counts?.regular ?? 0),
    );
    return Column(
      children: [
        for (var i = 0; i < days.length; i++)
          Semantics(
            key: ValueKey('statistics-recent-${days[i].date.key}'),
            label: statisticsDayLabel(context, days[i]),
            excludeSemantics: true,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: pikoDesign.dimension('spacing.2'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          i == 0
                              ? copy.text('statistics.today')
                              : i == 1
                              ? copy.text('statistics.yesterday')
                              : statisticsDate(context, days[i].date),
                        ),
                      ),
                      SizedBox(width: pikoDesign.dimension('spacing.3')),
                      Text(
                        '${days[i].counts?.regular ?? '—'}${days[i].coverage == StatisticsCoverage.partial ? '*' : ''}',
                      ),
                    ],
                  ),
                  SizedBox(height: pikoDesign.dimension('spacing.1')),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      pikoDesign.dimension('radii.card'),
                    ),
                    child: LinearProgressIndicator(
                      value: (days[i].counts?.regular ?? 0) / largest,
                      minHeight: pikoDesign.dimension(
                        'components.statistics.barHeight',
                      ),
                      backgroundColor: pikoDesign.color('tint'),
                      color: pikoDesign.color('primary'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class StatisticsCalendar extends StatelessWidget {
  const StatisticsCalendar({
    super.key,
    required this.snapshot,
    required this.month,
    required this.ready,
    required this.onMonth,
  });
  final StatisticsSnapshot snapshot;
  final DateTime month;
  final bool ready;
  final ValueChanged<DateTime> onMonth;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final firstWeekday = DateTime.utc(month.year, month.month).weekday - 1;
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final next = DateTime.utc(month.year, month.month + 1);
    final currentMonth = DateTime.utc(
      snapshot.today.year,
      snapshot.today.month,
    );
    final gap = pikoDesign.dimension('components.statistics.calendarGap');
    final monthLabel = DateFormat.yMMMM(copy.locale).format(month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PikoField(
          label: copy.text('statistics.month'),
          child: StatisticsAction(
            key: const ValueKey('statistics-month-jump'),
            label: monthLabel,
            field: true,
            onPressed: !ready
                ? null
                : () async {
                    final chosen = await showPikoDialog<DateTime>(
                      context,
                      builder: (_) =>
                          _MonthDialog(initial: month, latest: currentMonth),
                    );
                    if (chosen != null && context.mounted) onMonth(chosen);
                  },
          ),
        ),
        SizedBox(height: pikoDesign.dimension('spacing.2')),
        PikoAnchorRegion(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatisticsAction(
                  key: const ValueKey('statistics-previous'),
                  label: copy.text('statistics.previous'),

                  onPressed: ready && (month.year > 1 || month.month > 1)
                      ? () => onMonth(DateTime.utc(month.year, month.month - 1))
                      : null,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: StatisticsAction(
                  key: const ValueKey('statistics-next'),
                  label: copy.text('statistics.next'),

                  onPressed: ready && !next.isAfter(currentMonth)
                      ? () => onMonth(next)
                      : null,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: pikoDesign.dimension('spacing.4'),
          ),
          child: Text(
            monthLabel,
            key: const ValueKey('statistics-month'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        // Intrinsic-height rows keep all seven calendar columns at 200% text.
        Table(
          key: const ValueKey('statistics-calendar'),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Padding(
                    padding: EdgeInsets.all(gap / 2),
                    child: Semantics(
                      label: DateFormat.EEEE(
                        copy.locale,
                      ).format(DateTime.utc(2026, 10, 12 + weekday)),
                      excludeSemantics: true,
                      child: Text(
                        DateFormat.E(
                          copy.locale,
                        ).format(DateTime.utc(2026, 10, 12 + weekday)),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: pikoDesign.dimension(
                            'components.statistics.calendarWeekdaySize',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (var row = 0; row < (firstWeekday + count + 6) ~/ 7; row++)
              TableRow(
                children: [
                  for (var col = 0; col < 7; col++)
                    if (row * 7 + col - firstWeekday + 1 case final day
                        when day >= 1 && day <= count)
                      _CalendarDay(
                        day: snapshot.day(
                          LearningDate(month.year, month.month, day),
                        ),
                        today: snapshot.today,
                      )
                    else
                      const SizedBox.shrink(),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.day, required this.today});
  final StatisticsDay day;
  final LearningDate today;
  @override
  Widget build(BuildContext context) {
    final gap = pikoDesign.dimension('components.statistics.calendarGap');
    return Semantics(
      key: ValueKey('statistics-day-${day.date.key}'),
      label: statisticsDayLabel(context, day),
      excludeSemantics: true,
      child: Container(
        margin: EdgeInsets.all(gap / 2),
        padding: EdgeInsets.symmetric(vertical: gap, horizontal: gap / 2),
        decoration: BoxDecoration(
          color: (day.counts?.regular ?? 0) > 0
              ? pikoDesign.color('tint')
              : null,
          border: day.date == today
              ? Border.all(color: pikoDesign.color('ink'))
              : null,
          borderRadius: BorderRadius.circular(
            pikoDesign.dimension('spacing.2'),
          ),
        ),
        child: Column(
          children: [
            Text(
              '${day.date.day}',
              style: TextStyle(
                fontSize: pikoDesign.dimension(
                  'components.statistics.calendarDaySize',
                ),
              ),
            ),
            Text(
              day.coverage == StatisticsCoverage.future
                  ? ''
                  : '${day.counts?.regular ?? '—'}${day.coverage == StatisticsCoverage.partial ? '*' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: pikoDesign.dimension(
                  'components.statistics.calendarCountSize',
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthDialog extends StatefulWidget {
  const _MonthDialog({required this.initial, required this.latest});
  final DateTime initial, latest;
  @override
  State<_MonthDialog> createState() => _MonthDialogState();
}

class _MonthDialogState extends State<_MonthDialog> {
  late final year = TextEditingController(text: '${widget.initial.year}');
  late int month = widget.initial.month;
  bool invalid = false;
  @override
  void dispose() {
    year.dispose();
    super.dispose();
  }

  void apply() {
    final y = int.tryParse(year.text.trim());
    if (y == null ||
        y < 1 ||
        y > widget.latest.year ||
        DateTime.utc(y, month).isAfter(widget.latest)) {
      setState(() => invalid = true);
      return;
    }
    Navigator.of(context).pop(DateTime.utc(y, month));
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return PikoDialog(
      title: copy.text('statistics.jump'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PikoField(
            label: copy.text('statistics.month'),
            child: DropdownButtonFormField<int>(
              key: const ValueKey('statistics-jump-month'),
              initialValue: month,
              isExpanded: true,
              decoration: pikoInputDecoration(),
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      DateFormat.MMMM(
                        copy.locale,
                      ).format(DateTime.utc(2000, m)),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => month = value);
              },
            ),
          ),
          SizedBox(height: pikoDesign.dimension('spacing.4')),
          PikoTextField(
            key: const ValueKey('statistics-jump-year'),
            label: copy.text('statistics.year'),
            controller: year,
            error: invalid ? copy.text('statistics.invalidMonth') : null,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => apply(),
          ),
        ],
      ),
      actions: [
        PikoDialogAction(
          label: copy.text('action.cancel'),
          role: PikoDialogActionRole.safe,
          onPressed: () => Navigator.pop(context),
        ),
        PikoDialogAction(label: copy.text('r2.apply'), onPressed: apply),
      ],
    );
  }
}
