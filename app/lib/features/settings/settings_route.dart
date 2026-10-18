import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../shared/copy_scope.dart';
import '../../shared/interface_locale.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/components/piko_preference_picker.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';
import 'app_language_controller.dart';
import 'preferred_direction_controller.dart';
import 'preferred_direction_control.dart';
import '../../data/settings_repository.dart';
import 'question_examples_control.dart';
import '../../data/full_export.dart';
import '../../platform/vocabulary_json_platform.dart';
import '../interchange/full_export_control.dart';

class SettingsRoute extends StatelessWidget {
  const SettingsRoute({
    required this.binding,
    this.directionBinding,
    this.settingsRepository,
    this.registerPending,
    this.fullExportService,
    this.fullExportPlatform,
    this.collectionsBuilder,
    super.key,
  });
  final ValueListenable<AppLanguageController?> binding;
  final ValueListenable<PreferredDirectionController?>? directionBinding;
  final SettingsRepository? settingsRepository;
  final ValueChanged<Future<void>>? registerPending;
  final WidgetBuilder? collectionsBuilder;
  final FullExportService? fullExportService;
  final VocabularyJsonPlatform? fullExportPlatform;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<AppLanguageController?>(
        valueListenable: binding,
        builder: (context, controller, _) {
          if (controller == null) return const SizedBox.shrink();
          return _bound(context, controller);
        },
      );

  Widget _bound(
    BuildContext context,
    AppLanguageController controller,
  ) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final copy = PikoCopyScope.of(context);
      bool current() =>
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          identical(binding.value, controller) &&
          controller.canSelect;
      return Scaffold(
        body: PikoPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PikoHeading(
                title: copy.text('nav.settings'),
                leading: PikoIconButton(
                  semanticLabel: copy.text('common.back'),
                  icon: const PikoIcon(PikoIconName.arrowLeft),
                  variant: PikoButtonVariant.ghost,
                  onPressed: () {
                    if (context.mounted &&
                        ModalRoute.of(context)?.isCurrent == true) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
              SizedBox(height: pikoDesign.dimension('spacing.4')),
              PikoFormSection(
                title: copy.text('settingsPreview.generalGroup'),
                children: [
                  if (!controller.ready)
                    PikoFormFieldRow(
                      child: Text(
                        copy.text(
                          controller.error == null
                              ? 'settings.loading'
                              : 'settings.loadFailed',
                        ),
                      ),
                    ),
                  if (controller.ready)
                    PikoPreferencePicker<Locale>(
                      key: const ValueKey('settings-language'),
                      label: copy.text('settings.language'),
                      value: controller.locale.value,
                      choices: [
                        for (final locale
                            in InterfaceLocaleController.supportedLocales)
                          (
                            locale,
                            copy.text(
                              locale.languageCode == 'de'
                                  ? 'settings.languageGerman'
                                  : 'settings.languageEnglish',
                            ),
                          ),
                      ],
                      onChanged: controller.canSelect
                          ? (selected) {
                              if (current()) controller.select(selected);
                            }
                          : null,
                    ),
                  if ((controller.ready && controller.pending) ||
                      controller.error != null)
                    PikoFormFieldRow(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (controller.ready && controller.pending)
                            Text(copy.text('settings.saving')),
                          if (controller.error != null) ...[
                            if (controller.ready)
                              Text(copy.text('settings.saveFailed')),
                            PikoButton(
                              label: copy.text('action.retry'),
                              onPressed: controller.pending
                                  ? null
                                  : () {
                                      if (context.mounted &&
                                          ModalRoute.of(context)?.isCurrent ==
                                              true &&
                                          identical(
                                            binding.value,
                                            controller,
                                          ) &&
                                          !controller.pending) {
                                        controller.retry();
                                      }
                                    },
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              PikoFormSection(
                title: copy.text('settingsPreview.learning'),
                children: [
                  if (directionBinding case final binding?)
                    PreferredDirectionControl(binding: binding),
                  if (settingsRepository case final repository?)
                    QuestionExamplesControl(
                      repository: repository,
                      registerPending: registerPending ?? (_) {},
                    ),
                ],
              ),
              if (fullExportService case final service?)
                PikoFormSection(
                  title: copy.text('settingsPreview.data'),
                  children: [
                    FullExportControl(
                      service: service,
                      platform:
                          fullExportPlatform ??
                          const SystemVocabularyJsonPlatform.fullExport(),
                      registerPending: registerPending ?? (_) {},
                    ),
                  ],
                ),
              if (collectionsBuilder != null)
                PikoFormSection(
                  title: copy.text('settingsPreview.areas'),
                  children: [
                    PikoNavigationRow(
                      title: copy.text('settingsPreview.collections'),
                      subtitle: copy.text('settingsPreview.collectionSummary'),
                      onTap: () {
                        if (context.mounted &&
                            ModalRoute.of(context)?.isCurrent == true) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: collectionsBuilder!,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}
