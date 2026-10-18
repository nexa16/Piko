import 'dart:math';

import 'package:flutter/material.dart';

import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/piko_theme.dart';
import 'speed_learning_session.dart';
import 'speed_numbers_game.dart';

/// Untimed ordering break using the exact game/identity owned by the live round.
class SpeedNumbersBreak extends StatelessWidget {
  const SpeedNumbersBreak({required this.session, super.key});

  final SpeedLearningSession session;

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final game = session.state?.numberGame;
        final handle = session.currentBreak;
        final expected = game?.nextNumber;
        return PikoCard(
          key: const ValueKey('speed-numbers-break'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                headingLevel: 2,
                child: Text(
                  copy.text('r2.game'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SizedBox(height: d.dimension('spacing.3')),
              Text(
                copy.text(
                  game?.kind == SpeedBreakKind.letters
                      ? 'r2.letterGameHint'
                      : 'r2.gameHint',
                ),
              ),
              if (expected != null) ...[
                SizedBox(height: d.dimension('spacing.3')),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    copy.text('r2.gameNext', {'number': game!.label(expected)}),
                    key: const ValueKey('speed-number-next'),
                  ),
                ),
              ],
              if (game != null && handle != null) ...[
                SizedBox(height: d.dimension('spacing.3')),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final gap = d.dimension('spacing.2');
                    final padding = d.dimension('spacing.1');
                    final metrics = TextPainter(
                      text: TextSpan(
                        text: '10',
                        style: DefaultTextStyle.of(context).style.copyWith(
                          fontSize: d.dimension('typography.label'),
                          fontWeight: d.weight('components.buttons.weight'),
                        ),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final minimumWidth = max(
                      d.dimension('controls.largeHeight'),
                      metrics.width + padding * 2,
                    );
                    metrics.dispose();
                    final maximumColumns = d
                        .dimension('components.speedGame.columns')
                        .round();
                    final columns =
                        ((constraints.maxWidth + gap) / (minimumWidth + gap))
                            .floor()
                            .clamp(1, maximumColumns)
                            .toInt();
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final number in game.positions)
                          SizedBox(
                            width: width,
                            child: PikoButton(
                              key: ValueKey(
                                game.kind == SpeedBreakKind.letters
                                    ? 'speed-letter-${game.label(number)}'
                                    : 'speed-number-$number',
                              ),
                              label: game.label(number),
                              padding: EdgeInsets.all(padding),
                              minimumSize: Size(
                                minimumWidth,
                                d.dimension('controls.largeHeight'),
                              ),
                              onPressed:
                                  expected != null &&
                                      number >= expected &&
                                      !session.isSubmitting
                                  ? () => session.tapNumber(handle, number)
                                  : null,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
