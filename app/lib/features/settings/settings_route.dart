import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../shared/copy_scope.dart';
import '../../shared/interface_locale.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';
import 'app_language_controller.dart';
import 'preferred_direction_controller.dart';
import 'preferred_direction_control.dart';
import '../../data/settings_repository.dart';
import 'question_examples_control.dart';

class SettingsRoute extends StatelessWidget {
  const SettingsRoute({
    required this.binding,
    this.directionBinding,
    this.settingsRepository,
    this.registerPending,
    super.key,
  });
  final ValueListenable<AppLanguageController?> binding;
  final ValueListenable<PreferredDirectionController?>? directionBinding;
  final SettingsRepository? settingsRepository;
  final ValueChanged<Future<void>>? registerPending;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<AppLanguageController?>(
        valueListenable: binding,
        builder: (context, controller, _) {
          if (controller == null) return const SizedBox.shrink();
          return _bound(context, controller);
        },
      );

  Widget _bound(BuildContext context, AppLanguageController controller) =>
      AnimatedBuilder(
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
                    leading: PikoButton(
                      label: copy.text('common.back'),
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
                  if (!controller.ready)
                    Text(
                      copy.text(
                        controller.error == null
                            ? 'settings.loading'
                            : 'settings.loadFailed',
                      ),
                    ),
                  if (controller.ready)
                    PikoCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: pikoDesign.dimension(
                            'components.settings.fieldMarginY',
                          ),
                        ),
                        child: PikoDropdown<Locale>(
                          label: copy.text('settings.language'),
                          value: controller.locale.value,
                          items: [
                            for (final locale
                                in InterfaceLocaleController.supportedLocales)
                              DropdownMenuItem(
                                value: locale,
                                child: Text(
                                  copy.text(
                                    locale.languageCode == 'de'
                                        ? 'settings.languageGerman'
                                        : 'settings.languageEnglish',
                                  ),
                                ),
                              ),
                          ],
                          onChanged: controller.canSelect
                              ? (selected) {
                                  if (selected != null && current()) {
                                    controller.select(selected);
                                  }
                                }
                              : null,
                        ),
                      ),
                    ),
                  if (controller.ready && controller.pending)
                    Text(copy.text('settings.saving')),
                  if (controller.error != null) ...[
                    if (controller.ready)
                      Text(copy.text('settings.saveFailed')),
                    PikoButton(
                      label: copy.text('action.retry'),
                      onPressed: () {
                        if (context.mounted &&
                            ModalRoute.of(context)?.isCurrent == true &&
                            identical(binding.value, controller) &&
                            !controller.pending) {
                          controller.retry();
                        }
                      },
                    ),
                  ],
                  if (directionBinding case final binding?)
                    PreferredDirectionControl(binding: binding),
                  if (settingsRepository case final repository?)
                    QuestionExamplesControl(
                      repository: repository,
                      registerPending: registerPending ?? (_) {},
                    ),
                ],
              ),
            ),
          );
        },
      );
}
