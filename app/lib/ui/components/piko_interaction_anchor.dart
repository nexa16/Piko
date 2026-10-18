import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Route-local interaction ownership. No selection, view or learning data lives here.
class PikoInteractionAnchor {
  PikoInteractionAnchor({this.onCapture});
  final VoidCallback? onCapture;
  bool get hasTarget => _target != null;
  static PikoInteractionAnchor? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AnchorScope>()?.anchor;
  final _regions = <_RenderRegion>{};
  Map<_RenderRegion, double> _tops = {};
  _RenderRegion? _target;
  Size? _viewportSize;
  int? _pointer;
  Offset? _pointerStart;

  void clear() {
    _target = null;
    _tops = {};
    _pointer = null;
    _pointerStart = null;
  }

  void _capture(_RenderRegion region, {PointerDownEvent? event}) {
    if (!region.attached || !region.hasSize) return;
    final viewport = region.parentViewport;
    if (viewport == null) return;
    _target = region;
    _viewportSize = viewport.size;
    _tops = {
      for (final candidate in _regions)
        if (candidate.attached && candidate.parentViewport == viewport)
          candidate: candidate.getTransformTo(viewport).getTranslation().y,
    };
    _pointer = event?.pointer;
    _pointerStart = event?.position;
    region.boxContents?._recordOffset();
    onCapture?.call();
  }

  Widget scope({required Widget child}) =>
      _AnchorScope(anchor: this, child: child);

  _RenderRegion? _resolveTarget(RenderBox viewport) {
    final target = _target;
    if (target == null) return null;
    if (target.attached && target.parentViewport == viewport) return target;
    final previousTop = _tops[target];
    final candidates = _tops.keys
        .where((r) => r.attached && r.parentViewport == viewport)
        .toList();
    if (previousTop == null || candidates.isEmpty) {
      clear();
      return null;
    }
    candidates.sort(
      (a, b) => (_tops[a]! - previousTop).abs().compareTo(
        (_tops[b]! - previousTop).abs(),
      ),
    );
    return _target = target.fallbackId == null
        ? candidates.first
        : candidates
                  .where((r) => r.anchorId == target.fallbackId)
                  .firstOrNull ??
              candidates.first;
  }
}

class _AnchorScope extends InheritedWidget {
  const _AnchorScope({required this.anchor, required super.child});
  final PikoInteractionAnchor anchor;
  @override
  bool updateShouldNotify(_AnchorScope oldWidget) => anchor != oldWidget.anchor;
}

/// An entire chip/card/header is the stable identity, including its reset target.
/// The region remains passive outside an anchored viewport.
class PikoAnchorRegion extends StatefulWidget {
  const PikoAnchorRegion({
    super.key,
    required this.child,
    this.anchorId,
    this.fallbackId,
  });
  final Widget child;
  final Object? anchorId, fallbackId;

  /// Action callbacks also use this path for semantic/keyboard activation.
  static void capture(BuildContext context) {
    if (!context.mounted) return;
    final state = context.findAncestorStateOfType<_RegionState>();
    final object = context.findRenderObject();
    final region = object is _RenderRegion
        ? object
        : state?._key.currentContext?.findRenderObject();
    if (region is _RenderRegion) region.anchor._capture(region);
  }

  @override
  State<PikoAnchorRegion> createState() => _RegionState();
}

class _RegionState extends State<PikoAnchorRegion> {
  final _key = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final anchor = context
        .dependOnInheritedWidgetOfExactType<_AnchorScope>()
        ?.anchor;
    if (anchor == null) return widget.child;
    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      onFocusChange: (focused) {
        if (!focused) return;
        final focusContext = FocusManager.instance.primaryFocus?.context;
        if (focusContext != null) PikoAnchorRegion.capture(focusContext);
      },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          final region = _key.currentContext?.findRenderObject();
          if (region is _RenderRegion) anchor._capture(region);
        }
        return KeyEventResult.ignored;
      },
      child: _Region(
        key: _key,
        anchor: anchor,
        anchorId: widget.anchorId,
        fallbackId: widget.fallbackId,
        child: widget.child,
      ),
    );
  }
}

/// Shared controls use the nearest explicit card/header, or their own stable
/// region when standing alone. Capture in the callback also covers semantics.
class PikoAnchorAction extends StatelessWidget {
  const PikoAnchorAction({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) {
    final region = context.findAncestorStateOfType<_RegionState>();
    final parentAnchor = region == null
        ? null
        : PikoInteractionAnchor.maybeOf(region.context);
    return region != null &&
            parentAnchor == PikoInteractionAnchor.maybeOf(context)
        ? builder(context)
        : PikoAnchorRegion(child: Builder(builder: builder));
  }
}

/// Content-sized surfaces (including dialog bodies) share the same layout-time
/// correction as sliver pages, without reserving empty space for collapsed UI.
class PikoAnchoredBoxScrollView extends StatefulWidget {
  const PikoAnchoredBoxScrollView({
    super.key,
    required this.child,
    this.controller,
    this.physics,
    this.padding = EdgeInsets.zero,
    this.interactionAnchor,
  });
  final Widget child;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;
  final PikoInteractionAnchor? interactionAnchor;
  @override
  State<PikoAnchoredBoxScrollView> createState() => _BoxScrollState();
}

class _BoxScrollState extends State<PikoAnchoredBoxScrollView> {
  final _ownedAnchor = PikoInteractionAnchor();
  @override
  Widget build(BuildContext context) {
    final anchor = widget.interactionAnchor ?? _ownedAnchor;
    return anchor.scope(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (anchor._pointer != event.pointer) anchor.clear();
        },
        onPointerMove: (event) {
          final start = anchor._pointerStart;
          if (start != null && (event.position - start).distance > 8) {
            anchor.clear();
          }
        },
        onPointerSignal: (_) => anchor.clear(),
        child: SingleChildScrollView(
          controller: widget.controller,
          physics: widget.physics,
          child: Builder(
            builder: (context) => _AnchoredBoxContents(
              anchor: anchor,
              position: Scrollable.of(context).position,
              textScaler: MediaQuery.textScalerOf(context),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnchoredBoxContents extends SingleChildRenderObjectWidget {
  const _AnchoredBoxContents({
    required this.anchor,
    required this.position,
    required this.textScaler,
    required super.child,
  });
  final PikoInteractionAnchor anchor;
  final ScrollPosition position;
  final TextScaler textScaler;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAnchoredBoxContents(anchor, position, textScaler);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAnchoredBoxContents renderObject,
  ) {
    if (renderObject.textScaler != textScaler ||
        renderObject.position != position) {
      anchor.clear();
    }
    renderObject
      ..anchor = anchor
      ..position = position
      ..textScaler = textScaler;
  }
}

class _RenderAnchoredBoxContents extends RenderProxyBox {
  _RenderAnchoredBoxContents(this.anchor, this.position, this.textScaler);
  PikoInteractionAnchor anchor;
  ScrollPosition position;
  TextScaler textScaler;
  double? _lastPixels;
  void _recordOffset() => _lastPixels = position.pixels;
  @override
  void performLayout() {
    if (_lastPixels != null && (position.pixels - _lastPixels!).abs() > .01) {
      anchor.clear();
    }
    super.performLayout();
    _recordOffset();
    if (!anchor.hasTarget) return;
    final candidate = RenderAbstractViewport.maybeOf(this);
    if (candidate is! RenderBox) return;
    final viewport = candidate as RenderBox;
    // Correct while the enclosing box viewport lays out this padded content,
    // before it computes dimensions/paint. Immediate caret/reveal transforms
    // keep SingleChildScrollView's offset semantics.
    final nextViewportSize = viewport.constraints.constrain(size);
    if (anchor._viewportSize != nextViewportSize) {
      anchor.clear();
      return;
    }
    final target = anchor._resolveTarget(viewport);
    if (target == null) return;
    final delta =
        target.getTransformTo(viewport).getTranslation().y -
        anchor._tops[target]!;
    final maxScroll = (size.height - nextViewportSize.height).clamp(
      0.0,
      double.infinity,
    );
    final next = (position.pixels + delta).clamp(0.0, maxScroll);
    if ((next - position.pixels).abs() > .01) {
      position.correctBy(next - position.pixels);
    }
    _recordOffset();
  }
}

class _Region extends SingleChildRenderObjectWidget {
  const _Region({
    super.key,
    required this.anchor,
    required super.child,
    this.anchorId,
    this.fallbackId,
  });
  final PikoInteractionAnchor anchor;
  final Object? anchorId, fallbackId;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRegion(anchor)
    ..anchorId = anchorId
    ..fallbackId = fallbackId;
  @override
  void updateRenderObject(BuildContext context, _RenderRegion renderObject) {
    renderObject
      ..anchorId = anchorId
      ..fallbackId = fallbackId;
    if (renderObject.anchor == anchor) return;
    renderObject.anchor._regions.remove(renderObject);
    renderObject.anchor = anchor;
    if (renderObject.attached) anchor._regions.add(renderObject);
  }
}

class _RenderRegion extends RenderProxyBox {
  _RenderRegion(this.anchor);
  PikoInteractionAnchor anchor;
  Object? anchorId, fallbackId;
  RenderBox? get parentViewport {
    RenderObject? node = parent;
    while (node != null) {
      if (node is RenderAbstractViewport && node is RenderBox) {
        return node as RenderBox;
      }
      node = node.parent;
    }
    return null;
  }

  _RenderAnchoredBoxContents? get boxContents {
    RenderObject? node = parent;
    while (node != null) {
      if (node is _RenderAnchoredBoxContents) return node;
      if (node is RenderAbstractViewport) return null;
      node = node.parent;
    }
    return null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    anchor._regions.add(this);
  }

  @override
  void detach() {
    anchor._regions.remove(this);
    super.detach();
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent && anchor._pointer != event.pointer) {
      anchor._capture(this, event: event);
    }
    super.handleEvent(event, entry);
  }
}

class PikoAnchoredScrollView extends CustomScrollView {
  const PikoAnchoredScrollView({
    super.key,
    required this.interactionAnchor,
    required super.slivers,
    super.physics,
    super.controller,
    super.shrinkWrap,
  });
  final PikoInteractionAnchor interactionAnchor;
  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (interactionAnchor._pointer != event.pointer) {
          interactionAnchor.clear();
        }
      },
      onPointerMove: (event) {
        final start = interactionAnchor._pointerStart;
        if (start != null && (event.position - start).distance > 8) {
          interactionAnchor.clear();
        }
      },
      onPointerSignal: (_) => interactionAnchor.clear(),
      child: shrinkWrap
          ? _AnchoredShrinkViewport(
              interactionAnchor: interactionAnchor,
              textScaler: MediaQuery.textScalerOf(context),
              offset: offset,
              slivers: slivers,
            )
          : _AnchoredViewport(
              interactionAnchor: interactionAnchor,
              textScaler: MediaQuery.textScalerOf(context),
              offset: offset,
              slivers: slivers,
            ),
    );
  }
}

class _AnchoredShrinkViewport extends ShrinkWrappingViewport {
  const _AnchoredShrinkViewport({
    required this.interactionAnchor,
    required this.textScaler,
    required super.offset,
    required super.slivers,
  });
  final PikoInteractionAnchor interactionAnchor;
  final TextScaler textScaler;
  @override
  RenderShrinkWrappingViewport createRenderObject(BuildContext context) =>
      _AnchoredShrinkRenderViewport(
        interactionAnchor,
        textScaler: textScaler,
        offset: offset,
        crossAxisDirection: Viewport.getDefaultCrossAxisDirection(
          context,
          axisDirection,
        ),
      );
  @override
  void updateRenderObject(
    BuildContext context,
    RenderShrinkWrappingViewport renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    final viewport = renderObject as _AnchoredShrinkRenderViewport;
    if (viewport.textScaler != textScaler) interactionAnchor.clear();
    viewport.interactionAnchor = interactionAnchor;
    viewport.textScaler = textScaler;
  }
}

class _AnchoredShrinkRenderViewport extends RenderShrinkWrappingViewport
    with _AnchorLayout {
  _AnchoredShrinkRenderViewport(
    this.interactionAnchor, {
    required this.textScaler,
    required super.offset,
    required super.crossAxisDirection,
  });
  @override
  PikoInteractionAnchor interactionAnchor;
  TextScaler textScaler;
  @override
  void performLayout() => layoutAnchored(super.performLayout);
}

class _AnchoredViewport extends Viewport {
  _AnchoredViewport({
    required this.interactionAnchor,
    required this.textScaler,
    required super.offset,
    required super.slivers,
  });
  final PikoInteractionAnchor interactionAnchor;
  final TextScaler textScaler;
  @override
  RenderViewport createRenderObject(BuildContext context) =>
      _AnchoredRenderViewport(
        interactionAnchor,
        textScaler: textScaler,
        offset: offset,
        crossAxisDirection: Viewport.getDefaultCrossAxisDirection(
          context,
          axisDirection,
        ),
      );
  @override
  void updateRenderObject(BuildContext context, RenderViewport renderObject) {
    super.updateRenderObject(context, renderObject);
    final viewport = renderObject as _AnchoredRenderViewport;
    if (viewport.textScaler != textScaler) interactionAnchor.clear();
    viewport.interactionAnchor = interactionAnchor;
    viewport.textScaler = textScaler;
  }
}

class _AnchoredRenderViewport extends RenderViewport with _AnchorLayout {
  _AnchoredRenderViewport(
    this.interactionAnchor, {
    required this.textScaler,
    required super.offset,
    required super.crossAxisDirection,
  });
  @override
  PikoInteractionAnchor interactionAnchor;
  TextScaler textScaler;
  @override
  void performLayout() => layoutAnchored(super.performLayout);
}

mixin _AnchorLayout on RenderBox {
  PikoInteractionAnchor get interactionAnchor;
  ViewportOffset get offset;
  double? _lastPixels;

  void layoutAnchored(VoidCallback layoutContent) {
    // Explicit scrolling (including keyboard and accessibility reveal requests)
    // takes precedence. Dimension changes within this layout are handled below.
    if (_lastPixels != null && (offset.pixels - _lastPixels!).abs() > .01) {
      interactionAnchor.clear();
    }
    layoutContent();
    _lastPixels = offset.pixels;
    final anchor = interactionAnchor;
    if (anchor._target == null) return;
    if (anchor._viewportSize != size || offset is! ScrollPosition) {
      anchor.clear();
      return;
    }
    final target = anchor._resolveTarget(this);
    if (target == null) return;
    final position = offset as ScrollPosition;
    // The viewport retries its sliver layout before paint. No post-frame jump,
    // animation or permanent leading/trailing padding is needed.
    for (var attempt = 0; attempt < 4; attempt++) {
      final top = target.getTransformTo(this).getTranslation().y;
      final delta = top - anchor._tops[target]!;
      final next = (offset.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      final correction = next - offset.pixels;
      if (correction.abs() < .01) break;
      offset.correctBy(correction);
      layoutContent();
      _lastPixels = offset.pixels;
    }
  }
}
