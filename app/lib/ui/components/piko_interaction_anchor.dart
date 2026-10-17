import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Route-local interaction ownership. No selection, view or learning data lives here.
class PikoInteractionAnchor {
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
  }

  Widget scope({required Widget child}) =>
      _AnchorScope(anchor: this, child: child);
}

class _AnchorScope extends InheritedWidget {
  const _AnchorScope({required this.anchor, required super.child});
  final PikoInteractionAnchor anchor;
  @override
  bool updateShouldNotify(_AnchorScope oldWidget) => anchor != oldWidget.anchor;
}

/// An entire chip/card/header is the stable identity, including its reset target.
/// The region remains passive outside a Collection's anchored viewport.
class PikoAnchorRegion extends StatefulWidget {
  const PikoAnchorRegion({super.key, required this.child});
  final Widget child;

  /// Action callbacks also use this path for semantic/keyboard activation.
  static void capture(BuildContext context) {
    final state = context.findAncestorStateOfType<_RegionState>();
    final region = state?._key.currentContext?.findRenderObject();
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
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          final region = _key.currentContext?.findRenderObject();
          if (region is _RenderRegion) anchor._capture(region);
        }
        return KeyEventResult.ignored;
      },
      child: _Region(key: _key, anchor: anchor, child: widget.child),
    );
  }
}

class _Region extends SingleChildRenderObjectWidget {
  const _Region({super.key, required this.anchor, required super.child});
  final PikoInteractionAnchor anchor;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRegion(anchor);
  @override
  void updateRenderObject(BuildContext context, _RenderRegion renderObject) {
    if (renderObject.anchor == anchor) return;
    renderObject.anchor._regions.remove(renderObject);
    renderObject.anchor = anchor;
    if (renderObject.attached) anchor._regions.add(renderObject);
  }
}

class _RenderRegion extends RenderProxyBox {
  _RenderRegion(this.anchor);
  PikoInteractionAnchor anchor;
  _AnchoredRenderViewport? get parentViewport {
    RenderObject? node = parent;
    while (node != null) {
      if (node is _AnchoredRenderViewport) return node;
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
      child: _AnchoredViewport(
        interactionAnchor: interactionAnchor,
        textScaler: MediaQuery.textScalerOf(context),
        offset: offset,
        slivers: slivers,
      ),
    );
  }
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

class _AnchoredRenderViewport extends RenderViewport {
  _AnchoredRenderViewport(
    this.interactionAnchor, {
    required this.textScaler,
    required super.offset,
    required super.crossAxisDirection,
  });
  PikoInteractionAnchor interactionAnchor;
  TextScaler textScaler;
  double? _lastPixels;

  @override
  void performLayout() {
    // Explicit scrolling (including keyboard and accessibility reveal requests)
    // takes precedence. Dimension changes within this layout are handled below.
    if (_lastPixels != null && (offset.pixels - _lastPixels!).abs() > .01) {
      interactionAnchor.clear();
    }
    super.performLayout();
    _lastPixels = offset.pixels;
    final anchor = interactionAnchor;
    if (anchor._target == null) return;
    if (anchor._viewportSize != size || offset is! ScrollPosition) {
      anchor.clear();
      return;
    }
    var target = anchor._target!;
    if (!target.attached || target.parentViewport != this) {
      // Prefer the closest surviving contextual region; never resurrect removed rows.
      final previousTop = anchor._tops[target];
      final candidates = anchor._tops.keys
          .where((r) => r.attached && r.parentViewport == this)
          .toList();
      if (previousTop == null || candidates.isEmpty) {
        anchor.clear();
        return;
      }
      candidates.sort(
        (a, b) => (anchor._tops[a]! - previousTop).abs().compareTo(
          (anchor._tops[b]! - previousTop).abs(),
        ),
      );
      target = anchor._target = candidates.first;
    }
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
      super.performLayout();
      _lastPixels = offset.pixels;
    }
  }
}
