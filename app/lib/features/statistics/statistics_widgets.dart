import 'package:flutter/material.dart';
import '../../data/statistics_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_heading_action.dart';
import '../../ui/piko_theme.dart';
import 'statistics_binding.dart';
import 'statistics_action.dart';

class StatisticsStatus extends StatelessWidget {
  const StatisticsStatus({super.key, required this.binding});
  final StatisticsBinding binding;
  @override
  Widget build(BuildContext context) {
    if (binding.ready) return const SizedBox.shrink();
    final copy = PikoCopyScope.of(context);
    final stale = binding.snapshot != null;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: pikoDesign.dimension('spacing.3'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              copy.text(
                binding.error != null
                    ? (stale ? 'statistics.stale' : 'statistics.error')
                    : (stale ? 'statistics.refreshing' : 'statistics.loading'),
              ),
            ),
            if (binding.error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: PikoButton(
                  label: copy.text('action.retry'),
                  onPressed: binding.refresh,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StatisticsSectionHeading extends StatelessWidget {
  const StatisticsSectionHeading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    headingLevel: 2,
    child: Text(
      text,
      style: TextStyle(
        fontSize: pikoDesign.dimension('components.sectionHeading.size'),
        fontWeight: pikoDesign.weight('components.sectionHeading.weight'),
        color: pikoDesign.color('ink'),
      ),
    ),
  );
}

class StatisticsSurface extends StatelessWidget {
  const StatisticsSurface({
    super.key,
    required this.child,
    this.color = 'surface',
    this.outlined = false,
  });
  final Widget child;
  final String color;
  final bool outlined;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(
      pikoDesign.dimension('components.statistics.padding'),
    ),
    decoration: BoxDecoration(
      color: pikoDesign.color(color),
      borderRadius: BorderRadius.circular(pikoDesign.dimension('radii.card')),
      border: outlined ? Border.all(color: pikoDesign.color('ink')) : null,
    ),
    child: child,
  );
}

class StatisticsSummary extends StatelessWidget {
  const StatisticsSummary({
    super.key,
    required this.snapshot,
    this.onOpen,
    this.home = false,
    this.current = true,
  });
  final StatisticsSnapshot snapshot;
  final VoidCallback? onOpen;
  final bool home, current;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final count = snapshot.day(snapshot.today).counts?.regular;
    final gap = pikoDesign.dimension('components.statistics.gap');
    final numbers = PikoHeadingAction(
      gap: gap,
      stackedActionAtStart: true,
      heading: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.text('statistics.today')),
          Text(
            count == null
                ? '—'
                : MaterialLocalizations.of(context).formatDecimal(count),
            key: const ValueKey('statistics-today'),
            semanticsLabel: count == null
                ? copy.text('statistics.unavailable')
                : null,
            style: TextStyle(
              fontSize: pikoDesign.dimension('components.statistics.todaySize'),
              height: pikoDesign.dimension(
                'components.statistics.todayLineHeight',
              ),
              fontWeight: pikoDesign.weight('typography.titleWeight'),
            ),
          ),
          Text(
            copy.text('statistics.reviews'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      action: Wrap(
        spacing: gap,
        runSpacing: gap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (current && (count ?? 0) >= snapshot.streakMinimumReviews)
            Image.asset(
              'assets/brand/piko-star.png',
              key: const ValueKey('statistics-star'),
              width: pikoDesign.dimension('components.statistics.mascotSize'),
              height: pikoDesign.dimension('components.statistics.mascotSize'),
              filterQuality: FilterQuality.none,
              excludeFromSemantics: true,
            ),
          Container(
            padding: EdgeInsets.all(gap),
            decoration: BoxDecoration(
              color: pikoDesign.color('gold'),
              borderRadius: BorderRadius.circular(
                pikoDesign.dimension('radii.card'),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.text(
                    snapshot.streak == 1 ? 'statistics.day' : 'statistics.days',
                    {
                      'count': MaterialLocalizations.of(
                        context,
                      ).formatDecimal(snapshot.streak),
                    },
                  ),
                  key: const ValueKey('statistics-streak'),
                  style: TextStyle(
                    fontSize: pikoDesign.dimension(
                      'components.statistics.badgeSize',
                    ),
                    fontWeight: pikoDesign.weight('typography.titleWeight'),
                  ),
                ),
                Text(
                  copy.text('statistics.streak'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: numbers),
        if (home) ...[
          SizedBox(width: gap),
          const PikoIcon(PikoIconName.chevronRight),
        ],
      ],
    );
    if (!home) return StatisticsSurface(color: 'tint', child: body);
    return StatisticsAction(
      key: const ValueKey('statistics-open'),
      label: copy.text('statistics.openStats'),
      tint: true,
      onPressed: onOpen,
      child: body,
    );
  }
}

class StatisticsReminder extends StatelessWidget {
  const StatisticsReminder({super.key});
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return StatisticsSurface(
      key: const ValueKey('statistics-reminder'),
      color: 'gold',
      outlined: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PikoIcon(PikoIconName.alertTriangle),
          SizedBox(width: pikoDesign.dimension('spacing.3')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.text('statistics.open'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: pikoDesign.dimension('spacing.2')),
                Text(copy.text('statistics.openBody')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatisticsActivity extends StatelessWidget {
  const StatisticsActivity({
    super.key,
    required this.binding,
    required this.hasCollections,
    required this.onOpen,
  });
  final StatisticsBinding binding;
  final bool hasCollections;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: binding,
    builder: (context, _) {
      final snapshot = binding.snapshot;
      if (!hasCollections && snapshot?.hasRecordedActivity != true) {
        // An error is not proof of an empty history. Keep recovery accessible.
        return binding.ready
            ? const SizedBox.shrink()
            : StatisticsStatus(binding: binding);
      }
      final copy = PikoCopyScope.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatisticsSectionHeading(copy.text('statistics.activity')),
          SizedBox(
            height: pikoDesign.dimension(
              'components.sectionHeading.bottomMargin',
            ),
          ),
          StatisticsStatus(binding: binding),
          if (snapshot != null)
            StatisticsSummary(
              snapshot: snapshot,
              home: true,
              current: binding.ready,
              onOpen: binding.ready ? onOpen : null,
            ),
          if (binding.ready &&
              snapshot!.todayCounts.regular == 0 &&
              snapshot.streak > 0) ...[
            SizedBox(height: pikoDesign.dimension('spacing.4')),
            const StatisticsReminder(),
          ],
          SizedBox(
            height: pikoDesign.dimension('components.homeHeader.sectionGap'),
          ),
        ],
      );
    },
  );
}
