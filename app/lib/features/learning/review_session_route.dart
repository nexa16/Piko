import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/piko_theme.dart';
import 'due_learning_session.dart';
import 'review_launch.dart';

/// Actual fixed session and initial no-due presentation; card/grading UI follows.
class ReviewSessionRoute extends StatefulWidget {
  const ReviewSessionRoute({
    super.key,
    required this.collection,
    required this.session,
  });
  final CollectionRecord collection;
  final DueLearningSession session;
  @override
  State<ReviewSessionRoute> createState() => _ReviewSessionRouteState();
}

class _ReviewSessionRouteState extends State<ReviewSessionRoute> {
  bool _exiting = false;
  Future<void> _exit() async {
    if (_exiting) return;
    final route = ModalRoute.of(context);
    final session = widget.session;
    setState(() => _exiting = true);
    await session.stop();
    if (mounted && identical(session, widget.session)) {
      setState(() => _exiting = false);
      if (route?.isCurrent == true) Navigator.of(context).pop();
    }
  }

  @override
  void didUpdateWidget(ReviewSessionRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      unawaited(oldWidget.session.stop());
      oldWidget.session.dispose();
      _exiting = false;
    }
  }

  @override
  void dispose() {
    unawaited(widget.session.stop());
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return PopScope(
      canPop: !_exiting && widget.session.isStopped,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        body: PikoPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PikoHeading(
                title: copy.text('learn.longTitle'),
                leading: PikoButton(
                  label: copy.text('common.back'),
                  icon: const PikoIcon(PikoIconName.arrowLeft),
                  variant: PikoButtonVariant.ghost,
                  onPressed: _exiting ? null : _exit,
                ),
              ),
              Text(
                reviewDirectionLabel(
                  widget.collection,
                  widget.session.direction,
                ),
                key: const ValueKey('review-fixed-direction'),
              ),
              // Initial empty membership is not regular exhaustion after grades.
              // Retry integration must also check pending reinforcement first.
              if (widget.session.members.isEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: pikoDesign.dimension('spacing.5'),
                  ),
                  child: PikoCard(
                    key: const ValueKey('review-no-due'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          headingLevel: 2,
                          child: Text(
                            copy.text('learn.noDueTitle'),
                            style: TextStyle(
                              fontSize: pikoDesign.dimension('typography.body'),
                              fontWeight: pikoDesign.weight(
                                'typography.titleWeight',
                              ),
                              color: pikoDesign.color('ink'),
                            ),
                          ),
                        ),
                        SizedBox(height: pikoDesign.dimension('spacing.3')),
                        Text(
                          copy.text('learn.noDueBody'),
                          style: TextStyle(
                            fontSize: pikoDesign.dimension(
                              'components.emptyState.descriptionSize',
                            ),
                            height: pikoDesign.dimension(
                              'components.emptyState.descriptionLineHeight',
                            ),
                            color: pikoDesign.color('muted'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
