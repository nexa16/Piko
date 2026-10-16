import 'learning_item.dart';

/// Detail presentation preference, independent of both directions' learning.
enum PreferredDirection {
  targetToNative,
  nativeToTarget,
  both;

  static const settingKey = 'preferredDirection';

  /// Creation and migration seed the installation-specific default in storage.
  /// Missing or unsupported values retain the existing-installation fallback.
  static PreferredDirection fromStored(String? value) => switch (value) {
    'targetToNative' => targetToNative,
    'both' => both,
    _ => nativeToTarget,
  };

  Set<LearningDirection> get directions => switch (this) {
    targetToNative => const {LearningDirection.targetToNative},
    nativeToTarget => const {LearningDirection.nativeToTarget},
    both => const {
      LearningDirection.targetToNative,
      LearningDirection.nativeToTarget,
    },
  };
}
