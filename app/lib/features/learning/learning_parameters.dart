/// Versioned reference for the accepted learning defaults. These constants are
/// not user/developer overrides; changing behavior requires a new contract.
abstract final class LearningParameters {
  static const version = 1;
  static const desiredRetention = 0.9;
  static const retryGaps = [20, 10, 5, 3, 1];
  static const retryWaitSeconds = 10;
  static const learningDayBoundaryHour = 4;
  static const skipOtherQuestions = 5;
  static const speedPoolSize = 5;
  static const speedMaxCorrectStreak = 4;
  static const registry =
      <
        String,
        ({
          Object value,
          String unit,
          String allowed,
          String scope,
          String effect,
        })
      >{
        'fsrs.desiredRetention': (
          value: desiredRetention,
          unit: 'probability',
          allowed: '0.9 (fixed)',
          scope: 'Long-term',
          effect:
              'Pinned FSRS desired retention; no fuzz or library learning/relearning steps.',
        ),
        'retry.gaps': (
          value: retryGaps,
          unit: 'accepted other answers',
          allowed: '20/10/5/3/1 by error count (fixed)',
          scope: 'Collection and direction',
          effect: 'Eligibility after each error; fifth and later errors use 1.',
        ),
        'retry.waitSeconds': (
          value: retryWaitSeconds,
          unit: 'seconds',
          allowed: '10 (fixed)',
          scope: 'Captured retry round',
          effect: 'Insufficient-pool fallback; original expiry remains.',
        ),
        'retry.dayBoundaryHour': (
          value: learningDayBoundaryHour,
          unit: 'local hour',
          allowed: '4 (fixed)',
          scope: 'Device learning day',
          effect: 'Unfinished retry expiry; civil calendar boundary.',
        ),
        'review.skipOtherQuestions': (
          value: skipOtherQuestions,
          unit: 'other presentations',
          allowed: '5 (fixed)',
          scope: 'Long-term launch',
          effect:
              'Skip defers behind five available other questions or to the end.',
        ),
        'speed.poolSize': (
          value: speedPoolSize,
          unit: 'vocabulary items',
          allowed: 'integer 1..9007199254740991 per launch',
          scope: 'Speed launch',
          effect: 'Default active pool size; explicit setup may override.',
        ),
        'speed.maxCorrectStreak': (
          value: speedMaxCorrectStreak,
          unit: 'consecutive correct answers',
          allowed: '4 (fixed)',
          scope: 'Speed item',
          effect: 'Required streak is errors plus one, capped at four.',
        ),
      };
}
