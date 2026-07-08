import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'errors.dart';
import 'finders.dart';

class AutomationEngine {
  static final AutomationEngine instance = AutomationEngine._();
  AutomationEngine._();

  /// Callback for when an interaction occurs (used for UI highlighting).
  void Function(Offset position)? onInteraction;

  /// Helper to convert dynamic target (Key or Finder) to AutomationFinder
  AutomationFinder _toFinder(dynamic target) {
    if (target is AutomationFinder) return target;
    if (target is Key) return find.byKey(target);
    if (target is String) return find.byText(target);
    if (target is IconData) return find.byIcon(target);
    if (target is Type) return find.byType(target);
    throw ArgumentError('Target must be a Key, String, IconData, Type, or AutomationFinder. Got: ${target.runtimeType}');
  }

  /// Triggers a tap on the widget identified by [target].
  ///
  /// Before tapping, the target must pass every actionability check: it exists,
  /// resolves to an element with a tap callback (i.e. is enabled), is visible,
  /// and actually receives pointer events at its center (not obscured by
  /// another widget). These are re-checked on a poll until [timeout]; on
  /// timeout the most specific failing reason is thrown.
  Future<void> tap(dynamic target, {Duration timeout = const Duration(seconds: 5)}) async {
    final finder = _toFinder(target);
    final deadline = DateTime.now().add(timeout);

    AutomationException lastReason = ElementNotFoundException('No widget found for $finder.');
    while (true) {
      final actionable = _resolveActionableTap(finder, (reason) => lastReason = reason);
      if (actionable != null) {
        await _highlightAndTap(actionable);
        return;
      }
      if (!DateTime.now().isBefore(deadline)) {
        throw lastReason;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Resolves [finder] to a tappable, visible, unobscured element, or returns
  /// null and reports (via [onFail]) the most specific reason it is not yet
  /// actionable.
  Element? _resolveActionableTap(AutomationFinder finder, void Function(AutomationException) onFail) {
    final element = _findFirstElement(finder);
    if (element == null) {
      onFail(ElementNotFoundException('No widget found for $finder.'));
      return null;
    }

    // Resolve to the element that actually carries a tap callback: the target
    // itself, then a tappable ancestor, then a tappable descendant.
    Element? found;
    if (_isTappable(element) && _hasTapCallback(element.widget)) {
      found = element;
    } else {
      element.visitAncestorElements((ancestor) {
        if (_isTappable(ancestor) && _hasTapCallback(ancestor.widget)) {
          found = ancestor;
          return false;
        }
        return true;
      });
      found ??= _findFirstDescendant(
          element, (e) => _isTappable(e) && _isVisible(e) && _hasTapCallback(e.widget));
    }

    final tappable = found;
    if (tappable == null) {
      if (_isTappable(element) && !_hasTapCallback(element.widget)) {
        onFail(NotActionableException('Widget for $finder is disabled: its onPressed/onTap callback is null.'));
      } else {
        onFail(NotActionableException('No tappable element with a callback found for $finder (on it or its ancestors/descendants).'));
      }
      return null;
    }

    if (!_isVisible(tappable)) {
      onFail(NotVisibleException('Widget for $finder is not visible.'));
      return null;
    }

    final center = _centerOf(tappable);
    if (center == null) {
      onFail(const NotActionableException('Target has no attached, sized render box.'));
      return null;
    }
    if (!_pointReachesTarget(tappable, center)) {
      onFail(NotActionableException('Widget for $finder is obscured by another widget and would not receive the tap at $center.'));
      return null;
    }

    return tappable;
  }

  /// Global-coordinate center of [element], or null if it has no usable box.
  Offset? _centerOf(Element element) {
    final rb = element.renderObject as RenderBox?;
    if (rb == null || !rb.attached || !rb.hasSize) return null;
    return rb.localToGlobal(rb.size.center(Offset.zero));
  }

  /// Whether a pointer at [globalPosition] would actually reach [target],
  /// i.e. [target] (or a descendant of it) is on the hit-test path and not
  /// covered by some other widget. This is the "receives events" check.
  bool _pointReachesTarget(Element target, Offset globalPosition) {
    final targetRO = target.renderObject;
    if (targetRO == null) return false;
    final result = HitTestResult();
    GestureBinding.instance.hitTestInView(result, globalPosition, View.of(target).viewId);
    for (final HitTestEntry entry in result.path) {
      final hit = entry.target;
      if (hit == targetRO) return true;
      if (hit is RenderObject && _isRenderDescendant(targetRO, hit)) return true;
    }
    return false;
  }

  /// Whether [node] is [ancestor] or sits below it in the render tree.
  bool _isRenderDescendant(RenderObject ancestor, RenderObject node) {
    RenderObject? current = node;
    while (current != null) {
      if (current == ancestor) return true;
      final parent = current.parent;
      current = parent is RenderObject ? parent : null;
    }
    return false;
  }

  Future<void> _highlightAndTap(Element element) async {
    final position = _centerOf(element);
    if (position == null) {
      throw const NotActionableException('Target for tap has no attached, sized render box.');
    }
    onInteraction?.call(position);
    await Future.delayed(const Duration(milliseconds: 300));

    // Dispatch a REAL tap: a synthetic pointer down/up routed through
    // GestureBinding, so hit-testing and the gesture arena decide what handles
    // it - exactly as if a finger touched the screen. Previously the widget's
    // onPressed/onTap was invoked directly, which bypassed hit-testing (so a
    // covered or IgnorePointer widget still "tapped") and the gesture arena.
    await _dispatchTapAt(position, element);
  }

  int _pointerId = 0;

  /// Sends a synthetic tap (pointer down then up) at [globalPosition] through
  /// [GestureBinding], on the [FlutterView] that hosts [element].
  Future<void> _dispatchTapAt(Offset globalPosition, Element element) async {
    final binding = GestureBinding.instance;
    final viewId = View.of(element).viewId;
    final pointer = ++_pointerId;

    binding.handlePointerEvent(
      PointerDownEvent(viewId: viewId, pointer: pointer, position: globalPosition),
    );
    // Brief hold so the tap recognizer accepts the gesture on pointer-up.
    await Future.delayed(const Duration(milliseconds: 50));
    binding.handlePointerEvent(
      PointerUpEvent(viewId: viewId, pointer: pointer, position: globalPosition),
    );
  }

  /// Enters [text] into the text field identified by [target].
  ///
  /// The text is delivered through the field's real editing pipeline (the same
  /// entry point the platform IME uses), so `inputFormatters`, `onChanged`, and
  /// the selection/cursor are all honoured. Set [submit] to also fire the
  /// field's submit action (`onSubmitted`/`onEditingComplete`).
  Future<void> enterText(dynamic target, String text,
      {Duration timeout = const Duration(seconds: 5), bool submit = false}) async {
    final finder = _toFinder(target);
    await waitFor(finder, timeout: timeout);

    final root = _findFirstElement(finder);
    if (root == null) throw ElementNotFoundException('No widget found for $finder.');

    // Find the EditableText descendant.
    final editableElement = _findFirstDescendant(root, (e) => e.widget is EditableText && _isVisible(e));

    final editable = editableElement;
    if (editable == null) throw NotActionableException('No editable text field found inside $finder. Ensure you are targeting a TextField or TextFormField.');

    await _highlightAndEnterText(editable, text, submit: submit);
  }

  Future<void> _highlightAndEnterText(Element element, String text, {bool submit = false}) async {
    final renderBox = element.renderObject as RenderBox?;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
      throw const NotActionableException('Editable field has no attached, sized render box.');
    }
    final position = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
    onInteraction?.call(position);
    await Future.delayed(const Duration(milliseconds: 300));

    // Focus the field (opens the real input connection) and deliver the text
    // via EditableTextState.updateEditingValue - the platform IME's own entry
    // point - so inputFormatters run, onChanged fires, and the caret is placed
    // at the end. This replaces the previous `controller.text = text`, which
    // bypassed all of that.
    final state = (element as StatefulElement).state as EditableTextState;
    state.widget.focusNode.requestFocus();
    await Future.delayed(const Duration(milliseconds: 50));

    state.updateEditingValue(TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ));

    if (submit) {
      state.performAction(TextInputAction.done);
    }
  }

  /// Scrolls until the [target] is visible.
  Future<void> scrollUntilVisible(dynamic target, {
    dynamic scrollable,
    double step = 300.0, 
    int maxScrolls = 60, 
    Duration duration = const Duration(milliseconds: 100)
  }) async {
    final targetFinder = _toFinder(target);
    
    debugPrint('[Automation] scrollUntilVisible: looking for $targetFinder');

    final existingElement = _findFirstElement(targetFinder);
    if (existingElement != null) {
      debugPrint('[Automation] Found element: ${existingElement.widget.runtimeType}');
      final visible = _isVisible(existingElement);
      debugPrint('[Automation] Is visible: $visible');
      if (visible) {
        debugPrint('[Automation] target already visible');
        return;
      }
    } else {
      debugPrint('[Automation] Element not found in tree, will scroll to find it');
    }

    ScrollableState? scrollState;
    if (scrollable != null) {
      final scrollableFinder = _toFinder(scrollable);
      final element = _findFirstElement(scrollableFinder);
      if (element != null) {
        scrollState = Scrollable.of(element);
      }
    } else {
      // Find the "best" vertical scrollable (the one with the largest scroll extent)
      debugPrint('[Automation] Looking for scrollable widgets in tree...');
      ScrollableState? bestScrollable;
      double largestExtent = -1.0;
      int elementCount = 0;

      void visitor(Element e) {
        elementCount++;
        // Skip only the overlay part of the automation inspector, not the wrapper
        final widgetTypeName = e.widget.runtimeType.toString();
        if (widgetTypeName == 'AutomationInspectorOverlay' || 
            widgetTypeName == '_AutomationInspectorOverlayState' ||
            widgetTypeName.startsWith('_AutomationInspector')) {
          return; // Skip this subtree
        }

        final widgetType = e.widget.runtimeType.toString();
        // Log potential scrollable-related widgets
        if (widgetType.contains('Scroll') || widgetType.contains('List') || widgetType.contains('View')) {
          debugPrint('[Automation] Checking widget: $widgetType');
        }

        if (e.widget is Scrollable) {
          debugPrint('[Automation] Found Scrollable widget: ${e.widget.runtimeType}');
          
          if (e is StatefulElement) {
            final state = e.state;
            if (state is ScrollableState) {
              debugPrint('[Automation] Scrollable axis: ${state.widget.axis}');
              if (state.widget.axis == Axis.vertical) {
                try {
                  if (state.position.hasPixels) {
                    final extent = state.position.maxScrollExtent;
                    debugPrint('[Automation] Scrollable maxExtent: $extent');
                    if (extent > largestExtent) {
                      largestExtent = extent;
                      bestScrollable = state;
                    }
                  }
                } catch (err) {
                  debugPrint('[Automation] Error getting scroll extent: $err');
                }
              }
            }
          }
        }
        e.visitChildren(visitor);
      }
      WidgetsBinding.instance.rootElement?.visitChildren(visitor);
      debugPrint('[Automation] Visited $elementCount elements, bestScrollable: ${bestScrollable != null}');
      scrollState = bestScrollable;
    }
    
    if (scrollState == null) {
      throw const NotActionableException('No vertical Scrollable found to perform scrollUntilVisible.');
    }

    final position = scrollState.position;
    debugPrint('[Automation] Using scrollable with maxExtent: ${position.maxScrollExtent}');
    
    for (int i = 0; i < maxScrolls; i++) {
        final element = _findFirstElement(targetFinder);
        if (element != null && _isVisible(element)) {
           debugPrint('[Automation] Target found in tree and visible. Ensuring visibility...');
           await Scrollable.ensureVisible(element, duration: const Duration(milliseconds: 200), alignment: 0.5);
           await Future.delayed(const Duration(milliseconds: 300)); // Wait for animation
           return;
        }
        
        if (position.pixels >= position.maxScrollExtent) {
           debugPrint('[Automation] Reached bottom of scrollable at ${position.pixels}');
           break;
        }

        final targetScroll = (position.pixels + step).clamp(0.0, position.maxScrollExtent);
        debugPrint('[Automation] Jumping to $targetScroll (Step $i)');
        position.jumpTo(targetScroll);
        
        await Future.delayed(duration);
        await Future.delayed(const Duration(milliseconds: 50));
    }
    
    if (!_elementExistsAndVisible(targetFinder)) {
      throw ElementNotFoundException('Could not find $target after scrolling to the bottom (${position.maxScrollExtent}px).');
    }
  }

  // --- Finders & Utils ---

  Element? _findFirstElement(AutomationFinder finder) {
    if (WidgetsBinding.instance.rootElement == null) return null;
    final root = WidgetsBinding.instance.rootElement!;
    
    // We search the entire tree recursively.
    return finder.findFirst(root);
  }
  
  bool _elementExistsAndVisible(AutomationFinder finder) {
    final element = _findFirstElement(finder);
    if (element == null) return false;
    return _isVisible(element);
  }

  Future<void> waitFor(dynamic target, {Duration timeout = const Duration(seconds: 5)}) async {
    final finder = _toFinder(target);
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (_findFirstElement(finder) != null) return;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw AutomationTimeoutException('Timed out after $timeout waiting for $finder.');
  }

  bool _isTappable(Element element) {
    final widget = element.widget;
    return widget is ButtonStyleButton || 
           widget is MaterialButton ||
           widget is FloatingActionButton ||
           widget is IconButton ||
           widget is InkWell ||
           widget is InkResponse ||
           widget is GestureDetector ||
           widget is ListTile;
  }

  /// Checks if a tappable widget actually has a tap callback set.
  bool _hasTapCallback(Widget widget) {
    if (widget is ButtonStyleButton) return widget.onPressed != null;
    if (widget is MaterialButton) return widget.onPressed != null;
    if (widget is FloatingActionButton) return widget.onPressed != null;
    if (widget is IconButton) return widget.onPressed != null;
    if (widget is InkWell) return widget.onTap != null;
    if (widget is InkResponse) return widget.onTap != null;
    if (widget is GestureDetector) return widget.onTap != null;
    if (widget is ListTile) return widget.onTap != null;
    return false;
  }

  bool _isVisible(Element element) {
    final renderBox = element.renderObject as RenderBox?;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize || renderBox.size.isEmpty) return false;

    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final windowSize = view.physicalSize / view.devicePixelRatio;
    Rect visibleArea = Rect.fromLTWH(0, 0, windowSize.width, windowSize.height);

    // Initial widget rect in global coords
    final pos = renderBox.localToGlobal(Offset.zero);
    final widgetRect = pos & renderBox.size;

    // Check if it's even on the screen generally
    if (!visibleArea.overlaps(widgetRect)) return false;

    // CLIP CHECK: Walk up the tree and intersect with all viewports
    RenderObject? ancestor = renderBox.parent;
    while (ancestor != null) {
      if (ancestor is RenderViewportBase) {
        final Rect viewportGlobalRect = (ancestor as RenderBox).localToGlobal(Offset.zero) & (ancestor as RenderBox).size;
        visibleArea = visibleArea.intersect(viewportGlobalRect);
      } else if (ancestor is RenderBox) {
        // Handle explicit clipping widgets if possible, 
        // though Viewport is the primary concern for lists.
      }
      ancestor = ancestor.parent;
    }

    // Now check if the widget significantly overlaps the final visible area.
    // We use a small threshold or center point to be sure it's actually "seeable"
    return visibleArea.overlaps(widgetRect);
  }
  
  Element? _findFirstDescendant(Element element, bool Function(Element) predicate) {
    if (predicate(element)) return element;
    Element? found;
    void visitor(Element child) {
      if (found != null) return;
      if (predicate(child)) {
        found = child;
      } else {
        child.visitChildren(visitor);
      }
    }
    element.visitChildren(visitor);
    return found;
  }
    
  // --- Public Headers for internal libraries (like Expect) ---
  
  AutomationFinder toFinderPublic(dynamic target) => _toFinder(target);
  
  Element? findFirstElementPublic(AutomationFinder finder) => _findFirstElement(finder);
  
  bool isVisiblePublic(Element element) => _isVisible(element);

  /// All elements currently matching [finder], searched from the root.
  Iterable<Element> findAllPublic(AutomationFinder finder) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return const [];
    return finder.findAll(root);
  }

  /// Number of elements currently matching [finder].
  int countPublic(AutomationFinder finder) => findAllPublic(finder).length;

  /// Whether [finder] resolves to an enabled, tappable element (itself, an
  /// ancestor, or a descendant carries a non-null tap callback).
  bool isTapEnabledPublic(AutomationFinder finder) {
    final el = _findFirstElement(finder);
    if (el == null) return false;
    if (_isTappable(el) && _hasTapCallback(el.widget)) return true;
    var foundInAncestor = false;
    el.visitAncestorElements((a) {
      if (_isTappable(a) && _hasTapCallback(a.widget)) {
        foundInAncestor = true;
        return false;
      }
      return true;
    });
    if (foundInAncestor) return true;
    return _findFirstDescendant(el, (e) => _isTappable(e) && _hasTapCallback(e.widget)) != null;
  }

  /// Waits until the framework has no more frames scheduled, i.e. animations,
  /// layout, and transitions have settled - or until [timeout] elapses.
  ///
  /// Unlike a fixed delay, this returns as soon as the UI is idle and fails
  /// loudly if something keeps scheduling frames forever (e.g. an infinite
  /// animation), instead of silently continuing on a stale frame.
  Future<void> pumpAndSettle({
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 50),
  }) async {
    final binding = WidgetsBinding.instance;
    final end = DateTime.now().add(timeout);
    while (binding.hasScheduledFrame) {
      if (DateTime.now().isAfter(end)) {
        throw AutomationTimeoutException(
            'pumpAndSettle timed out after $timeout; frames are still being scheduled (an animation may never settle).');
      }
      await Future.delayed(pollInterval);
    }
  }
}
